// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "./MasterOwnerModifier.sol";

contract EventManager is Pausable {
    address public eventOwner;
    MasterOwnerModifier public masterOwnerModifier;

    bool public isCancelled = false;

    event EventCancelled(string reason);
    event FundsWithdrawn(address indexed vendor, uint256 vendorAmount, uint256 treasuryAmount);

    error EventNotCancel();
    error EventNotOver();
    error NoFundsAvailable();
    error InvalidAddress();
    error NotEventOwner();
    error NotMasterOwner();
    error NotMasterOrEventOwner();
    error PaymentFailed();

    modifier onlyEventOwner() {
        if (msg.sender != eventOwner) revert NotEventOwner();
        _;
    }

    modifier onlyMasterOwner() {
        if (!masterOwnerModifier.isMasterOwner(msg.sender)) revert NotMasterOwner();
        _;
    }

    modifier onlyVendorOrOwner() {
        if (msg.sender != eventOwner && !masterOwnerModifier.isMasterOwner(msg.sender)) revert NotMasterOrEventOwner();
        _;
    }

    constructor(
        address _vendor,
        address _ownerModifierAddress
    ) {
        eventOwner = _vendor;
        masterOwnerModifier = MasterOwnerModifier(_ownerModifierAddress);
    }

    function cancelEvent(string calldata reason) external onlyVendorOrOwner {
        if (isCancelled) revert EventNotCancel();
        isCancelled = true;
        emit EventCancelled(reason);
    }

    function withdrawFunds(uint256 totalRevenue) external onlyVendorOrOwner whenNotPaused {
        if (isCancelled) revert EventNotCancel();
        if (totalRevenue == 0) revert NoFundsAvailable();

        uint256 treasuryAmount = totalRevenue / 100; // 1% for treasury
        uint256 vendorAmount = totalRevenue - treasuryAmount;

        if (!payable(eventOwner).send(vendorAmount)) revert PaymentFailed();
        // if (!payable(masterOwnerModifier.treasuryContract()).send(treasuryAmount)) revert PaymentFailed();

        emit FundsWithdrawn(eventOwner, vendorAmount, treasuryAmount);
    }

    function pause() external onlyMasterOwner {
        _pause();
    }

    function unpause() external onlyMasterOwner {
        _unpause();
    }
}
