//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;
import "./Dao.sol";
import "./DaoCountVotes.sol";
import "./DaoVotes.sol";
import "./DaoQuorum.sol";

contract FlashDao is Dao, DaoCountVotes, DaoVotes, DaoQuorum {
    constructor(IVotes token_) Dao("Flash Dao") DaoVotes(token_) {}

    function quorum(uint256 blockNumber, bool isFinal)
        public
        view
        override(IDao, DaoQuorum)
        returns (uint256)
    {
        return super.quorum(blockNumber, isFinal);
    }

    function getVotes(address account, uint256 blockNumber)
        public
        view
        override(Dao, DaoVotes)
        returns (uint256)
    {
        return super.getVotes(account, blockNumber);
    }

    function proposalForRate(uint256 proposalId)
        public
        view
        override
        returns (uint256)
    {
        return super.proposalForRate(proposalId);
    }

    function state(uint256 proposalId)
        public
        view
        override(Dao)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }
    
    function setFirstFinalProposal() public virtual override(Dao) returns(uint256) {
        return super.setFirstFinalProposal();
    }

    function propose(
        address targets,
        uint256 values,
        bytes memory calldatas,
        string memory description
    ) public override(Dao) returns (uint256) {
        require(
            token.getPastTotalSupply(block.number - 1) >= 50,
            "WinDAO:Insufficient total supply"
        );
        return super.propose(targets, values, calldatas, description);
    }

    function proposalThreshold() public view override(Dao) returns (uint256) {
        return super.proposalThreshold();
    }

    function _execute(
        uint256 proposalId,
        address targets,
        uint256 values,
        bytes memory calldatas,
        bytes32 descriptionHash
    ) internal override(Dao) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Dao) returns (address) {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Dao)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
