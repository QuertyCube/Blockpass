// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.23;

// import "forge-std/Test.sol";
// import "../src/EventContract.sol";
// import "forge-std/console.sol";
// import "../src/MockERC20.sol";
// import "../src/MasterOwnerModifier.sol";

// contract EventContractTest is Test {
//     EventContract eventContract;
//     MockERC20 usdcToken;
//     MasterOwnerModifier masterOwnerModifier;
//     address vendor = address(0x1);
//     address masterOwner = address(0x2);
//     address treasury = address(0x3);
//     address user = address(0x4);

//     function setUp() public {
//         // Initialize mock USDC token and master owner modifier
//         usdcToken = new MockERC20("Mock USDC", "USDC", 6);
//         masterOwnerModifier = new MasterOwnerModifier();
//         masterOwnerModifier.addMasterOwner(masterOwner);

//         // Initialize tickets
//         EventContract.Ticket[] memory tickets = new EventContract.Ticket[](2);
//         tickets[0] = EventContract.Ticket({
//             ticketType: "VIP",
//             price: 100 * 10**6, // 100 USDC
//             maxSupply: 1000,
//             minted: 0
//         });

//         tickets[1] = EventContract.Ticket({
//             ticketType: "REG",
//             price: 100 * 10**6, // 100 USDC
//             maxSupply: 3000,
//             minted: 0
//         });

//         // Deploy EventContract
//         eventContract = new EventContract(
//             vendor,
//             address(usdcToken),
//             treasury,
//             address(masterOwnerModifier),
//             "Test Event",
//             "TEVT",
//             block.timestamp + 2 days,           // Start timestamp of the event.
//             block.timestamp + 3 days,           // End timestamp of the event.
//             block.timestamp,                    // Sale Start timestamp of the ticket sale.
//             block.timestamp + 1 days,           // Sale End timestamp of the ticket sale.
//             tickets
//         );

//         // Mint 10000000 USDC to user
//         usdcToken.mint(user, 100000000000 * 10**6);
//     }

//     function testMintTicketHappyFlow() public {
//         // User approves and mints a VIP ticket
//         vm.startPrank(user);
//         usdcToken.approve(address(eventContract), 100 * 10**6);
//         eventContract.mintTicket("VIP");
//         assertEq(eventContract.balanceOf(user), 1);
//         vm.stopPrank();
//     }

//     function testWithdrawFundsHappyFlow() public {
//         // User mints a VIP ticket
//         vm.startPrank(user);
//         usdcToken.approve(address(eventContract), 100 * 10**6);
//         eventContract.mintTicket("VIP");
//         vm.stopPrank();

//         // Move time forward to after event end
//         vm.warp(block.timestamp + 4 days);
//         // Vendor withdraws funds
//         vm.startPrank(vendor);
//         eventContract.withdrawFunds();
//         assertEq(usdcToken.balanceOf(vendor), 99 * 10**6); // 99 USDC to vendor
//         assertEq(usdcToken.balanceOf(treasury), 1 * 10**6); // 1 USDC to treasury
//         vm.stopPrank();
//     }

//     function testMintTicketUnhappyFlow() public {
//         // User tries to mint a VIP ticket after ticket sale end
//         vm.startPrank(user);
//         usdcToken.approve(address(eventContract), 100 * 10**6);
//         vm.warp(block.timestamp + 2 days); // Move time forward to after ticket sale end
//         vm.expectRevert(EventContract.TicketSaleNotActive.selector);
//         eventContract.mintTicket("VIP");
//         vm.stopPrank();
//     }

//     function testWithdrawFundsUnhappyFlow() public {
//         // User mints a VIP ticket
//         vm.startPrank(user);
//         usdcToken.approve(address(eventContract), 100 * 10**6);
//         eventContract.mintTicket("VIP");
//         vm.stopPrank();

//         // Vendor tries to withdraw funds before event end
//         vm.startPrank(vendor);
//         vm.expectRevert(EventContract.EventNotOver.selector);
//         eventContract.withdrawFunds();
//         vm.stopPrank();
//     }

//     function testCancelEventAutoRefund_And_CheckUserBalance() public {
//         // User mints a VIP ticket
//         vm.startPrank(user);
//         usdcToken.approve(address(eventContract), 100 * 10**6);
//         eventContract.mintTicket("VIP");
//         vm.stopPrank();

