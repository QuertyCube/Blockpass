// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface ITicketManager {
    function addTickets(bytes32[] calldata _ticketTypes, uint256[] calldata _prices, uint256[] calldata _maxSupplies) external;
    function mintTicket(bytes32 _ticketType, address _buyer) external;
    function useTicket(uint256 _tokenId, address _user) external;
    function refundAllTickets() external;
    function modifyTicketMaxSupply(bytes32 _ticketType, uint256 _newMaxSupply) external;

    function getTicketDetails(bytes32 _ticketType) external view returns (uint256 price, uint256 supply);
    function mintTicket(address buyer, bytes32 ticketType) external;
    function getUserTickets(address user) external view returns (uint256[] memory, bytes32[] memory);
    function refundAll() external;
}