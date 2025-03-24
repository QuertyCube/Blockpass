// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IEventContract {
    function eventOwner() external view returns (address);
    function additionalEventOwners(address user) external view returns (bool);
    function eventTiketStartSale() external view returns (uint256);
    function eventTiketEndSale() external view returns (uint256);
    function eventEnd() external view returns (uint256);
}

interface IMasterOwnerModifier {
    function isMasterOwner(address user) external view returns (bool);
}

contract TicketManager is ERC721Enumerable {
    IERC20 public usdcToken;
    address public treasuryContract;
    address public masterOwnerModifier;

    uint256 private _nextTokenId = 1;
    uint256 public totalRevenue;
    bool public isCancelled = false;

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
    event FundsWithdrawn(address indexed vendor, uint256 vendorAmount, uint256 treasuryAmount);
    event EventCancelled(string reason);

    error EventNotCancel();
    error TicketSoldOut();
    error TicketSaleNotActive();
    error PaymentFailed();
    error NotTicketOwner();
    error EventNotOver();
    error NoFundsAvailable();
    error InvalidAddress();
    error NotEventOwner();

    modifier onlyEventOwner(address eventContract) {
        if (msg.sender != IEventContract(eventContract).eventOwner() && !IEventContract(eventContract).additionalEventOwners(msg.sender)) revert NotEventOwner();
        _;
    }

    modifier onlyVendorOrOwner(address eventContract) {
        if (msg.sender != IEventContract(eventContract).eventOwner() && !IMasterOwnerModifier(masterOwnerModifier).isMasterOwner(msg.sender)) revert NotEventOwner();
        _;
    }

    constructor(address _usdcToken, address _treasuryContract, address _masterOwnerModifier) ERC721("TicketManager", "TICKET") {
        usdcToken = IERC20(_usdcToken);
        treasuryContract = _treasuryContract;
        masterOwnerModifier = _masterOwnerModifier;
    }

    function addTickets(address eventContract, bytes32[] calldata _ticketTypes, uint256[] calldata _prices, uint256[] calldata _maxSupplies) external onlyEventOwner(eventContract) {
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

    function mintTicket(address eventContract, bytes32 _ticketType) external {
        if (isCancelled) revert EventNotCancel();
        if (block.timestamp < IEventContract(eventContract).eventTiketStartSale() || block.timestamp > IEventContract(eventContract).eventTiketEndSale()) revert TicketSaleNotActive();

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

    function useTicket(uint256 _tokenId) external {
        if (ownerOf(_tokenId) != msg.sender) revert NotTicketOwner();
        _burn(_tokenId);
        emit TicketUsed(_tokenId);
    }

    function modifyTicketMaxSupply(address eventContract, bytes32 _ticketType, uint256 _newMaxSupply) external onlyEventOwner(eventContract) {
        if (_newMaxSupply == 0) revert("Max supply must be greater than zero");
        Ticket storage ticket = tickets[_ticketType];
        if (ticket.maxSupply == 0) revert("Ticket type does not exist");
        if (_newMaxSupply < ticket.minted) revert("New max supply cannot be less than minted tickets");

        ticket.maxSupply = _newMaxSupply;
    }

    function withdrawFunds(address eventContract) external onlyVendorOrOwner(eventContract) {
        if (block.timestamp <= IEventContract(eventContract).eventEnd()) revert EventNotOver();
        if (isCancelled) revert EventNotCancel();
        if (totalRevenue == 0) revert NoFundsAvailable();

        uint256 treasuryAmount = totalRevenue / 100; // 1% for treasury
        uint256 vendorAmount = totalRevenue - treasuryAmount;

        if (!usdcToken.transfer(IEventContract(eventContract).eventOwner(), vendorAmount)) revert PaymentFailed();
        if (!usdcToken.transfer(treasuryContract, treasuryAmount)) revert PaymentFailed();

        emit FundsWithdrawn(IEventContract(eventContract).eventOwner(), vendorAmount, treasuryAmount);
        totalRevenue = 0;
    }

    function cancelEventAndAutoRefund(address eventContract, string calldata reason) external onlyVendorOrOwner(eventContract) {
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