//         // Vendor cancels the event
//         vm.startPrank(vendor);
//         eventContract.cancelEventAndAutoRefund("Event cancelled");
//         assertTrue(eventContract.isCancelled());
//         vm.stopPrank();

//         // Check user balance
//         vm.prank(user);
//         assertEq(usdcToken.balanceOf(user), 100000000000 * 10**6); // User gets refund
//     }

//     function testClaimRefund() public {
//         // User mints a VIP ticket
//         // for(uint i = 0; i < 1000; i++) {
//             vm.startPrank(user);
//             usdcToken.approve(address(eventContract), 100 * 10**6);
//             eventContract.mintTicket("VIP");
//             vm.stopPrank();
//         // }
//         // for(uint i = 0; i < 3000; i++) {
//         //     vm.startPrank(user);
//         //     usdcToken.approve(address(eventContract), 100 * 10**6);
//         //     eventContract.mintTicket("REG");
//         //     vm.stopPrank();
//         // }

//         // Check total supply of tickets
//         assertEq(eventContract.totalSupply(), 1);


//         // Vendor cancels the event
//         vm.prank(vendor);
//         eventContract.cancelEventOnly("Event cancelled");

//         // // Check user balance
//         vm.startPrank(user);
//         eventContract.claimRefund(1);
//         assertEq(usdcToken.balanceOf(user), 100000000000 * 10**6); // User gets refund
//         vm.stopPrank();

//     }

//     function testGetUserTickets() public {
//         // User mints two VIP tickets
//         vm.startPrank(user);
//         usdcToken.approve(address(eventContract), 200 * 10**6);
//         eventContract.mintTicket("VIP");
//         eventContract.mintTicket("VIP");
//         vm.stopPrank();

//         // Get user tickets
//         (uint256[] memory ticketIds, string[] memory ticketTypes) = eventContract.getUserTickets(user);
//         assertEq(ticketIds.length, 2);
//         assertEq(ticketTypes.length, 2);
//         assertEq(ticketTypes[0], "VIP");
//         assertEq(ticketTypes[1], "VIP");
//     }

//     function testUseTicket() public {
//         // User mints and uses a VIP ticket
//         vm.startPrank(user);
//         usdcToken.approve(address(eventContract), 100 * 10**6);
//         eventContract.mintTicket("VIP");
//         eventContract.useTicket(1);
//         assertEq(eventContract.balanceOf(user), 0);
//         vm.stopPrank();
//     }

//     function testTransferTicket() public {
//         // User mints and transfers a VIP ticket
//         vm.startPrank(user);
//         usdcToken.approve(address(eventContract), 100 * 10**6);
//         eventContract.mintTicket("VIP");
//         eventContract.transferTicket(address(0x5), 1);
//         assertEq(eventContract.balanceOf(address(0x5)), 1);
//         vm.stopPrank();
//     }

//     function testModifyTicketMaxSupply() public {
//         // Vendor modifies the max supply of VIP tickets
//         vm.startPrank(vendor);
//         eventContract.modifyTicketMaxSupply("VIP", 200);
//         (,,uint256 maxSupply,) = eventContract.tickets("VIP");
//         assertEq(maxSupply, 200);
//         vm.stopPrank();
//     }

//     function testAddEventOwner() public {
//         // Vendor adds an additional event owner
//         vm.startPrank(vendor);
//         eventContract.addEventOwner(address(0x6));
//         assertTrue(eventContract.additionalEventOwners(address(0x6)));
//         vm.stopPrank();
//     }

//     function testRemoveEventOwner() public {
//         // Vendor removes an additional event owner
//         vm.startPrank(vendor);
//         eventContract.addEventOwner(address(0x6));
//         eventContract.removeEventOwner(address(0x6));
//         assertFalse(eventContract.additionalEventOwners(address(0x6)));
//         vm.stopPrank();
//     }

//     function testPauseAndUnpause() public {
//         // Master owner pauses and unpauses the event
//         vm.startPrank(masterOwner);
//         eventContract.pause();
//         assertTrue(eventContract.paused());
//         eventContract.unpause();
//         assertFalse(eventContract.paused());
//         vm.stopPrank();
//     }
// }
