// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./EventContract.sol";
import "./MasterOwnerModifier.sol";
import "./EventLibrary.sol";

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
    /// @param params The parameters for the new event
    /// @return The address of the newly created event contract
    function createEvent(EventLibrary.EventParams calldata params) external returns (address) {
        if (params.start >= params.end) revert InvalidEventTiming();
        if (params.startSale >= params.endSale) revert InvalidSaleTiming();
        if (params.ticketInfos.length == 0) revert InvalidTicketData();

        EventContract newEvent = new EventContract(
            msg.sender, // Vendor as eventOwner
            usdc_token,
            treasuryContract,
            address(masterOwnerModifier), // Pass the ownerModifier address
            params.name,
            params.nftSymbol,
            params.start,
            params.end,
            params.startSale,
            params.endSale,
            params.ticketInfos
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
}
