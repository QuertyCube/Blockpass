// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./MasterOwnerModifier.sol";

contract EventContract is ERC721Enumerable, Pausable {
    address public eventOwner;
    address public masterOwner;
    address public treasuryContract;
    IERC20 public usdcToken;
    MasterOwnerModifier public masterOwnerModifier;

    string public eventName;
    string[] public ticketTypes;

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

    modifier onlyEventOwner() {
        require(msg.sender == eventOwner || additionalEventOwners[msg.sender], "Not event owner");
        _;
    }

    modifier onlyMasterOwner() {
        require(masterOwnerModifier.isMasterOwner(msg.sender), "Caller is not an owner");
        _;
    }

    modifier onlyVendorOrOwner() {
        require(msg.sender == eventOwner || masterOwnerModifier.isMasterOwner(msg.sender), "Not vendor or owner");
        _;
    }

    /**
     * @dev Constructor to initialize the contract.
     * @param _vendor Address of the event vendor.
     * @param _masterOwner Address of the master owner.
     * @param _usdcToken Address of the USDC token contract.
     * @param _treasuryContract Address of the treasury contract.
     * @param _name Name of the event.
     * @param _nftSymbol Symbol of the NFT.
     * @param _start Start timestamp of the event.
     * @param _end End timestamp of the event.
     * @param _startSale Start timestamp of the ticket sale.
     * @param _endSale End timestamp of the ticket sale.
     * @param _tickets Array of Ticket structs containing ticket details.
     */
    constructor(
        address _vendor,
        address _masterOwner,
        address _usdcToken,
        address _treasuryContract,
        address _ownerModifierAddress,
        string memory _name,
        string memory _nftSymbol,
        uint256 _start,
        uint256 _end,
        uint256 _startSale,
        uint256 _endSale,
        Ticket[] memory _tickets
    ) ERC721(_name, _nftSymbol) {
        eventOwner = _vendor;
        masterOwner = _masterOwner;
        usdcToken = IERC20(_usdcToken);
        treasuryContract = _treasuryContract;
        masterOwnerModifier = MasterOwnerModifier(_ownerModifierAddress);
        eventName = _name;
        eventStart = _start;
        eventEnd = _end;
        eventTiketStartSale = _startSale;
        eventTiketEndSale = _endSale;

        for (uint256 i = 0; i < _tickets.length; i++) {
            tickets[_tickets[i].ticketType] = _tickets[i];
            ticketTypes.push(_tickets[i].ticketType);
        }
    }

    /**
     * @dev Function to mint a new ticket.
     * @param _ticketType The type of the ticket to be minted.
     */
    function mintTicket(string calldata _ticketType) external whenNotPaused {
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
    function modifyTicketMaxSupply(string calldata _ticketType, uint256 _newMaxSupply) external onlyEventOwner {
        require(_newMaxSupply > 0, "Max supply must be greater than zero");
        Ticket storage ticket = tickets[_ticketType];
        require(ticket.maxSupply > 0, "Ticket type does not exist");
        require(_newMaxSupply >= ticket.minted, "New max supply cannot be less than minted tickets");

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

        require(usdcToken.transfer(eventOwner, vendorAmount), "Vendor withdrawal failed");
        require(usdcToken.transfer(treasuryContract, treasuryAmount), "Treasury transfer failed");

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
        require(!isCancelled, "Event already cancelled");
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

    function cancelEventOnly(string calldata reason) external onlyVendorOrOwner {
        require(!isCancelled, "Event already cancelled");
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

        string memory ticketType = ticketTypesById[_tokenId];
        uint256 refundAmount = tickets[ticketType].price;

        // Attempt to transfer the refund amount before burning the token
        bool refundSuccess = usdcToken.transfer(msg.sender, refundAmount);
        require(refundSuccess, "Refund failed");

        // Burn the token only if the refund was successful
        _burn(_tokenId);
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