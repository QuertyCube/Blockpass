// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Master.sol";

contract MasterTest is Test {
    MasterContract master;
    address owner;
    address addr1;
    address addr2;

    function setUp() public {
        // master = new MasterContract(input tresery contrac);
        owner = address(this);
        addr1 = address(0x1);
        addr2 = address(0x2);
    }

    function testCreate() public {
        // assertEq(master.owner(), owner);
    }
}
