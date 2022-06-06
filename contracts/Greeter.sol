//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


contract Greeter {
  uint public value;
  function setValue(uint _value) public {
    value = _value;
  }

}
