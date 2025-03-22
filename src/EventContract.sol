// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./MasterOwnerModifier.sol";
import "./TicketManager.sol";

contract EventContract is ERC721Enumerable, Pausable {
    address public eventOwner;
    address public treasuryContract;
    IERC20 public usdcToken;
    MasterOwnerModifier public masterOwnerModifier;
    TicketManager public ticketManager;

    string public eventName;

    uint256 public eventStart;
    uint256 public eventEnd;
    uint256 public eventTiketStartSale;
    uint256 public eventTiketEndSale;
    uint256 public totalRevenue;

    bool public isCancelled = false;

    mapping(address => bool) public additionalEventOwners;

    event EventCancelled(string reason);
    event FundsWithdrawn(address indexed vendor, uint256 vendorAmount, uint256 treasuryAmount);

    error EventNotCancel();
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

    constructor(
        address _vendor,
        address _usdcToken,
        address _treasuryContract,
        address _ownerModifierAddress,
        address _ticketManager,
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
        ticketManager = TicketManager(_ticketManager);
        eventName = string(abi.encodePacked(_name));
        eventStart = _start;
        eventEnd = _end;
        eventTiketStartSale = _startSale;
        eventTiketEndSale = _endSale;
    }

    function addTickets(bytes32[] calldata _ticketTypes, uint256[] calldata _prices, uint256[] calldata _maxSupplies) external onlyEventOwner {
        ticketManager.addTickets(_ticketTypes, _prices, _maxSupplies);
    }

    function mintTicket(bytes32 _ticketType) external whenNotPaused {
        if (isCancelled) revert EventNotCancel();
        if (block.timestamp < eventTiketStartSale || block.timestamp > eventTiketEndSale) revert TicketSaleNotActive();

        uint256 price = ticketManager.tickets(_ticketType).price;
        if (!usdcToken.transferFrom(msg.sender, address(this), price)) revert PaymentFailed();

        uint256 tokenId = ticketManager.mintTicket(_ticketType, msg.sender);
        _safeMint(msg.sender, tokenId);
        totalRevenue += price;
    }

    function useTicket(uint256 _tokenId) external whenNotPaused {
        if (ownerOf(_tokenId) != msg.sender) revert NotTicketOwner();
        _burn(_tokenId);
        ticketManager.useTicket(_tokenId);
    }

    function modifyTicketMaxSupply(bytes32 _ticketType, uint256 _newMaxSupply) external onlyEventOwner {
        ticketManager.modifyTicketMaxSupply(_ticketType, _newMaxSupply);
    }

    function withdrawFunds() external onlyVendorOrOwner whenNotPaused {
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

    function cancelEventAndAutoRefund(string calldata reason) external onlyVendorOrOwner {
        if (isCancelled) revert EventNotCancel();
        isCancelled = true;
        emit EventCancelled(reason);

        uint256 totalSupply = totalSupply();
        for (uint256 i = 0; i < totalSupply; i++) {
            uint256 tokenId = tokenByIndex(i);
            address ticketOwner = ownerOf(tokenId);
            ticketManager.refundTicket(tokenId, ticketOwner);
            _burn(tokenId);
        }
        totalRevenue = 0;
    }

    function pause() external onlyMasterOwner {
        _pause();
    }

    function unpause() external onlyMasterOwner {
        _unpause();
    }
}
