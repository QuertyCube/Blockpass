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
        string[] memory _ticketTypes,
        uint256[] memory _prices,
        uint256[] memory _maxSupplies
    ) ERC721(_name, _nftSymbol) {
        require(_ticketTypes.length == _prices.length && _prices.length == _maxSupplies.length, "Invalid ticket data");

        eventOwner = _vendor;
        masterOwner = _masterOwner;
        usdcToken = IERC20(_usdcToken);
        treasuryContract = _treasuryContract;
        eventName = _name;
        eventStart = _start;
        eventEnd = _end;
        eventTiketStartSale = _startSale;
        eventTiketEndSale = _endSale;

        for (uint256 i = 0; i < _ticketTypes.length; i++) {
            tickets[_ticketTypes[i]] = Ticket(_prices[i], _maxSupplies[i], 0);
            ticketTypes.push(_ticketTypes[i]);
        }
    }

    function mintTicket(string memory _ticketType) external whenNotPaused {
        require(!isCancelled, "Event is cancelled");
        require(block.timestamp >= eventTiketStartSale && block.timestamp <= eventTiketEndSale, "Ticket sale not active");

        Ticket storage ticket = tickets[_ticketType];
        require(ticket.minted < ticket.maxSupply, "Sold out");

        uint256 price = ticket.price;
        require(usdcToken.transferFrom(msg.sender, address(this), price), "USDC payment failed");

        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);
        ticketTypesById[tokenId] = _ticketType;
        ticket.minted++;
        totalRevenue += price;

        emit TicketMinted(msg.sender, _ticketType, tokenId);
    }

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

    function useTicket(uint256 _tokenId) external whenNotPaused {
        require(ownerOf(_tokenId) == msg.sender, "Not ticket owner");
        _burn(_tokenId);
        emit TicketUsed(_tokenId);
    }

    function transferTicket(address _to, uint256 _tokenId) external whenNotPaused {
        require(ownerOf(_tokenId) == msg.sender, "Not ticket owner");
        _transfer(msg.sender, _to, _tokenId);
        emit TicketTransferred(msg.sender, _to, _tokenId);
    }

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

    function addEventOwner(address _newOwner) external onlyEventOwner {
        require(_newOwner != address(0), "Invalid address");
        additionalEventOwners[_newOwner] = true;
    }

    function removeEventOwner(address _owner) external onlyEventOwner {
        require(_owner != address(0), "Invalid address");
        additionalEventOwners[_owner] = false;
    }

    function pause() external onlyMasterOwner {
        _pause();
    }

    function unpause() external onlyMasterOwner {
        _unpause();
    }
}
