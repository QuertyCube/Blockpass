// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/TreasuryFund.sol";

contract TestTreasuryFund is Test {
    TreasuryFund treasuryFund;
    address owner;
    address nonOwner;

    function setUp() public {
        owner = address(this);
        nonOwner = address(0x123);
        treasuryFund = new TreasuryFund();
    }

    function testWithdrawFunds() public {
        // Arrange
        address recipient = address(0x456);
        uint256 amount = 1 ether;
        vm.deal(address(treasuryFund), amount);

        // Act
        treasuryFund.withdrawFunds(recipient, amount);

        // Assert
        assertEq(recipient.balance, amount);
    }

    function testWithdrawFundsOnlyOwner() public {
        // Arrange
        address recipient = address(0x456);
        uint256 amount = 1 ether;
        vm.deal(address(treasuryFund), amount);

        // Act & Assert
        vm.prank(nonOwner);
        vm.expectRevert("Not owner");
        treasuryFund.withdrawFunds(recipient, amount);
    }

    function testReceiveFunds() public {
        // Arrange
        uint256 amount = 1 ether;

        // Act
        (bool success,) = address(treasuryFund).call{value: amount}("");

        // Assert
        assertTrue(success);
        assertEq(address(treasuryFund).balance, amount);
    }
}
