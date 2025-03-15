// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract TreasuryFund {
    address public owner;

    event TreasuryFundWithdrawn(address indexed to, uint256 amount);

    /// @notice Ensures that the function is called only by the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    /// @notice Sets the deployer as the owner of the contract
    constructor() {
        owner = msg.sender;
    }

    /// @notice Withdraws funds from the treasury to a specified address
    /// @param _to The address to which the funds will be sent
    /// @param _amount The amount of funds to withdraw
    function withdrawFunds(address _to, uint256 _amount) external onlyOwner {
        payable(_to).transfer(_amount);
        emit TreasuryFundWithdrawn(_to, _amount);
    }

    /// @notice Allows the contract to receive Ether
    receive() external payable {}
}
