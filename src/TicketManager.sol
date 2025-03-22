// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

contract TicketManager is Ownable {
    IERC20 public usdcToken;

    struct Ticket {
        bytes32 ticketType;
        uint256 price;
        uint256 maxSupply;
        uint256 minted;
    }

    mapping(bytes32 => Ticket) public tickets;
    mapping(uint256 => bytes32) public ticketTypesById;
    uint256 private _nextTokenId = 1;

    event TicketMinted(address indexed buyer, bytes32 ticketType, uint256 tokenId);
    event TicketRefunded(address indexed buyer, uint256 tokenId, uint256 amount);
    event TicketUsed(uint256 tokenId);

    constructor(address _usdcToken) {
        usdcToken = IERC20(_usdcToken);
    }

    function addTickets(bytes32[] calldata _ticketTypes, uint256[] calldata _prices, uint256[] calldata _maxSupplies) external onlyOwner {
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

    function mintTicket(bytes32 _ticketType, address _buyer) external onlyOwner returns (uint256) {
        Ticket storage ticket = tickets[_ticketType];
        require(ticket.minted < ticket.maxSupply, "Ticket sold out");

        uint256 tokenId = _nextTokenId++;
        ticketTypesById[tokenId] = _ticketType;
        ticket.minted++;

        emit TicketMinted(_buyer, _ticketType, tokenId);
        return tokenId;
    }

    function refundTicket(uint256 _tokenId, address _buyer) external onlyOwner {
        bytes32 ticketType = ticketTypesById[_tokenId];
        uint256 refundAmount = tickets[ticketType].price;

        emit TicketRefunded(_buyer, _tokenId, refundAmount);
    }

    function useTicket(uint256 _tokenId) external onlyOwner {
        emit TicketUsed(_tokenId);
    }

    function modifyTicketMaxSupply(bytes32 _ticketType, uint256 _newMaxSupply) external onlyOwner {
        require(_newMaxSupply > 0, "Max supply must be greater than zero");
        Ticket storage ticket = tickets[_ticketType];
        require(ticket.maxSupply > 0, "Ticket type does not exist");
        require(_newMaxSupply >= ticket.minted, "New max supply cannot be less than minted tickets");

        ticket.maxSupply = _newMaxSupply;
    }
}
