//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "./Dao.sol";


/**
  @dev at this contract we will define
  {getVotes},
 */
abstract contract DaoVotes is Dao{
  IVotes immutable public token;
  constructor(IVotes _token){
    token = _token;
  }
  function getVotes(address account, uint256 blockNumber) public view virtual override returns(uint256){
     return token.getPastVotes(account, blockNumber);
  }
}