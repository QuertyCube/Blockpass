// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./EventContract.sol";

contract MasterContract {
    address public owner;
    address public treasuryContract;
    mapping(address => bool) public vendors;
    address[] public eventContracts;

    event EventCreated(address indexed eventAddress);
    event VendorAdded(address indexed vendor);
    event VendorRemoved(address indexed vendor);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyVendor() {
        require(vendors[msg.sender], "Not vendor");
        _;
    }

    constructor(address _treasuryContract) {
        owner = msg.sender;
        treasuryContract = _treasuryContract;
    }

    function addVendor(address _vendor) external onlyOwner {
        vendors[_vendor] = true;
        emit VendorAdded(_vendor);
    }

    function removeVendor(address _vendor) external onlyOwner {
        vendors[_vendor] = false;
        emit VendorRemoved(_vendor);
    }

    function createEvent(
        string memory _name,
        uint256 _start,
        uint256 _end,
        uint256 _startSale,
        uint256 _endSale,
        string[] memory _ticketTypes,
        uint256[] memory _prices,
        uint256[] memory _maxSupplies,
        address _usdcToken
    ) external onlyVendor returns (address) {
        EventContract newEvent = new EventContract(
            msg.sender, // Vendor sebagai eventOwner
            owner, // Owner utama dari MasterContract
            _usdcToken,
            treasuryContract,
            _name,
            _start,
            _end,
            _startSale,
            _endSale,
            _ticketTypes,
            _prices,
            _maxSupplies
        );
        eventContracts.push(address(newEvent));
        emit EventCreated(address(newEvent));
        return address(newEvent);
    }
}
