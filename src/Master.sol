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
    error InsufficientBalance();
    error TransferFail();

    constructor(address _treasuryContract, address _usdc_token, address _ownerModifierAddress) {
        treasuryContract = _treasuryContract;
        usdc_token = _usdc_token;
        masterOwnerModifier = _ownerModifierAddress;
    }

    modifier onlyOwner() {
        require(IMasterOwnerModifier(masterOwnerModifier).isMasterOwner(msg.sender), NotOwner());
        _;
    }

    /// @notice Creates a new event contract
    /// @return The address of the newly created event contract
    function createEvent(
        string memory _name,
        string memory _nftSymbol,
        uint256 _start,
        uint256 _end,
        uint256 _startSale,
        uint256 _endSale
    ) external returns (address) {
        if (_start >= _end) revert InvalidEventTiming();
        if (_startSale >= _endSale) revert InvalidSaleTiming();

        EventContract newEvent = new EventContract(
            msg.sender, // Vendor as eventOwner
            usdc_token,
            treasuryContract,
            address(masterOwnerModifier), // Pass the ownerModifier address
            _name,
            _nftSymbol,
            _start,
            _end,
            _startSale,
            _endSale

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
        if (amount > address(this).balance) {revert InsufficientBalance();}
        (bool success, ) = treasuryContract.call{value: amount}("");
        if (!success) {revert TransferFail();}
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
