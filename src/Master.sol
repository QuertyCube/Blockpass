// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./EventContract.sol";


contract MasterContract {
    address public immutable treasuryContract;
    address public immutable usdc_token;
    address public immutable masterOwnerModifier;

    mapping(uint256 => address) public eventContracts;
    uint256 public eventCount;

    event EventCreated(address indexed eventAddress);
    event FundsWithdrawn(address indexed owner, uint256 amount);

    error InvalidEventTiming();
    error InvalidSaleTiming();
    error InvalidTicketData();
    error NotOwner();

    constructor(address _treasuryContract, address _usdc_token, address _ownerModifierAddress) {
        treasuryContract = _treasuryContract;
        usdc_token = _usdc_token;
        masterOwnerModifier = _ownerModifierAddress;
    }

    modifier onlyOwner() {
        require(IMasterOwnerModifier(masterOwnerModifier).isMasterOwner(msg.sender), "Caller is not an owner");
        _;
    }

    function createEvent(
        bytes32 name,
        bytes32 nftSymbol,
        uint256 start,
        uint256 end,
        uint256 startSale,
        uint256 endSale,
        address ticketManager
    ) external returns (address) {
        if (start >= end) revert InvalidEventTiming();
        if (startSale >= endSale) revert InvalidSaleTiming();

        EventContract newEvent = new EventContract(
            msg.sender, // Vendor as eventOwner
            usdc_token,
            treasuryContract,
            address(masterOwnerModifier), // Pass the ownerModifier address
            name,
            nftSymbol,
            start,
            end,
            startSale,
            endSale,
            ticketManager
        );

        eventContracts[eventCount] = address(newEvent);
        unchecked { eventCount++; }
        emit EventCreated(address(newEvent));
        return address(newEvent);
    }

    receive() external payable {}

    function withdraw(uint256 amount) external onlyOwner {
        if (amount > address(this).balance) {revert("Insufficient balance");}
        (bool success, ) = treasuryContract.call{value: amount}("");
        require(success, "Transfer failed");
        emit FundsWithdrawn(treasuryContract, amount);
    }

    function getAllEvents() external view returns (address[] memory) {
        address[] memory events = new address[](eventCount);
        for (uint256 i = 0; i < eventCount; i++) {
            events[i] = eventContracts[i];
        }
        return events;
    }
}
