// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./EventContract.sol";

contract MasterContract {
    address public owner;
    address public treasuryContract;
    mapping(address => bool) public vendors;
    mapping(address => bool) public owners;
    address[] public eventContracts;

    event EventCreated(address indexed eventAddress);
    event VendorAdded(address indexed vendor);
    event VendorRemoved(address indexed vendor);
    event OwnerAdded(address indexed newOwner);

    modifier onlyOwner() {
        require(owners[msg.sender], "Not owner");
        _;
    }

    modifier onlyVendor() {
        require(vendors[msg.sender], "Not vendor");
        _;
    }

    struct EventParams {
        string name;
        string nftSymbol;
        uint256 start;
        uint256 end;
        uint256 startSale;
        uint256 endSale;
        string[] ticketTypes;
        uint256[] prices;
        uint256[] maxSupplies;
        address usdcToken;
    }

    constructor(address _treasuryContract) {
        owner = msg.sender;
        owners[msg.sender] = true;
        treasuryContract = _treasuryContract;
    }

    function addOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        owners[_newOwner] = true;
        emit OwnerAdded(_newOwner);
    }

    function addVendor(address _vendor) external onlyOwner {
        require(_vendor != address(0), "Invalid address");
        vendors[_vendor] = true;
        emit VendorAdded(_vendor);
    }

    function removeVendor(address _vendor) external onlyOwner {
        require(_vendor != address(0), "Invalid address");
        vendors[_vendor] = false;
        emit VendorRemoved(_vendor);
    }

    function createEvent(EventParams memory params) external onlyVendor returns (address) {
        require(params.start < params.end, "Invalid event timing");
        require(params.startSale < params.endSale, "Invalid sale timing");
        require(params.ticketTypes.length == params.prices.length && params.prices.length == params.maxSupplies.length, "Mismatched ticket data");
        
        EventContract newEvent = new EventContract(
            msg.sender, // Vendor sebagai eventOwner
            owner, // Owner utama dari MasterContract
            params.usdcToken,
            treasuryContract,
            params.name,
            params.nftSymbol,
            params.start,
            params.end,
            params.startSale,
            params.endSale,
            params.ticketTypes,
            params.prices,
            params.maxSupplies
        );

        eventContracts.push(address(newEvent));
        emit EventCreated(address(newEvent));
        return address(newEvent);
    }
    
    function getAllEvents() external view returns (address[] memory) {
        return eventContracts;
    }
}
