//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./DaoVotes.sol";

abstract contract DaoQuorum is DaoVotes {
  uint256 private _numeratorIdea = 15;
  uint256 private _numeratorFinal = 50;
  function quorum(uint256 blockNumber, bool isFinal) public virtual override view returns(uint256){
      return token.getPastTotalSupply(blockNumber) * numerator(isFinal) / deminator();
  }
  function deminator() public pure returns(uint256){
    return 100;
  }
    
  function numerator(bool isFinal) public view returns(uint256){
    if(isFinal) return _numeratorFinal;
    else return _numeratorIdea;
  }
}