pragma solidity ^0.8.0;

contract MasterOwnerModifier {
    mapping(address => bool) public owners;

    // Define events
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);

    // Add a new owner to the list
    function addMasterOwner(address _owner) public {
        require(!owners[_owner], "Address is already an owner");
        owners[_owner] = true;
        emit OwnerAdded(_owner); // Emit event
    }

    // Remove an owner from the list
    function removeMasterOwner(address _owner) public {
        require(owners[_owner], "Address is not an owner");
        owners[_owner] = false;
        emit OwnerRemoved(_owner); // Emit event
    }

    // Check if an address is an owner
    function isMasterOwner(address _owner) public view returns (bool) {
        return owners[_owner];
    }
}