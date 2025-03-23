// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ITicketManager.sol";

abstract contract TicketManager is ERC721Enumerable, ITicketManager {
    address public eventContract;
    IERC20 public usdcToken;

    uint256 private _nextTokenId = 1;
    bool public isCancelled = false;
    uint256 public totalRevenue;

    struct Ticket {
        bytes32 ticketType;
        uint256 price;
        uint256 maxSupply;
        uint256 minted;
    }

    mapping(bytes32 => Ticket) public tickets;
    mapping(uint256 => bytes32) public ticketTypesById;

    event TicketMinted(address indexed buyer, bytes32 ticketType, uint256 tokenId);
    event TicketUsed(uint256 tokenId);
    event TicketRefunded(address indexed buyer, uint256 tokenId, uint256 amount);
    
    modifier onlyEventContract() {
        require(msg.sender == eventContract, "Only EventContract can call this function");
        _;
    }

    constructor(address _eventContract, address _usdcToken, string memory _name, string memory _symbol) 
        ERC721(_name, _symbol) 
    {
        eventContract = _eventContract;
        usdcToken = IERC20(_usdcToken);
    }

    function addTickets(bytes32[] calldata _ticketTypes, uint256[] calldata _prices, uint256[] calldata _maxSupplies) 
        external 
        onlyEventContract 
    {
        require(_ticketTypes.length == _prices.length && _ticketTypes.length == _maxSupplies.length, "Invalid ticket data");

        for (uint256 i = 0; i < _ticketTypes.length; i++) {
            tickets[_ticketTypes[i]] = Ticket({
                ticketType: _ticketTypes[i],
                price: _prices[i],
                maxSupply: _maxSupplies[i],
                minted: 0
            });
        }
    }

    function mintTicket(bytes32 _ticketType, address _buyer) external onlyEventContract {
        require(!isCancelled, "Event cancelled");
        
        Ticket storage ticket = tickets[_ticketType];
        require(ticket.minted < ticket.maxSupply, "Ticket Sold Out");
        require(usdcToken.transferFrom(_buyer, address(this), ticket.price), "Payment Failed");

        uint256 tokenId = _nextTokenId++;
        _safeMint(_buyer, tokenId);
        ticketTypesById[tokenId] = _ticketType;
        ticket.minted++;
        totalRevenue += ticket.price;

        emit TicketMinted(_buyer, _ticketType, tokenId);
    }

    function useTicket(uint256 _tokenId, address _user) external onlyEventContract {
        require(ownerOf(_tokenId) == _user, "Not Ticket Owner");
        _burn(_tokenId);
        emit TicketUsed(_tokenId);
    }

    function refundAllTickets() external onlyEventContract {
        isCancelled = true;
        uint256 totalSupply = totalSupply();
        for (uint256 i = 0; i < totalSupply; i++) {
            uint256 tokenId = tokenByIndex(i);
            address ticketOwner = ownerOf(tokenId);
            bytes32 ticketType = ticketTypesById[tokenId];
            uint256 refundAmount = tickets[ticketType].price;

            _burn(tokenId);
            require(usdcToken.transfer(ticketOwner, refundAmount), "Payment Failed");
            emit TicketRefunded(ticketOwner, tokenId, refundAmount);
        }
        totalRevenue = 0;
    }

    function modifyTicketMaxSupply(bytes32 _ticketType, uint256 _newMaxSupply) external onlyEventContract {
        require(_newMaxSupply > 0, "Max supply must be greater than zero");
        Ticket storage ticket = tickets[_ticketType];
        require(ticket.maxSupply > 0, "Ticket type does not exist");
        require(_newMaxSupply >= ticket.minted, "New max supply cannot be less than minted tickets");

        ticket.maxSupply = _newMaxSupply;
    }

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

    function getTicketDetails(bytes32 _ticketType) public view returns (uint256 price, uint256 supply) {
        return (tickets[_ticketType].price, tickets[_ticketType].maxSupply);
    }
}
