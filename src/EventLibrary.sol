// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

library EventLibrary {
    struct TicketInfo {
        bytes32 ticketType; // Use bytes32 instead of string
        uint256 price;
        uint256 maxSupply;
    }

    struct EventParams {
        bytes32 name; // Use bytes32 instead of string
        bytes32 nftSymbol; // Use bytes32 instead of string
        uint256 start;
        uint256 end;
        uint256 startSale;
        uint256 endSale;
        TicketInfo[] ticketInfos;
    }
}
