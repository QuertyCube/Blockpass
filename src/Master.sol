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
    event FundsWithdrawn(address indexed owner, uint256 amount);

    modifier onlyOwner() {
        require(owners[msg.sender], "Not owner");
        _;
    }

    modifier onlyVendor() {
        require(vendors[msg.sender], "Not vendor");
        _;
    }

    struct TicketInfo {
        string ticketType;
        uint256 price;
        uint256 maxSupply;
    }

    struct EventParams {
        string name;
        string nftSymbol;
        uint256 start;
        uint256 end;
        uint256 startSale;
        uint256 endSale;
        TicketInfo[] ticketInfos;
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

    /// @notice Creates a new event contract
    /// @param params The parameters for the new event
    /// @return The address of the newly created event contract
    function createEvent(EventParams memory params) external onlyVendor returns (address) {
        require(params.start < params.end, "Invalid event timing");
        require(params.startSale < params.endSale, "Invalid sale timing");
        require(params.ticketInfos.length > 0, "Invalid ticket data");

        EventContract.Ticket[] memory tickets = new EventContract.Ticket[](params.ticketInfos.length);
        for (uint256 i = 0; i < params.ticketInfos.length; i++) {
            tickets[i] = EventContract.Ticket({
                ticketType: params.ticketInfos[i].ticketType,
                price: params.ticketInfos[i].price,
                maxSupply: params.ticketInfos[i].maxSupply,
                minted: 0
            });
        }

        EventContract newEvent = new EventContract(
            msg.sender, // Vendor as eventOwner
            owner, // Main owner of the MasterContract
            params.usdcToken,
            treasuryContract,
            params.name,
            params.nftSymbol,
            params.start,
            params.end,
            params.startSale,
            params.endSale,
            tickets
        );

        eventContracts.push(address(newEvent));
        emit EventCreated(address(newEvent));
        return address(newEvent);
    }

    /// @notice Returns all event contracts created
    /// @return An array of addresses of all event contracts
    function getAllEvents() external view returns (address[] memory) {
        return eventContracts;
    }

    /// @notice Allows the contract to receive Ether
    receive() external payable {}

    /// @notice Withdraws Ether from the contract
    /// @param amount The amount of Ether to withdraw
    function withdraw(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        payable(owner).transfer(amount);
        emit FundsWithdrawn(owner, amount);
    }
}

/*

 {
  "name": "My Event",
  "nftSymbol": "MEVT",
  "start": 1672531200, // Unix timestamp for event start
  "end": 1672617600, // Unix timestamp for event end
  "startSale": 1672444800, // Unix timestamp for ticket sale start
  "endSale": 1672527600, // Unix timestamp for ticket sale end
  "ticketInfos": [
    {
      "ticketType": "VIP",
      "price": 1000000000000000000, // 1 USDC in wei (assuming 18 decimals)
      "maxSupply": 100
    },
    {
      "ticketType": "Regular",
      "price": 500000000000000000, // 0.5 USDC in wei (assuming 18 decimals)
      "maxSupply": 500
    }
  ],
  "usdcToken": "0xYourUSDCContractAddress"
}

 */
