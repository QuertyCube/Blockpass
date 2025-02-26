// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


/**
 * @title MockERC20
 * @dev Implementation of the ERC20 Token with mint and burn functions.
 */
contract MockERC20 is ERC20 {
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name}, {symbol}, and {decimals}. Mints 1,000,000 tokens to the deployer.
     */
    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _decimals = decimals_;
        _mint(msg.sender, 1_000_000 * (10 ** uint256(decimals_))); // Mint 1M tokens to deployer
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Mints `amount` tokens to `to`. Can only be called by the owner.
     */
    function mint(address to, uint256 amount) external  {
        _mint(to, amount);
    }

    /**
     * @dev Burns `amount` tokens from `from`. Can only be called by the owner.
     */
    function burn(address from, uint256 amount) external  {
        _burn(from, amount);
    }
}
