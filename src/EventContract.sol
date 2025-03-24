// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ITicketManager.sol";

interface IMasterOwnerModifier {
    function isMasterOwner(address user) external view returns (bool);
}

contract EventContract is ERC721Enumerable {
    address public eventOwner;
    address public treasuryContract;
    IERC20 public usdcToken;
    address public masterOwnerModifier;
    ITicketManager public ticketManager;

    string public eventName;
    bytes32[] public ticketTypes;

    uint256 public eventStart;
    uint256 public eventEnd;
    uint256 public eventTiketStartSale;
    uint256 public eventTiketEndSale;

    mapping(address => bool) public additionalEventOwners;

    event EventCancelled(string reason);

    error EventNotCancel();
    error InvalidAddress();
    error NotEventOwner();
    error NotMasterOwner();
    error NotMasterOrEventOwner();

    modifier onlyEventOwner() {
        if (msg.sender != eventOwner && !additionalEventOwners[msg.sender]) revert NotEventOwner();
        _;
    }

    modifier onlyMasterOwner() {
        if (!IMasterOwnerModifier(masterOwnerModifier).isMasterOwner(msg.sender)) revert NotMasterOwner();
        _;
    }

    modifier onlyVendorOrOwner() {
        if (msg.sender != eventOwner && !IMasterOwnerModifier(masterOwnerModifier).isMasterOwner(msg.sender)) revert NotEventOwner();
        _;
    }

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
        uint256 _endSale,
        address _ticketManager
    ) ERC721(string(abi.encodePacked(_name)), string(abi.encodePacked(_nftSymbol))) {
        eventOwner = _vendor;
        usdcToken = IERC20(_usdcToken);
        treasuryContract = _treasuryContract;
        masterOwnerModifier = _ownerModifierAddress;
        eventName = string(abi.encodePacked(_name));
        eventStart = _start;
        eventEnd = _end;
        eventTiketStartSale = _startSale;
        eventTiketEndSale = _endSale;
        ticketManager = ITicketManager(_ticketManager);
    }

    function addTickets(bytes32[] calldata _ticketTypes, uint256[] calldata _prices, uint256[] calldata _maxSupplies) external onlyEventOwner {
        ticketManager.addTickets(address(this), _ticketTypes, _prices, _maxSupplies);
    }

    function mintTicket(bytes32 _ticketType) external {
        ticketManager.mintTicket(address(this), _ticketType);
    }

    function getUserTickets(address _user) external view returns (uint256[] memory, bytes32[] memory) {
        return ticketManager.getUserTickets(_user);
    }

    function useTicket(uint256 _tokenId) external {
        ticketManager.useTicket(_tokenId);
    }

    function modifyTicketMaxSupply(bytes32 _ticketType, uint256 _newMaxSupply) external onlyEventOwner {
        ticketManager.modifyTicketMaxSupply(address(this), _ticketType, _newMaxSupply);
    }

    function withdrawFunds() external onlyVendorOrOwner {
        ticketManager.withdrawFunds(address(this));
    }

    function cancelEventAndAutoRefund(string calldata reason) external onlyVendorOrOwner {
        ticketManager.cancelEventAndAutoRefund(address(this), reason);
    }

    function getTicketDetails(bytes32 ticketType) external view returns (uint256 price, uint256 supply) {
        return ticketManager.getTicketDetails(ticketType);
    }
}
