// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./ITicketManager.sol";

contract EventContract is ERC721Enumerable, Ownable {
    address public immutable usdcToken;
    address public immutable treasury;
    address public immutable masterOwnerModifier;
    
    string public eventName;
    bytes32 public nftSymbol;
    uint256 public eventStart;
    uint256 public eventEnd;
    uint256 public ticketStartSale;
    uint256 public ticketEndSale;
    bool public isCancelled = false;

    ITicketManager public ticketManager;

    event EventCancelled(string reason);
    event TicketUsed(uint256 indexed tokenId);

    error EventNotCancelled();
    error TicketSaleNotActive();
    error NotTicketOwner();
    error EventNotOver();

    constructor(
        address _owner,
        address _usdcToken,
        address _treasury,
        address _masterOwnerModifier,
        ITicketManager _ticketManager,
        string memory _eventName,
        bytes32 _nftSymbol,
        uint256 _start,
        uint256 _end,
        uint256 _startSale,
        uint256 _endSale
    ) ERC721(_eventName, string(abi.encodePacked(_nftSymbol))) Ownable(_owner) {
        usdcToken = _usdcToken;
        treasury = _treasury;
        masterOwnerModifier = _masterOwnerModifier;
        ticketManager = _ticketManager;
        eventName = _eventName;
        nftSymbol = _nftSymbol;
        eventStart = _start;
        eventEnd = _end;
        ticketStartSale = _startSale;
        ticketEndSale = _endSale;
    }

    modifier onlyDuringSale() {
        if (block.timestamp < ticketStartSale || block.timestamp > ticketEndSale) revert TicketSaleNotActive();
        _;
    }

    modifier onlyTicketOwner(uint256 _tokenId) {
        if (ownerOf(_tokenId) != msg.sender) revert NotTicketOwner();
        _;
    }

    function mintTicket(bytes32 _ticketType) external onlyDuringSale {
        ticketManager.mintTicket(msg.sender, _ticketType);
    }

    function getUserTickets(address _user) external view returns (uint256[] memory, bytes32[] memory) {
        return ticketManager.getUserTickets(_user);
    }

    function useTicket(uint256 _tokenId) external onlyTicketOwner(_tokenId) {
        _burn(_tokenId);
        emit TicketUsed(_tokenId);
    }

    function cancelEvent(string calldata reason) external onlyOwner {
        isCancelled = true;
        ticketManager.refundAll();
        emit EventCancelled(reason);
    }
}
