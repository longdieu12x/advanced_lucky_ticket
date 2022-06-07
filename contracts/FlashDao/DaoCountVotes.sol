pragma solidity ^0.8.0;

import "./Dao.sol";

/**
  @dev at this contract we will define
  {_quorumReached},
  {_voteSucceeded},
  {_highestRateFor} ,
  {_resetCountVote},
  {_countVote}
 */
abstract contract DaoCountVotes is Dao {
    enum VoteType {
        Against,
        For
    }
    struct ProposalVote {
        uint256 againstVotes;
        uint256 forVotes;
        address[] votedAddress;
        mapping(address => bool) hasVoted;
    }

    mapping(uint256 => ProposalVote) private _proposalVotes;

    /**
     * @dev See {IGovernor-COUNTING_MODE}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function COUNTING_MODE() public pure virtual override returns (string memory) {
        return "support=bravo&quorum=for,abstain";
    }

    /**
     * @dev See {IGovernor-hasVoted}.
     */
    function hasVoted(uint256 proposalId, address account) public view virtual override returns (bool) {
        return _proposalVotes[proposalId].hasVoted[account];
    }

    /**
     * @dev Accessor to the internal vote counts.
     */
    function proposalVotes(uint256 proposalId)
        public
        view
        virtual
        returns (
            uint256 againstVotes,
            uint256 forVotes,
            address[] memory votedAddress

        )
    {
        ProposalVote storage proposalvote = _proposalVotes[proposalId];
        return (proposalvote.againstVotes, proposalvote.forVotes, proposalvote.votedAddress);
    }

    /**
     * @dev See {Governor-_quorumReached}.
     */
    function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
        ProposalVote storage proposalvote = _proposalVotes[proposalId];
        return quorum(proposalSnapshot(proposalId),  proposalId == _finalProposalId) <= proposalvote.forVotes + proposalvote.againstVotes;
    }

    /**
     * @dev See {Governor-_voteSucceeded}. In this module, the forVotes must be strictly over the againstVotes.
     */
    function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
        ProposalVote storage proposalvote = _proposalVotes[proposalId];
        return proposalvote.forVotes > proposalvote.againstVotes;
    }

    /**
     * @dev See {Governor-_countVote}. In this module, the support follows the `VoteType` enum (from Governor Bravo).
     */
    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight
    ) internal virtual override(Dao) {
        ProposalVote storage proposalvote = _proposalVotes[proposalId];
        require(!proposalvote.hasVoted[account], "DaoCountVotes: vote already cast");
        proposalvote.hasVoted[account] = true;
        proposalvote.votedAddress.push(account);
        if (support == uint8(VoteType.Against)) {
            proposalvote.againstVotes += weight;
        } else if (support == uint8(VoteType.For)) {
            proposalvote.forVotes += weight;
        } else {
            revert("DaoCountVotes: invalid value for enum VoteType");
        }
    }
    /**
      @dev returns index of highest rate in all proposals
     */
    function _highestRateFor() internal
        view
        virtual
        override(Dao)
        returns (uint256){
          uint highestRateProposalId = _proposalKeys[0];
          for (uint i = 0; i < _proposalKeys.length; i++){
            if (state(_proposalKeys[i]) == ProposalState.Queued && proposalForRate(_proposalKeys[i]) > proposalForRate(highestRateProposalId)){
              highestRateProposalId = _proposalKeys[i];
            }
          }
          return highestRateProposalId;
    }

        /**
     * @dev proposalForRate: percentage of rate in proposal
     */
    function proposalForRate(uint256 proposalId)
        public
        view
        virtual
        returns (uint256)
    {
        return _proposalVotes[proposalId].forVotes + _proposalVotes[proposalId].againstVotes == 0 ? 0 : uint256(_proposalVotes[proposalId].forVotes * 100 / (_proposalVotes[proposalId].forVotes + _proposalVotes[proposalId].againstVotes));
    }

    function _resetCountVote(uint256 proposalId) public virtual override {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        proposalVote.forVotes = 0;
        proposalVote.againstVotes = 0;
        for (uint256 i = 0; i < proposalVote.votedAddress.length; i++) {
            proposalVote.hasVoted[proposalVote.votedAddress[i]] = false;
        }
        delete proposalVote.votedAddress;
    }

}