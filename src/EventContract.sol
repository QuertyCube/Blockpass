// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMasterOwnerModifier {
    function isMasterOwner(address user) external view returns (bool);
}

contract EventContract is ERC721Enumerable {
    address public eventOwner;
    address public treasuryContract;
    IERC20 public usdcToken;
    address public masterOwnerModifier;

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
        string ticketType;
        uint256 price;
        uint256 maxSupply;
        uint256 minted;
    }

    mapping(string => Ticket) public tickets;
    mapping(uint256 => string) public ticketTypesById;
    mapping(address => bool) public additionalEventOwners;

    event EventCancelled(string reason);
    event FundsWithdrawn(address indexed vendor, uint256 vendorAmount, uint256 treasuryAmount);
    event TicketMinted(address indexed buyer, string ticketType, uint256 tokenId);
    event TicketRefunded(address indexed buyer, uint256 tokenId, uint256 amount);
    event TicketUsed(uint256 tokenId);

    error EventAlreadyCancelled();
    error EventNotCancel();
    error EventNotOver();
    error InvalidAddress();
    error InvalidSupply();
    error InvalidTicketType();
    error NoFundsAvailable();
    error NotEventOwner();
    error NotMasterOrEventOwner();
    error NotMasterOwner();
    error NotTicketOwner();
    error PaymentFailed();
    error TicketSaleNotActive();
    error TicketSoldOut();
    error TicketTypeNotExists();
    error InvalidSupplyAndMinted();

    modifier onlyEventOwner() {
        if (msg.sender != eventOwner && !additionalEventOwners[msg.sender]) revert NotEventOwner();
        _;
    }

    modifier onlyMasterOwner() {
        if (!IMasterOwnerModifier(masterOwnerModifier).isMasterOwner(msg.sender)) revert NotMasterOwner();
        _;
    }

    modifier onlyVendorOrOwner() {
        if (msg.sender != eventOwner && !IMasterOwnerModifier(masterOwnerModifier).isMasterOwner(msg.sender)) revert NotMasterOrEventOwner(); 
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
        string memory _name,
        string memory _nftSymbol,
        uint256 _start,
        uint256 _end,
        uint256 _startSale,
        uint256 _endSale
    ) ERC721(_name, _nftSymbol) {
        eventOwner = _vendor;
        usdcToken = IERC20(_usdcToken);
        treasuryContract = _treasuryContract;
        masterOwnerModifier = _ownerModifierAddress;
        eventName = _name;
        eventStart = _start;
        eventEnd = _end;
        eventTiketStartSale = _startSale;
        eventTiketEndSale = _endSale;

    }

    function addTickets(string[] calldata _ticketTypes, uint256[] calldata _prices, uint256[] calldata _maxSupplies
    ) external onlyEventOwner {
        for (uint256 i = 0; i < _maxSupplies.length; i++) {
            if (keccak256(bytes(_ticketTypes[i])) == keccak256(bytes(""))) revert InvalidTicketType();
            if (_maxSupplies[i] == 0) revert InvalidSupply();
        }

        for (uint256 i = 0; i < _ticketTypes.length; i++) {
            tickets[_ticketTypes[i]] = Ticket({
                ticketType: _ticketTypes[i],
                price: _prices[i],
                maxSupply: _maxSupplies[i],
                minted: 0
            });
            ticketTypes.push(bytes32(bytes(_ticketTypes[i])));
        }
    }


    /**
     * @dev Function to mint a new ticket.
     * @param _ticketType The type of the ticket to be minted.
     */
    function mintTicket(string calldata _ticketType) external {
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
    function modifyTicketMaxSupply(string memory _ticketType, uint256 _newMaxSupply) external onlyEventOwner {
        if (_newMaxSupply == 0) revert InvalidSupply();
        Ticket storage ticket = tickets[_ticketType];
        if (ticket.maxSupply == 0) revert TicketTypeNotExists();
        if (_newMaxSupply < ticket.minted) revert InvalidSupplyAndMinted();

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

    // Define the totalSupply function if not already defined
    function _totalSupply() public view returns (uint256) {
        return totalSupply();
    }

    /**
     * @dev Function to cancel the event and refund all ticket holders.
     * @param reason The reason for cancelling the event.
     */
    function cancelEventAndAutoRefund(string calldata reason) external onlyVendorOrOwner {
        if (isCancelled) revert EventAlreadyCancelled();
        isCancelled = true;
        emit EventCancelled(reason);
        // Refund all ticket holders
        uint256 totalSupply = totalSupply();
        uint256 i = 0;
        while (i < totalSupply) {
            
            uint256 tokenId = tokenByIndex(i);
            address ticketOwner = ownerOf(tokenId);
            string memory ticketType = ticketTypesById[tokenId];
            uint256 refundAmount = tickets[ticketType].price;

            _burn(tokenId);
            require(usdcToken.transfer(ticketOwner, refundAmount), "Refund failed");
            emit TicketRefunded(ticketOwner, tokenId, refundAmount);

            // Update total supply after burning the token
            totalSupply = _totalSupply();
        }

        totalRevenue = 0;
    }

    
    function getTicketDetails(string memory ticketType) public view returns (uint256 price, uint256 supply) {
        return (tickets[ticketType].price, tickets[ticketType].maxSupply);
    }
}
