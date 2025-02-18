// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EventContract is ERC721Enumerable {
    address public eventOwner; // Vendor yang membuat event
    address public masterOwner; // Owner dari MasterContract
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
    string[] public ticketTypes;
    uint256 public totalRevenue;
    uint256 private _nextTokenId = 1;

    event TicketMinted(address indexed buyer, string ticketType, uint256 tokenId);
    event TicketUsed(uint256 tokenId);
    event FundsWithdrawn(address indexed vendor, uint256 vendorAmount, uint256 treasuryAmount);
    event EventCancelled(string reason);
    event TicketTransferred(address indexed from, address indexed to, uint256 tokenId);

    modifier onlyEventOwner() {
        require(msg.sender == eventOwner, "Not event owner");
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
        uint256 _start,
        uint256 _end,
        uint256 _startSale,
        uint256 _endSale,
        string[] memory _ticketTypes,
        uint256[] memory _prices,
        uint256[] memory _maxSupplies
    ) ERC721("EventNFT", "ETKT") {
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

    function mintTicket(string memory _ticketType) external {
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

    function useTicket(uint256 _tokenId) external {
        require(ownerOf(_tokenId) == msg.sender, "Not ticket owner");
        _burn(_tokenId);
        emit TicketUsed(_tokenId);
    }

    function transferTicket(address _to, uint256 _tokenId) external {
        require(ownerOf(_tokenId) == msg.sender, "Not ticket owner");
        _transfer(msg.sender, _to, _tokenId);
        emit TicketTransferred(msg.sender, _to, _tokenId);
    }

    function withdrawFunds() external onlyVendorOrOwner {
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
    }
}
