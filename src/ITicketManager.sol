// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface ITicketManager {
    function addTickets(address eventContract, bytes32[] calldata _ticketTypes, uint256[] calldata _prices, uint256[] calldata _maxSupplies) external;
    function mintTicket(address eventContract, bytes32 _ticketType) external;
    function getUserTickets(address _user) external view returns (uint256[] memory, bytes32[] memory);
    function useTicket(uint256 _tokenId) external;
    function modifyTicketMaxSupply(address eventContract, bytes32 _ticketType, uint256 _newMaxSupply) external;
    function withdrawFunds(address eventContract) external;
    function cancelEventAndAutoRefund(address eventContract, string calldata reason) external;
    function getTicketDetails(bytes32 ticketType) external view returns (uint256 price, uint256 supply);
}
