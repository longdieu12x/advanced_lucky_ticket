// SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;

import "./IDao.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Timers.sol";

/**
 * @dev core of the DAO system, can be extended throgh various modules.
 * This contract is abstract and requires several function to be implemented
 */

abstract contract Dao is Context, ERC165, EIP712, IDao {
    using SafeCast for uint256;
    using Timers for Timers.BlockNumber;

    bytes32 public constant BALLOT_TYPEHASH =
        keccak256("Ballot(uint256 proposalId, uint8 support)");

    struct ProposalCore {
        Timers.BlockNumber voteStart;
        Timers.BlockNumber voteEnd;
        bool executed;
    }

    string private _name;

    mapping(uint256 => ProposalCore) private _proposals;
    uint256 internal _finalProposalId;
    uint256[] internal _proposalKeys;

    event setFinalProposal(
        uint256 finalProposalId,
        uint64 voteStart,
        uint64 voteEnd
    );

    /**
     * @dev Restrict acess of functions to DAO executor
     */
    modifier onlyGovernance() {
        require(_msgSender() == _executor(), "FlashDao: onlyGovernance");
        _;
    }

    /**
     * @dev Set the {name} and {version}
     */
    constructor(string memory name_) EIP712(name_, version()) {
        _name = name_;
    }

    /**
     * @dev Only receive BNB that will be handled by the DAO
     */
    receive() external payable virtual {
        require(_executor() == address(this));
    }

    /**
     * @dev Override supportInterfaces see {IERC165-supportInterface}
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IDao).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev set first final proposal when the block start.
     */
    function setFirstFinalProposal() public virtual {
        uint256 higestRateProposalId = _highestRateFor();
        require(higestRateProposalId != 0, "FlashDao:Queued Empty");
        require(
            _finalProposalId == 0 ||
                state(_finalProposalId) == ProposalState.Defeated,
            "FlashDao: Invalid proposalId"
        );
        _setFinalProposal(higestRateProposalId);
    }

    /**
     * @dev Set final proposal, reset the votes and votes account for final pharse.
     */
    function _setFinalProposal(uint256 proposalId) internal virtual {
        ProposalCore storage proposal = _proposals[proposalId];
        _finalProposalId = proposalId;
        uint64 finalStart = block.number.toUint64();
        uint64 finalDeadline = finalStart + votingFinalPeriod().toUint64();
        proposal.voteStart.setDeadline(finalStart);
        proposal.voteEnd.setDeadline(finalDeadline);
        emit setFinalProposal(proposalId, finalStart, finalDeadline);
        _resetCountVote(proposalId);
    }

    /**
     * @dev See {IDAO-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IDAO-version}.
     */
    function version() public view virtual override returns (string memory) {
        return "1";
    }

    /**
     * @dev See {IDAO-hashProposal}.
     *
     * The proposal id is produced by hashing the RLC encoded `targets` array, the `values` array, the `calldatas` array
     * and the descriptionHash (bytes32 which itself is the keccak256 hash of the description string). This proposal id
     * can be produced from the proposal data which is part of the {ProposalCreated} event. It can even be computed in
     * advance, before the proposal is submitted.
     *
     * Note that the chainId and the governor address are not part of the proposal id computation. Consequently, the
     * same proposal (with same operation and same description) will have the same id if submitted on multiple governors
     * accross multiple networks. This also means that in order to execute the same operation twice (on the same
     * governor) the proposer will have to change the description in order to avoid proposal id conflicts.
     */
    function hashProposal(
        address targets,
        uint256 values,
        bytes memory calldatas,
        bytes32 descriptionHash
    ) public pure virtual override returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encode(targets, values, calldatas, descriptionHash)
                )
            );
    }

    /**
     * @dev See {IDAO-state}
     */
    function state(uint256 proposalId)
        public
        view
        virtual
        override
        returns (ProposalState)
    {
        ProposalCore storage proposal = _proposals[proposalId];
        if (proposal.executed) {
            return ProposalState.Executed;
        }
        uint256 snapshot = proposalSnapshot(proposalId);
        require(snapshot > 0, "FlashDao: unknown proposal id");
        uint256 deadline = proposalDeadline(proposalId);
        if (deadline >= block.number) {
            return ProposalState.Active;
        }
        if (proposalId != _finalProposalId)
            if (_quorumReached(proposalId) && _voteSucceeded(proposalId)) {
                return ProposalState.Queued;
            } else {
                return ProposalState.Expired;
            }
        else {
            if (_quorumReached(proposalId) && _voteSucceeded(proposalId)) {
                return ProposalState.Succeeded;
            } else {
                return ProposalState.Defeated;
            }
        }
    }

    /**
     * @dev See {IDAO-votingDelay}
     */
    function votingDelay() public view virtual override returns (uint256) {
        return 0;
    }

    function votingFinalPeriod() public view virtual returns (uint256) {
        return 1200;
    }

    /**
     * @dev See {IDAO-votingPeriod}
     */
    function votingPeriod() public view virtual override returns (uint256) {
        return 1200;
    }

    /**
     * @dev see {IDAO-proposalSnapshot}
     */
    function proposalSnapshot(uint256 proposalId)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _proposals[proposalId].voteStart.getDeadline();
    }

    /**
     * @dev see {IDAO-proposalDeadline}
     */
    function proposalDeadline(uint256 proposalId)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _proposals[proposalId].voteEnd.getDeadline();
    }

    /**
     * @dev Part of the Governor Bravo's interface: _"The number of votes required in order for a voter to become a proposer"_.
     */
    function proposalThreshold() public view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev Amount of votes already cast passes the threshold limit.
     */
    function _quorumReached(uint256 proposalId)
        internal
        view
        virtual
        returns (bool);

    /**
     * @dev Is the proposal successful or not.
     */
    function _voteSucceeded(uint256 proposalId)
        internal
        view
        virtual
        returns (bool);

    /**
     * @dev Return highest rate proposal id for in ideapharse
     */
    function _highestRateFor() internal view virtual returns (uint256);

    /**
     * @dev Reset the votes for the final pharse
     */
    function _resetCountVote(uint256 proposalId) public virtual;

    /**
     * @dev Register a vote with a given support and voting weight.
     *
     * Note: Support is generic and can represent various things depending on the voting system used.
     */
    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight
    ) internal virtual;

    /**
     * @dev See {IDAO-getVotes}
     */
    function getVotes(address account, uint256 blockNumber)
        public
        view
        virtual
        override
        returns (uint256);

    /**
     * @dev See {IDAO-propose}.
     */
    function propose(
        address targets,
        uint256 values,
        bytes memory calldatas,
        string memory description
    ) public virtual override returns (uint256) {
        require(
            getVotes(msg.sender, block.number - 1) >= proposalThreshold(),
            "GovernorCompatibilityBravo: proposer votes below proposal threshold"
        );
        uint256 proposalId = hashProposal(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );
        require(targets != address(0), "DAO: Target not null");
        ProposalCore storage proposal = _proposals[proposalId];
        require(proposal.voteStart.isUnset(), "DAO: proposal already exists");
        _proposalKeys.push(proposalId);
        uint64 snapshot = block.number.toUint64() + votingDelay().toUint64();
        uint64 deadline = snapshot + votingPeriod().toUint64();

        proposal.voteStart.setDeadline(snapshot);
        proposal.voteEnd.setDeadline(deadline);
        emit ProposalCreated(
            proposalId,
            _msgSender(),
            targets,
            values,
            calldatas,
            snapshot,
            deadline,
            description
        );


        return proposalId;
    }

    /**
     * @dev See {IGovernor-execute}.
     */
    function execute(
        address targets,
        uint256 values,
        bytes memory calldatas,
        bytes32 descriptionHash
    ) public payable virtual override returns (uint256) {
        uint256 proposalId = hashProposal(
            targets,
            values,
            calldatas,
            descriptionHash
        );
        ProposalState status = state(proposalId);
        require(
            status == ProposalState.Succeeded,
            "DAO: proposal not successful"
        );
        _proposals[proposalId].executed = true;
        _finalProposalId = 0;
        emit ProposalExecuted(proposalId);

        _execute(proposalId, targets, values, calldatas, descriptionHash);

        if (_highestRateFor() != 0) {
            _setFinalProposal(_highestRateFor());
        }
        return proposalId;
    }

    /**
     * @dev Internal execution mechanism. Can be overriden to implement different execution mechanism
     */
    function _execute(
        uint256, /* proposalId */
        address targets,
        uint256 values,
        bytes memory calldatas,
        bytes32 /*descriptionHash*/
    ) internal virtual {
        (bool success, ) = targets.call{value: values}(calldatas);
    }

    /**
     * @dev See {IGovernor-castVote}.
     */
    function castVote(uint256 proposalId, uint8 support)
        public
        virtual
        override
        returns (uint256)
    {
        address voter = _msgSender();
        return _castVote(proposalId, voter, support, "");
    }

    /**
     * @dev See {IGovernor-castVoteWithReason}.
     */
    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) public virtual override returns (uint256) {
        address voter = _msgSender();
        return _castVote(proposalId, voter, support, reason);
    }

    /**
     * @dev See {IGovernor-castVoteBySig}.
     */
    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override returns (uint256) {
        address voter = ECDSA.recover(
            _hashTypedDataV4(
                keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support))
            ),
            v,
            r,
            s
        );
        return _castVote(proposalId, voter, support, "");
    }

    /**
     * @dev Internal vote casting mechanism: Check that the vote is pending, that it has not been cast yet, retrieve
     * voting weight using {IGovernor-getVotes} and call the {_countVote} internal function.
     *
     * Emits a {IGovernor-VoteCast} event.
     */
    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason
    ) internal virtual returns (uint256) {
        ProposalCore storage aProposal = _proposals[proposalId];
        require(state(proposalId) == ProposalState.Active, "FlashDao: you can't vote on non-active proposal");
        uint256 weight = getVotes(account, aProposal.voteStart.getDeadline()); // get amount of votes at block start
        _countVote(proposalId, account, support, weight);
        emit VoteCast(account, proposalId, support, weight, reason);
        return weight;
    }

    function _executor() internal view virtual returns (address) {
        return address(this);
    }
}
