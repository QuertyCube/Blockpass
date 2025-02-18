// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract TreasuryFund {
    address public owner;

    event TreasuryFundWithdrawn(address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function withdrawFunds(address _to, uint256 _amount) external onlyOwner {
        payable(_to).transfer(_amount);
        emit TreasuryFundWithdrawn(_to, _amount);
    }

    receive() external payable {}
}
