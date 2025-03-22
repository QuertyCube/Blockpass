// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./MasterOwnerModifier.sol";
import "./EventLibrary.sol";

contract EventContract is ERC721Enumerable, Pausable {
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
    event TicketTransferred(address indexed from, address indexed to, uint256 tokenId);
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
     * @param _ticketInfos Array of Ticket structs containing ticket details.
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
        uint256 _endSale,
        EventLibrary.TicketInfo[] memory _ticketInfos
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

        for (uint256 i = 0; i < _ticketInfos.length; i++) {
            tickets[_ticketInfos[i].ticketType] = Ticket({
                ticketType: _ticketInfos[i].ticketType,
                price: _ticketInfos[i].price,
                maxSupply: _ticketInfos[i].maxSupply,
                minted: 0
            });
            ticketTypes.push(_ticketInfos[i].ticketType);
        }
    }

    /**
     * @dev Function to mint a new ticket.
     * @param _ticketType The type of the ticket to be minted.
     */
    function mintTicket(bytes32 _ticketType) external whenNotPaused {
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
    function useTicket(uint256 _tokenId) external whenNotPaused {
        if (ownerOf(_tokenId) != msg.sender) revert NotTicketOwner();
        _burn(_tokenId);
        emit TicketUsed(_tokenId);
    }

    /**
     * @dev Function to transfer a ticket to another user.
     * @param _to The address of the recipient.
     * @param _tokenId The ID of the ticket to be transferred.
     */
    function transferTicket(address _to, uint256 _tokenId) external whenNotPaused {
        if (ownerOf(_tokenId) != msg.sender) revert NotTicketOwner();
        if (block.timestamp >= eventStart - 24 hours) revert("Ticket transfers are not allowed 24 hours before the event");

        _transfer(msg.sender, _to, _tokenId);
        emit TicketTransferred(msg.sender, _to, _tokenId);
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

    // Define the totalSupply function if not already defined
    function _totalSupply() public view returns (uint256) {
        return totalSupply();
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
        uint256 i = 0;
        while (i < totalSupply) {
            
            uint256 tokenId = tokenByIndex(i);
            address ticketOwner = ownerOf(tokenId);
            bytes32 ticketType = ticketTypesById[tokenId];
            uint256 refundAmount = tickets[ticketType].price;

            _burn(tokenId);
            if (!usdcToken.transfer(ticketOwner, refundAmount)) revert PaymentFailed();
            emit TicketRefunded(ticketOwner, tokenId, refundAmount);

            // Update total supply after burning the token
            totalSupply = _totalSupply();
        }

        totalRevenue = 0;
    }

    function cancelEventOnly(string calldata reason) external onlyVendorOrOwner {
        if (isCancelled) revert EventNotCancel();
        isCancelled = true;
        emit EventCancelled(reason);

    }

    /**
     * @dev Function to claim a refund for a specific ticket.
     * @param _tokenId The ID of the ticket to be refunded.
     */
    function claimRefund(uint256 _tokenId) public {
        if (!isCancelled) revert EventNotCancel();
        if (ownerOf(_tokenId) != msg.sender) revert NotTicketOwner();

        bytes32 ticketType = ticketTypesById[_tokenId];
        uint256 refundAmount = tickets[ticketType].price;

        // Burn the token
        _burn(_tokenId);

        // Attempt to transfer the refund amount before burning the token
        if (!usdcToken.transfer(msg.sender, refundAmount)) revert PaymentFailed();

        emit TicketRefunded(msg.sender, _tokenId, refundAmount);
    }

    /**
     * @dev Function to add a new event owner.
     * @param _newOwner The address of the new event owner.
     */
    function addEventOwner(address _newOwner) external onlyEventOwner {
        if (_newOwner == address(0)) revert InvalidAddress();
        additionalEventOwners[_newOwner] = true;
    }

    /**
     * @dev Function to remove an event owner.
     * @param _owner The address of the event owner to be removed.
     */
    function removeEventOwner(address _owner) external onlyEventOwner {
        if (_owner == address(0)) revert InvalidAddress();
        additionalEventOwners[_owner] = false;
    }

    /**
     * @dev Function to pause the contract.
     */
    function pause() external onlyMasterOwner {
        _pause();
    }

    /**
     * @dev Function to unpause the contract.
     */
    function unpause() external onlyMasterOwner {
        _unpause();
    }
}

/**
Berikut adalah daftar fungsi dalam kontrak EventContract beserta penjelasan singkat mengenai fungsinya:

Daftar Fungsi:
constructor
    Menginisialisasi kontrak dengan parameter yang diberikan, seperti vendor, master owner, token USDC, kontrak treasury, nama event, simbol NFT, waktu mulai dan berakhirnya event, serta detail tiket.

mintTicket
    Memungkinkan pengguna untuk mencetak tiket baru jika event tidak dibatalkan dan penjualan tiket sedang aktif. Fungsi ini juga memeriksa apakah tiket masih tersedia dan pembayaran USDC berhasil.

getUserTickets
    Mengembalikan daftar ID tiket dan jenis tiket yang dimiliki oleh pengguna tertentu.

useTicket
    Memungkinkan pengguna untuk menggunakan tiket yang mereka miliki. Tiket akan dibakar setelah digunakan.

transferTicket
    Memungkinkan pengguna untuk mentransfer tiket mereka ke pengguna lain.

modifyTicketMaxSupply
    Memodifikasi jumlah maksimum tiket yang dapat dicetak untuk jenis tiket tertentu. Hanya pemilik event yang dapat memanggil fungsi ini.

withdrawFunds
    Memungkinkan vendor atau pemilik untuk menarik dana setelah event berakhir. Fungsi ini juga membagi dana antara vendor dan treasury.

cancelEvent
    Membatalkan event dan mengembalikan dana kepada semua pemegang tiket. Hanya vendor atau pemilik yang dapat memanggil fungsi ini.

claimRefund
    Memungkinkan pemegang tiket untuk mengklaim pengembalian dana jika event dibatalkan.

addEventOwner
    Menambahkan pemilik event baru. Hanya pemilik event yang dapat memanggil fungsi ini.

removeEventOwner
    Menghapus pemilik event. Hanya pemilik event yang dapat memanggil fungsi ini.

pause
Menjeda kontrak. Hanya master owner yang dapat memanggil fungsi ini.

unpause
    Melanjutkan kontrak yang dijeda. Hanya master owner yang dapat memanggil fungsi ini.



Alur Kontrak
Inisialisasi Kontrak
    Kontrak diinisialisasi dengan parameter yang diberikan melalui konstruktor. Ini termasuk detail event, waktu mulai dan berakhirnya event, serta detail tiket.

Penjualan Tiket
    Pengguna dapat mencetak tiket baru selama penjualan tiket aktif dan event tidak dibatalkan. Pembayaran dilakukan menggunakan token USDC.

Penggunaan dan Transfer Tiket
    Pengguna dapat menggunakan tiket mereka untuk menghadiri event atau mentransfer tiket ke pengguna lain.

Modifikasi dan Penarikan Dana
    Pemilik event dapat memodifikasi jumlah maksimum tiket yang dapat dicetak. Setelah event berakhir, vendor atau pemilik dapat menarik dana yang terkumpul.

Pembatalan Event dan Pengembalian Dana
    Jika event dibatalkan, semua pemegang tiket akan mendapatkan pengembalian dana. Pemegang tiket juga dapat mengklaim pengembalian dana secara individual.

Manajemen Pemilik Event
    Pemilik event dapat menambahkan atau menghapus pemilik event lainnya.

Pengelolaan Kontrak
    Master owner dapat menjeda atau melanjutkan kontrak sesuai kebutuhan.


Dengan alur ini, kontrak EventContract memungkinkan pengelolaan event yang terdesentralisasi, termasuk penjualan tiket, penggunaan tiket, transfer tiket, dan manajemen dana.
 */