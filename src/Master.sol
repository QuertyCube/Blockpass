// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./EventContract.sol";
import "./MasterOwnerModifier.sol";


contract MasterContract {
    address public immutable treasuryContract;
    address public immutable usdc_token;
    MasterOwnerModifier public immutable masterOwnerModifier;

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
        masterOwnerModifier = MasterOwnerModifier(_ownerModifierAddress);
    }

    modifier onlyOwner() {
        require(masterOwnerModifier.isMasterOwner(msg.sender), "Caller is not an owner");
        _;
    }

    /// @notice Creates a new event contract
    /// @return The address of the newly created event contract
    function createEvent(        bytes32 name,
        bytes32 nftSymbol,
        uint256 start,
        uint256 end,
        uint256 startSale,
        uint256 endSale
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
            endSale
        );

        eventContracts[eventCount] = address(newEvent);
        unchecked { eventCount++; }
        emit EventCreated(address(newEvent));
        return address(newEvent);
    }

    /// @notice Allows the contract to receive Ether
    receive() external payable {}

    /// @notice Withdraws Ether from the contract to the treasury contract
    /// @param amount The amount of Ether to withdraw
    function withdraw(uint256 amount) external onlyOwner {
        if (amount > address(this).balance) {revert("Insufficient balance");}
        (bool success, ) = treasuryContract.call{value: amount}("");
        require(success, "Transfer failed");
        emit FundsWithdrawn(treasuryContract, amount);
    }

    /// @notice Returns all event contracts created
    /// @return An array of addresses of all event contracts
    function getAllEvents() external view returns (address[] memory) {
        address[] memory events = new address[](eventCount);
        for (uint256 i = 0; i < eventCount; i++) {
            events[i] = eventContracts[i];
        }
        return events;
    }
}
