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

    function createEvent(EventParams memory params) external onlyVendor returns (address) {
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
}
