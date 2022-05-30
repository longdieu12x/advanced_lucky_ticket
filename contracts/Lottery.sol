//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/** 
Requirements:
- One user can buy from 1 ticket to 50 ticket
- It will last for X days (constructor)
- After X days, roll the lottery
- fee per ticket 0.04
- Choose 1 ticket for jacket 1 ether
- Choose 1 ticket for lucky 0.02 ether
- user can get their own losing ticket
- When rolling, winner can get money already
*/

import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Lottery is Ownable, VRFConsumerBase {
    using SafeCast for uint256;
    // random number configurations
    bytes32 internal _keyHash =
        0xcaf3c3727e033261d383b315559476f48034c13b18f8cafed4d871abe5049186;
    address private _vrfCoordinator =
        0xa555fC018435bef5A13C6c6870a9d4C11DEC329C;
    address private _linkToken = 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06;
    uint256 vrfFee = 0.1 * 10**18;
    uint256 _randomResult;
    // handler
    using Counters for Counters.Counter;
    mapping(address => mapping(uint256 => uint16)) public users; // address => session => ticket
    mapping(uint256 => mapping(uint256 => address)) public addressParticipants; // session => idx => address
    mapping(uint256 => uint256) locktimePerSession;
    mapping(uint256 => mapping(address => uint256))
        public ownerWinningLuckyTicket;
    mapping(uint256 => mapping(address => uint256))
        public ownerWinningJacketTicket;
    mapping(uint256 => uint64) public totalTickets; // session => total
    Counters.Counter currentSession;
    Counters.Counter involvesIdx;
    uint256 public ticketFee = 0;
    uint256 public jacketReward = 100000;
    uint256 public luckyReward = 5000;
    uint16 public totalTicketPerPeriod;
    uint256 public ticketCost = 1000; // 1000 wei
    uint32 public period = 5 * 24 * 3600;
    address private daoTreasury;

    // EVENTS
    event RandomWinner(address, uint8, uint256, uint256);
    event BuyTicket(address, uint16);
    // MODIFIERS
    modifier isTimeForRolling() {
        require(
            block.timestamp.toUint128() >=
                locktimePerSession[currentSession.current()],
            "Not right time for rolling"
        );
        _;
    }

    // LET GO
    constructor(
        uint16 _totalTicketPerPeriod,
        uint32 _period,
        address daoTreasury_
    ) VRFConsumerBase(_vrfCoordinator, _linkToken) {
        period = _period;
        totalTicketPerPeriod = _totalTicketPerPeriod;
        daoTreasury = payable(daoTreasury_);
    }

    function getRandomNumber() public returns (bytes32 requestId) {
        require(
            LINK.balanceOf(address(this)) >= vrfFee,
            "Not enough fee LINK in contract"
        );
        return requestRandomness(_keyHash, vrfFee);
    }

    function fulfillRandomness(bytes32, uint256 randomness) internal override {
        _randomResult = randomness;
    }

    function generateRandomNum(uint256 mod) public view returns (uint256) {
        uint256 randomNumber = uint256(
            keccak256(
                abi.encodePacked(
                    _randomResult,
                    block.timestamp,
                    msg.sender,
                    block.difficulty
                )
            )
        );
        return randomNumber % mod;
    }
    function setTicketFee(uint _ticketFee) public onlyOwner {
        ticketFee = _ticketFee;
    }
    function setPeriod(uint32 _period) public onlyOwner {
        period = _period;
    }

    /**
    @dev this function will set time lock for current session for rolling ticket
    */
    function setLockTime(uint128 lockTime_) public onlyOwner {
        locktimePerSession[currentSession.current()] = lockTime_;
    }

    function generateRandomNumber(uint256 _mod) public view returns (uint256) {
        uint256 randomNumber = uint256(
            keccak256(abi.encodePacked(block.timestamp, msg.sender))
        );
        return randomNumber % _mod;
    }

    function buyTicket(uint16 _ticketAmount) public payable {
        uint256 totalFee = ticketFee * _ticketAmount;
        uint256 totalAmount = _ticketAmount * ticketCost;
        require(msg.value >= totalFee + totalAmount, "Not enough fee");
        require(
            users[msg.sender][currentSession.current()] + _ticketAmount <= 50,
            "Overallowance ticket per period"
        );
        require(
            totalTickets[currentSession.current()] + _ticketAmount <=
                totalTicketPerPeriod,
            "Maximum of all market in a period is 50000"
        );
        if (msg.value - totalAmount != 0){
            (bool success, ) = payable(daoTreasury).call{value: totalFee}("");
            require(success, "Can't transfer money to dao treasury");
        }
        if (users[msg.sender][currentSession.current()] == 0) {
            addressParticipants[currentSession.current()][
                involvesIdx.current()
            ] = msg.sender;
            involvesIdx.increment();
        }
        users[msg.sender][currentSession.current()] += _ticketAmount;
        totalTickets[currentSession.current()] += _ticketAmount;
    }

    function randomTicketLucky()
        public
        isTimeForRolling
        onlyOwner
        returns (address)
    {
        uint256 luckyNumber = generateRandomNumber(
            totalTickets[currentSession.current()]
        ); // Lucky
        uint256 total = 0;
        uint256 winnerIdx = 0;
        uint256 rewardLucky = 0;
        for (uint256 i = 0; i <= involvesIdx.current(); i++) {
            total += users[addressParticipants[currentSession.current()][i]][
                currentSession.current()
            ];
            if (total >= luckyNumber && rewardLucky == 0) {
                // Transfer reward to user
                address userWinningLucky = addressParticipants[
                    currentSession.current()
                ][i];
                //(bool success, ) = payable(userWinningLucky).call{value: luckyReward}("");
                //require(success, "Reward lucky failed");
                rewardLucky++;
                ownerWinningLuckyTicket[currentSession.current()][
                    userWinningLucky
                ] += 1;
                users[userWinningLucky][currentSession.current()] -= 1;
                totalTickets[currentSession.current()] -= 1;
                winnerIdx = i;
                break;
            }
        }
        return addressParticipants[currentSession.current()][winnerIdx];
    }

    function resetWheel() public onlyOwner isTimeForRolling {
        currentSession.increment();
        locktimePerSession[currentSession.current()] =
            block.timestamp.toUint128() +
            period;
    }

    function randomTicketJacket()
        public
        isTimeForRolling
        onlyOwner
        returns (address)
    {
        uint256 jacketNumber = generateRandomNumber(
            totalTickets[currentSession.current()]
        ); // Jacket
        uint256 total = 0;
        uint256 winnerIdx = 0;
        uint256 rewardJacket = 0;
        for (uint256 i = 0; i <= involvesIdx.current(); i++) {
            total += users[addressParticipants[currentSession.current()][i]][
                currentSession.current()
            ];
            if (total >= jacketNumber && rewardJacket == 0) {
                // Transfer reward to user
                address userWinningJacket = addressParticipants[
                    currentSession.current()
                ][i];
                //(bool success, ) = payable(userWinningJacket).call{value: jacketReward}("");
                //require(success, "Reward jacket failed");
                ownerWinningJacketTicket[currentSession.current()][
                    userWinningJacket
                ] += 1;
                users[userWinningJacket][currentSession.current()] -= 1;
                totalTickets[currentSession.current()] -= 1;
                winnerIdx = i;
                rewardJacket++;
            }
        }
        return addressParticipants[currentSession.current()][winnerIdx];
    }

    function getBalanceContract() public view returns (uint256) {
        return address(this).balance;
    }

    function getTotalTicketLose() public view returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i <= currentSession.current(); i++) {
            total += users[msg.sender][i];
        }
        return total;
    }

    function getTotalTicketLoseAvailable() public view returns (uint256) {
        uint256 total;
        if (currentSession.current() == 0){
            return 0;
        }
        for (uint256 i = 0; i <= currentSession.current() - 1; i++) {
            total += users[msg.sender][i];
        }
        return total;
    }

    function claimRewards() public payable {
        uint256 totalRewards = getTotalTicketLoseAvailable();
        require(totalRewards > 0, "Not exist available losing ticket!");
        (bool success, ) = payable(msg.sender).call{
            value: totalRewards * ticketCost
        }("");
        require(success, "Claim ticket lose failed!");
    }

    function getOwnerLuckyTicket() public view returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i <= currentSession.current(); i++) {
            total += ownerWinningLuckyTicket[i][
                msg.sender
            ];
        }
        return total;
    }

    function getOwnerLuckyTicketAvailable() public view returns (uint256) {
        uint256 total;
        if (currentSession.current() == 0){
            return 0;
        }
        for (uint256 i = 0; i <= currentSession.current() - 1; i++) {
            total += ownerWinningLuckyTicket[i][
                msg.sender
            ];
        }
        return total;
    }

    function claimLucky() public payable {
        uint256 totalLucky = getOwnerLuckyTicketAvailable();
        require(totalLucky > 0, "Not exist available lucky ticket!");
        (bool success, ) = payable(msg.sender).call{
            value: totalLucky * luckyReward
        }("");
        require(success, "Claim ticket lose failed!");
    }

    function getOwnerJacketTicket() public view returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i <= currentSession.current(); i++) {
            total += ownerWinningJacketTicket[i][
                msg.sender
            ];
        }
        return total;
    }

    function getOwnerJacketTicketAvailable() public view returns (uint256) {
        uint256 total;
        if (currentSession.current() == 0){
            return 0;
        }
        for (uint256 i = 0; i <= currentSession.current() - 1; i++) {
            total += ownerWinningJacketTicket[i][
                msg.sender
            ];
        }
        return total;
    }

    function claimJacket() public payable {
        uint256 totalJacket = getOwnerJacketTicketAvailable();
        require(totalJacket > 0, "Not exist available jacket ticket!");
        (bool success, ) = payable(msg.sender).call{
            value: (totalJacket * jacketReward)
        }("");
        require(success, "Claim jacket lose failed!");
    }

    function getAddressParticipant(uint256 _session, uint256 _id)
        public
        view
        returns (address)
    {
        return addressParticipants[_session][_id];
    }
    // Fallback function is called when msg.data is not empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}
