// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/Master.sol";
import "../src/EventContract.sol";
import "../src/MasterOwnerModifier.sol";
import "../src/MockERC20.sol";
import "../src/TreasuryFund.sol";

contract MasterContractTest is Test {
    MasterContract public masterContract;
    MasterOwnerModifier public ownerModifier;
    MockERC20 public usdc;
    TreasuryFund public treasury;
    
    address public owner = address(0x1);
    address public owner2 = address(0x1);
    address public vendor = address(0x2);
    address public nonOwner = address(0x3);

    function setUp() public {
        // Deploy Owner Modifier contract
        vm.startPrank(owner);
        ownerModifier = new MasterOwnerModifier();
        
        // Deploy USDC mock token
        usdc = new MockERC20("Mock USDC", "USDC", 18);

        // Deploy Treasury contract
        treasury = new TreasuryFund();

        // Deploy MasterContract
        masterContract = new MasterContract(address(treasury),address(usdc), address(ownerModifier));

        // // Add owner to Owner Modifier contract
        // ownerModifier.addMasterOwner(owner);
        vm.stopPrank();
    }

    function test_CreateEvent_Success() public {
        // Create event
        vm.prank(owner);
        address eventAddress = masterContract.createEvent(
            "Blockchain Expo",
            "BEX",
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            block.timestamp,
            block.timestamp + 1 days
        );

        // Interact with the event contract
        EventContract eventInstance = EventContract(eventAddress);

        // Convert "VIP" string to bytes32 and wrap in an array
        string[] memory ticketCategories = new string[](1); 
        uint256[] memory ticketPrices = new uint256[](1);
        uint256[] memory ticketSupplies = new uint256[](1);

        ticketCategories[0] = "VIP";
        ticketPrices[0] = 100 ether;  // Harga tiket dalam wei
        ticketSupplies[0] = 100;      // Jumlah tiket

        // Add tickets
        vm.prank(owner);
        eventInstance.addTickets(ticketCategories, ticketPrices, ticketSupplies);

        // Validate that tickets were added (modify getTicketDetails if needed)
        (string[] memory tiketType, uint256[] memory ticketPrice, uint256[] memory ticketSupply) = eventInstance.getTicketDetails();
        assertEq(tiketType[0], "VIP");
        assertEq(ticketPrice[0], 100 ether);
        assertEq(ticketSupply[0], 100);
    }

    function test_CreateEvent_Fail_InvalidTiming() public {
        vm.prank(owner);
        vm.expectRevert(MasterContract.InvalidEventTiming.selector);
        masterContract.createEvent(
        "Invalid Event",
        "INV",
        block.timestamp + 2 days, // Start lebih lambat dari endDate (invalid)
        block.timestamp + 1 days, // End lebih cepat (invalid case)
        block.timestamp,
        block.timestamp + 1 days
        );
    }

    function test_CreateEvent_Fail_InvalidSaleTiming() public {
        vm.prank(owner);
        vm.expectRevert(MasterContract.InvalidSaleTiming.selector);
        masterContract.createEvent(
        "Invalid Sale Timing Event",
        "IST",
        block.timestamp + 1 days, // startDate
        block.timestamp + 2 days, // endDate
        block.timestamp + 2 days, // saleStart setelah saleEnd (invalid)
        block.timestamp + 1 days  // saleEnd sebelum saleStart (invalid)
    );
    }

    function test_CreateEvent_Fail_NoTickets() public {
        // Coba buat event tanpa menambahkan tiket (jika kontrak mengharuskan setidaknya 1 tiket)
        vm.prank(owner);
        address eventAddress = masterContract.createEvent(
            "Event Without Tickets",
            "EWT",
            block.timestamp + 1 days, // startDate
            block.timestamp + 2 days, // endDate
            block.timestamp,          // saleStart
            block.timestamp + 1 days  // saleEnd
        );

        // Dapatkan instance event yang baru dibuat
        EventContract eventInstance = EventContract(eventAddress);

        // Pastikan bahwa pemanggilan addTickets() gagal jika tidak ada 
        string[] memory ticketCategories = new string[](1); 
        uint256[] memory ticketPrices = new uint256[](1);
        uint256[] memory ticketSupplies = new uint256[](1);

        vm.prank(owner);
        vm.expectRevert(EventContract.InvalidTicketType.selector);
        eventInstance.addTickets(ticketCategories , ticketPrices, ticketSupplies);
    }

    function test_Withdraw_Success() public {
        vm.deal(address(masterContract), 10 ether); // Send 10 ETH to contract

        uint256 initialBalance = address(treasury).balance;

        vm.prank(owner);
        masterContract.withdraw(5 ether);

        assertEq(address(treasury).balance, initialBalance + 5 ether);
    }

    function test_Withdraw_Fail_InsufficientBalance() public {
        vm.prank(owner);
        vm.expectRevert(MasterContract.InsufficientBalance.selector);
        masterContract.withdraw(1 ether);
    }

    function test_Withdraw_Fail_NotOwner() public {
        vm.deal(address(masterContract), 10 ether); // Send 10 ETH to contract

        vm.prank(nonOwner);
        vm.expectRevert(MasterContract.NotOwner.selector);
        masterContract.withdraw(5 ether);
    }
}