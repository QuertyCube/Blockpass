// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract EventContract is ERC721Enumerable, Pausable {
    address public eventOwner;
    address public masterOwner;
    address public treasuryContract;
    string public eventName;
    uint256 public eventStart;
    uint256 public eventEnd;
    uint256 public eventTiketStartSale;
    uint256 public eventTiketEndSale;
    bool public isCancelled = false;

    IERC20 public usdcToken;

    struct Ticket {
        string ticketType;
        uint256 price;
        uint256 maxSupply;
        uint256 minted;
    }

    mapping(string => Ticket) public tickets;
    mapping(uint256 => string) public ticketTypesById;
    mapping(address => bool) public additionalEventOwners;
    string[] public ticketTypes;
    uint256 public totalRevenue;
    uint256 private _nextTokenId = 1;

    event TicketMinted(address indexed buyer, string ticketType, uint256 tokenId);
    event TicketUsed(uint256 tokenId);
    event FundsWithdrawn(address indexed vendor, uint256 vendorAmount, uint256 treasuryAmount);
    event EventCancelled(string reason);
    event TicketTransferred(address indexed from, address indexed to, uint256 tokenId);
    event TicketRefunded(address indexed buyer, uint256 tokenId, uint256 amount);

    modifier onlyEventOwner() {
        require(msg.sender == eventOwner || additionalEventOwners[msg.sender], "Not event owner");
        _;
    }

    modifier onlyMasterOwner() {
        require(msg.sender == masterOwner, "Not master owner");
        _;
    }

    modifier onlyVendorOrOwner() {
        require(msg.sender == eventOwner || msg.sender == masterOwner, "Not vendor or owner");
        _;
    }

    /**
     * @dev Constructor to initialize the contract.
     * @param _vendor Address of the event vendor.
     * @param _masterOwner Address of the master owner.
     * @param _usdcToken Address of the USDC token contract.
     * @param _treasuryContract Address of the treasury contract.
     * @param _name Name of the event.
     * @param _nftSymbol Symbol of the NFT.
     * @param _start Start timestamp of the event.
     * @param _end End timestamp of the event.
     * @param _startSale Start timestamp of the ticket sale.
     * @param _endSale End timestamp of the ticket sale.
     * @param _tickets Array of Ticket structs containing ticket details.
     */
    constructor(
        address _vendor,
        address _masterOwner,
        address _usdcToken,
        address _treasuryContract,
        string memory _name,
        string memory _nftSymbol,
        uint256 _start,
        uint256 _end,
        uint256 _startSale,
        uint256 _endSale,
        Ticket[] memory _tickets
    ) ERC721(_name, _nftSymbol) {
        eventOwner = _vendor;
        masterOwner = _masterOwner;
        usdcToken = IERC20(_usdcToken);
        treasuryContract = _treasuryContract;
        eventName = _name;
        eventStart = _start;
        eventEnd = _end;
        eventTiketStartSale = _startSale;
        eventTiketEndSale = _endSale;

        for (uint256 i = 0; i < _tickets.length; i++) {
            tickets[_tickets[i].ticketType] = _tickets[i];
            ticketTypes.push(_tickets[i].ticketType);
        }
    }

    /**
     * @dev Function to mint a new ticket.
     * @param _ticketType The type of the ticket to be minted.
     */
    function mintTicket(string memory _ticketType) external whenNotPaused {
        require(!isCancelled, "Event is cancelled");
        require(
            block.timestamp >= eventTiketStartSale && block.timestamp <= eventTiketEndSale, "Ticket sale not active"
        );

        Ticket storage ticket = tickets[_ticketType];
        require(ticket.minted < ticket.maxSupply, "Sold out");

        require(usdcToken.transferFrom(msg.sender, address(this), ticket.price), "USDC payment failed");

        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);
        ticketTypesById[tokenId] = _ticketType;
        ticket.minted++;
        totalRevenue += ticket.price;

        emit TicketMinted(msg.sender, _ticketType, tokenId);
    }

    /**
     * @dev Function to get all tickets owned by a user.
     * @param _user The address of the user.
     * @return ticketIds Array of ticket IDs owned by the user.
     * @return ticketTypesArray Array of ticket types owned by the user.
     */
    function getUserTickets(address _user) external view returns (uint256[] memory, string[] memory) {
        uint256 balance = balanceOf(_user);
        uint256[] memory ticketIds = new uint256[](balance);
        string[] memory ticketTypesArray = new string[](balance);

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(_user, i);
            ticketIds[i] = tokenId;
            ticketTypesArray[i] = ticketTypesById[tokenId];
        }

        return (ticketIds, ticketTypesArray);
    }

    /**
     * @dev Function to use a ticket.
     * @param _tokenId The ID of the ticket to be used.
     */
    function useTicket(uint256 _tokenId) external whenNotPaused {
        require(ownerOf(_tokenId) == msg.sender, "Not ticket owner");
        _burn(_tokenId);
        emit TicketUsed(_tokenId);
    }

    /**
     * @dev Function to transfer a ticket to another user.
     * @param _to The address of the recipient.
     * @param _tokenId The ID of the ticket to be transferred.
     */
    function transferTicket(address _to, uint256 _tokenId) external whenNotPaused {
        require(ownerOf(_tokenId) == msg.sender, "Not ticket owner");
        _transfer(msg.sender, _to, _tokenId);
        emit TicketTransferred(msg.sender, _to, _tokenId);
    }

    /**
     * @dev Function to withdraw funds after the event ends.
     */
    function withdrawFunds() external onlyVendorOrOwner whenNotPaused {
        require(block.timestamp > eventEnd, "Event is not over yet");
        require(!isCancelled, "Cannot withdraw, event cancelled");
        require(totalRevenue > 0, "No funds available");

        uint256 treasuryAmount = totalRevenue / 100; // 1% for treasury
        uint256 vendorAmount = totalRevenue - treasuryAmount;

        require(usdcToken.transfer(eventOwner, vendorAmount), "Vendor withdrawal failed");
        require(usdcToken.transfer(treasuryContract, treasuryAmount), "Treasury transfer failed");

        emit FundsWithdrawn(eventOwner, vendorAmount, treasuryAmount);
        totalRevenue = 0;
    }

    /**
     * @dev Function to cancel the event and refund all ticket holders.
     * @param reason The reason for cancelling the event.
     */
    function cancelEvent(string memory reason) external onlyMasterOwner {
        isCancelled = true;
        emit EventCancelled(reason);
        // Refund all ticket holders
        uint256 totalSupply = totalSupply();
        for (uint256 i = 0; i < totalSupply; i++) {
            uint256 tokenId = tokenByIndex(i);
            address ticketOwner = ownerOf(tokenId);
            string memory ticketType = ticketTypesById[tokenId];
            uint256 refundAmount = tickets[ticketType].price;

            _burn(tokenId);
            require(usdcToken.transfer(ticketOwner, refundAmount), "Refund failed");
            emit TicketRefunded(ticketOwner, tokenId, refundAmount);
        }

        totalRevenue = 0;
    }

    /**
     * @dev Function to claim a refund for a specific ticket.
     * @param _tokenId The ID of the ticket to be refunded.
     */
    function claimRefund(uint256 _tokenId) external {
        require(isCancelled, "Event is not cancelled");
        require(ownerOf(_tokenId) == msg.sender, "Not ticket owner");

        string memory ticketType = ticketTypesById[_tokenId];
        uint256 refundAmount = tickets[ticketType].price;

        // Attempt to transfer the refund amount before burning the token
        bool refundSuccess = usdcToken.transfer(msg.sender, refundAmount);
        require(refundSuccess, "Refund failed");

        // Burn the token only if the refund was successful
        _burn(_tokenId);
        emit TicketRefunded(msg.sender, _tokenId, refundAmount);
    }

    /**
     * @dev Function to add a new event owner.
     * @param _newOwner The address of the new event owner.
     */
    function addEventOwner(address _newOwner) external onlyEventOwner {
        require(_newOwner != address(0), "Invalid address");
        additionalEventOwners[_newOwner] = true;
    }

    /**
     * @dev Function to remove an event owner.
     * @param _owner The address of the event owner to be removed.
     */
    function removeEventOwner(address _owner) external onlyEventOwner {
        require(_owner != address(0), "Invalid address");
        additionalEventOwners[_owner] = false;
    }

    /**
     * @dev Function to pause the contract.
     */
    function pause() external onlyMasterOwner {
        _pause();
    }

    /**
     * @dev Function to unpause the contract.
     */
    function unpause() external onlyMasterOwner {
        _unpause();
    }
}
