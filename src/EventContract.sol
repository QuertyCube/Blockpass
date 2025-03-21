// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MasterOwnerModifier.sol";

contract EventContract is ERC721Enumerable {
    address public eventOwner;
    address public treasuryContract;
    IERC20 public usdcToken;
    MasterOwnerModifier public masterOwnerModifier;

    string public eventName;
    bytes32[] public ticketTypes;

    uint256 public eventStart;
    uint256 public eventEnd;
    uint256 public eventTiketStartSale;
    uint256 public eventTiketEndSale;
    uint256 public totalRevenue;
    uint256 private _nextTokenId = 1;

    bool public isCancelled = false;

    struct Ticket {
        bytes32 ticketType;
        uint256 price;
        uint256 maxSupply;
        uint256 minted;
    }

    mapping(bytes32 => Ticket) public tickets;
    mapping(uint256 => bytes32) public ticketTypesById;
    mapping(address => bool) public additionalEventOwners;

    event EventCancelled(string reason);
    event FundsWithdrawn(address indexed vendor, uint256 vendorAmount, uint256 treasuryAmount);
    event TicketMinted(address indexed buyer, bytes32 ticketType, uint256 tokenId);
    event TicketRefunded(address indexed buyer, uint256 tokenId, uint256 amount);
    event TicketUsed(uint256 tokenId);

    error EventNotCancel();
    error TicketSoldOut();
    error TicketSaleNotActive();
    error PaymentFailed();
    error NotTicketOwner();
    error EventNotOver();
    error NoFundsAvailable();
    error InvalidAddress();
    error NotEventOwner();
    error NotMasterOwner();
    error NotMasterOrEventOwner();

    modifier onlyEventOwner() {
        if (msg.sender != eventOwner && !additionalEventOwners[msg.sender]) revert NotEventOwner();
        _;
    }

    modifier onlyMasterOwner() {
        if (!masterOwnerModifier.isMasterOwner(msg.sender)) revert NotMasterOwner();
        _;
    }

    modifier onlyVendorOrOwner() {
        if (msg.sender != eventOwner && !masterOwnerModifier.isMasterOwner(msg.sender)) revert NotMasterOrEventOwner();
        _;
    }

    /**
     * @dev Constructor to initialize the contract.
     * @param _vendor Address of the event vendor.
     * @param _usdcToken Address of the USDC token contract.
     * @param _treasuryContract Address of the treasury contract.
     * @param _name Name of the event.
     * @param _nftSymbol Symbol of the NFT.
     * @param _start Start timestamp of the event.
     * @param _end End timestamp of the event.
     * @param _startSale Start timestamp of the ticket sale.
     * @param _endSale End timestamp of the ticket sale.
     */
    constructor(
        address _vendor,
        address _usdcToken,
        address _treasuryContract,
        address _ownerModifierAddress,
        bytes32 _name,
        bytes32 _nftSymbol,
        uint256 _start,
        uint256 _end,
        uint256 _startSale,
        uint256 _endSale
    ) ERC721(string(abi.encodePacked(_name)), string(abi.encodePacked(_nftSymbol))) {
        eventOwner = _vendor;
        usdcToken = IERC20(_usdcToken);
        treasuryContract = _treasuryContract;
        masterOwnerModifier = MasterOwnerModifier(_ownerModifierAddress);
        eventName = string(abi.encodePacked(_name));
        eventStart = _start;
        eventEnd = _end;
        eventTiketStartSale = _startSale;
        eventTiketEndSale = _endSale;

    }

    function addTickets(bytes32[] calldata _ticketTypes, uint256[] calldata _prices, uint256[] calldata _maxSupplies
    ) external onlyEventOwner {
        require(_ticketTypes.length == _prices.length && _ticketTypes.length == _maxSupplies.length, "Invalid ticket data");

        for (uint256 i = 0; i < _ticketTypes.length; i++) {
            tickets[_ticketTypes[i]] = Ticket({
                ticketType: _ticketTypes[i],
                price: _prices[i],
                maxSupply: _maxSupplies[i],
                minted: 0
            });
            ticketTypes.push(_ticketTypes[i]);
        }
    }


    /**
     * @dev Function to mint a new ticket.
     * @param _ticketType The type of the ticket to be minted.
     */
    function mintTicket(bytes32 _ticketType) external {
        if (isCancelled) revert EventNotCancel();
        if (block.timestamp < eventTiketStartSale || block.timestamp > eventTiketEndSale) revert TicketSaleNotActive();
    
        Ticket storage ticket = tickets[_ticketType];
        if (ticket.minted >= ticket.maxSupply) revert TicketSoldOut();
        if (!usdcToken.transferFrom(msg.sender, address(this), ticket.price)) revert PaymentFailed();
        
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
    function getUserTickets(address _user) external view returns (uint256[] memory, bytes32[] memory) {
        uint256 balance = balanceOf(_user);
        uint256[] memory ticketIds = new uint256[](balance);
        bytes32[] memory ticketTypesArray = new bytes32[](balance);

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
    function useTicket(uint256 _tokenId) external {
        if (ownerOf(_tokenId) != msg.sender) revert NotTicketOwner();
        _burn(_tokenId);
        emit TicketUsed(_tokenId);
    }

    /**
     * @dev Function to modify the max supply of a ticket type.
     * @param _ticketType The type of the ticket to be modified.
     * @param _newMaxSupply The new max supply for the ticket type.
     */
    function modifyTicketMaxSupply(bytes32 _ticketType, uint256 _newMaxSupply) external onlyEventOwner {
        if (_newMaxSupply == 0) revert("Max supply must be greater than zero");
        Ticket storage ticket = tickets[_ticketType];
        if (ticket.maxSupply == 0) revert("Ticket type does not exist");
        if (_newMaxSupply < ticket.minted) revert("New max supply cannot be less than minted tickets");

        ticket.maxSupply = _newMaxSupply;
    }

    /**
     * @dev Function to withdraw funds after the event ends.
     */
    function withdrawFunds() external onlyVendorOrOwner {
        if (block.timestamp <= eventEnd) revert EventNotOver();
        if (isCancelled) revert EventNotCancel();
        if (totalRevenue == 0) revert NoFundsAvailable();

        uint256 treasuryAmount = totalRevenue / 100; // 1% for treasury
        uint256 vendorAmount = totalRevenue - treasuryAmount;

        if (!usdcToken.transfer(eventOwner, vendorAmount)) revert PaymentFailed();
        if (!usdcToken.transfer(treasuryContract, treasuryAmount)) revert PaymentFailed();

        emit FundsWithdrawn(eventOwner, vendorAmount, treasuryAmount);
        totalRevenue = 0;
    }

    /**
     * @dev Function to cancel the event and refund all ticket holders.
     * @param reason The reason for cancelling the event.
     */
    function cancelEventAndAutoRefund(string calldata reason) external onlyVendorOrOwner {
        if (isCancelled) revert EventNotCancel();
        isCancelled = true;
        emit EventCancelled(reason);
        // Refund all ticket holders
        uint256 totalSupply = totalSupply();
        for (uint256 i = 0; i < totalSupply; i++) {
            
            uint256 tokenId = tokenByIndex(i);
            address ticketOwner = ownerOf(tokenId);
            bytes32 ticketType = ticketTypesById[tokenId];
            uint256 refundAmount = tickets[ticketType].price;

            _burn(tokenId);
            if (!usdcToken.transfer(ticketOwner, refundAmount)) revert PaymentFailed();
            emit TicketRefunded(ticketOwner, tokenId, refundAmount);
        }
        totalRevenue = 0;
    }
    
    function getTicketDetails(bytes32 ticketType) public view returns (uint256 price, uint256 supply) {
        return (tickets[ticketType].price, tickets[ticketType].maxSupply);
    }
}
