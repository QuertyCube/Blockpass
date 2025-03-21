// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./EventContract.sol";
import "./MasterOwnerModifier.sol";

contract MasterContract {
    address public owner;
    address public immutable treasuryContract;
    address public immutable usdc_token;
    MasterOwnerModifier public immutable masterOwnerModifier;

    address[] public eventContracts;

    event EventCreated(address indexed eventAddress);
    event FundsWithdrawn(address indexed owner, uint256 amount);

    constructor(address _treasuryContract, address _usdc_token,address _ownerModifierAddress) {
        owner = msg.sender;
        treasuryContract = _treasuryContract;
        usdc_token = _usdc_token;
        masterOwnerModifier = MasterOwnerModifier(_ownerModifierAddress);
    }

    modifier onlyOwner() {
        require(masterOwnerModifier.isMasterOwner(msg.sender), "Caller is not an owner");
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
    }

    function addOwner(address _newOwner) external onlyOwner {
        masterOwnerModifier.addMasterOwner(_newOwner);
    }

    // Function to remove an owner using OwnerModifier contract
    function removeOwner(address _owner) public {
        masterOwnerModifier.removeMasterOwner(_owner);
    }

    /// @notice Creates a new event contract
    /// @param params The parameters for the new event
    /// @return The address of the newly created event contract
    function createEvent(EventParams memory params) external returns (address) {
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
            usdc_token,
            treasuryContract,
            address(masterOwnerModifier), // Pass the ownerModifier address
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

    /// @notice Withdraws Ether from the contract to the treasury contract
    /// @param amount The amount of Ether to withdraw
    function withdraw(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        payable(treasuryContract).transfer(amount);
        emit FundsWithdrawn(treasuryContract, amount);
    }
}
