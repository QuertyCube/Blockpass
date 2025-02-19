// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Master.sol";
import "../src/EventContract.sol";

contract MasterContractTest is Test {
    MasterContract masterContract;
    address treasuryContract = address(0x123);
    address usdcToken = address(0x456);
    address vendor = address(0x789);

    function setUp() public {
        masterContract = new MasterContract(treasuryContract);
        masterContract.addVendor(vendor);
    }

    function testCreateEvent() public {
        address newEventAddress = createEvent();

        // Verify the event was created
        assertTrue(newEventAddress != address(0));
        assertEq(masterContract.eventContracts(0), newEventAddress);
    }
    function createEvent() internal returns (address) {
        // Prepare the EventParams
        MasterContract.TicketInfo[] memory ticketInfos = new MasterContract.TicketInfo[](2);
        ticketInfos[0] = MasterContract.TicketInfo({ticketType: "VIP", price: 100 * 10**6, maxSupply: 100});
        ticketInfos[1] = MasterContract.TicketInfo({ticketType: "Regular", price: 50 * 10**6, maxSupply: 500});

        MasterContract.EventParams memory params = MasterContract.EventParams({
            name: "My Event",
            nftSymbol: "MEVT",
            start: 1672531200,
            end: 1672617600,
            startSale: 1672444800,
            endSale: 1672527600,
            ticketInfos: ticketInfos,
            usdcToken: usdcToken
        });

        // Call createEvent as the vendor
        vm.prank(vendor);
        address newEventAddress = masterContract.createEvent(params);
        return newEventAddress;
    }
}
