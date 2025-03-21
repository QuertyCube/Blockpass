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
        // Define event parameters
        MasterContract.TicketInfo[] memory tickets = new MasterContract.TicketInfo[](1);
        tickets[0] = MasterContract.TicketInfo("VIP", 100 ether, 100);

        MasterContract.EventParams memory params = MasterContract.EventParams({
            name: "Blockchain Expo",
            nftSymbol: "BEX",
            start: block.timestamp + 1 days,
            end: block.timestamp + 2 days,
            startSale: block.timestamp,
            endSale: block.timestamp + 1 days,
            ticketInfos: tickets
        });

        // Create event
        vm.prank(owner);
        address eventAddress = masterContract.createEvent(params);

        // Validate event contract was created
        address[] memory events = masterContract.getAllEvents();
        assertEq(events.length, 1);
        assertEq(events[0], eventAddress);
    }

    function test_CreateEvent_Fail_InvalidTiming() public {
        MasterContract.TicketInfo[] memory tickets = new MasterContract.TicketInfo[](1);
        tickets[0] = MasterContract.TicketInfo("VIP", 100 ether, 100);

        MasterContract.EventParams memory invalidParams = MasterContract.EventParams({
            name: "Invalid Timing Event",
            nftSymbol: "ITE",
            start: block.timestamp + 2 days,
            end: block.timestamp + 1 days, // Error: start > end
            startSale: block.timestamp,
            endSale: block.timestamp + 1 days,
            ticketInfos: tickets
        });

        vm.prank(owner);
        vm.expectRevert("Invalid event timing");
        masterContract.createEvent(invalidParams);
    }

    function test_CreateEvent_Fail_InvalidSaleTiming() public {
        MasterContract.TicketInfo[] memory tickets = new MasterContract.TicketInfo[](1);
        tickets[0] = MasterContract.TicketInfo("VIP", 100 ether, 100);

        MasterContract.EventParams memory invalidParams = MasterContract.EventParams({
            name: "Invalid Sale Timing",
            nftSymbol: "IST",
            start: block.timestamp + 1 days,
            end: block.timestamp + 2 days,
            startSale: block.timestamp + 2 days, // Error: startSale > endSale
            endSale: block.timestamp + 1 days,
            ticketInfos: tickets
        });

        vm.prank(owner);
        vm.expectRevert("Invalid sale timing");
        masterContract.createEvent(invalidParams);
    }

    function test_CreateEvent_Fail_NoTickets() public {
        MasterContract.TicketInfo[] memory tickets = new MasterContract.TicketInfo[](0);

        MasterContract.EventParams memory invalidParams = MasterContract.EventParams({
            name: "No Tickets Event",
            nftSymbol: "NTE",
            start: block.timestamp + 1 days,
            end: block.timestamp + 2 days,
            startSale: block.timestamp,
            endSale: block.timestamp + 1 days,
            ticketInfos: tickets // Error: No ticket types
        });

        vm.prank(owner);
        vm.expectRevert("Invalid ticket data");
        masterContract.createEvent(invalidParams);
    }

    function test_AddOwner_Success() public {
        vm.prank(owner);
        masterContract.addOwner(nonOwner);

        assertTrue(ownerModifier.isMasterOwner(nonOwner));
    }

    function test_AddOwner_Fail_NotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert("Caller is not an owner");
        masterContract.addOwner(nonOwner);
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
        vm.expectRevert("Insufficient balance");
        masterContract.withdraw(1 ether);
    }

    function test_Withdraw_Fail_NotOwner() public {
        vm.deal(address(masterContract), 10 ether); // Send 10 ETH to contract

        vm.prank(nonOwner);
        vm.expectRevert("Caller is not an owner");
        masterContract.withdraw(5 ether);
    }
}




/**
setUp() → Menyiapkan kontrak dengan MasterOwnerModifier dan MockERC20 (USDC dummy).
test_CreateEvent_Success() → Memastikan event berhasil dibuat jika semua parameter valid.
Tes gagal (expectRevert):
test_CreateEvent_Fail_InvalidTiming() → Start lebih besar dari End.
test_CreateEvent_Fail_InvalidSaleTiming() → Start sale lebih besar dari End sale.
test_CreateEvent_Fail_NoTickets() → Tidak ada tiket yang tersedia.
test_AddOwner_Success() → Owner dapat menambahkan master owner baru.
test_AddOwner_Fail_NotOwner() → Non-owner tidak bisa menambahkan master owner.
test_Withdraw_Success() → Berhasil menarik dana ke treasury.
test_Withdraw_Fail_InsufficientBalance() → Gagal menarik lebih dari saldo yang tersedia.
test_Withdraw_Fail_NotOwner() → Non-owner tidak bisa menarik dana.
 */