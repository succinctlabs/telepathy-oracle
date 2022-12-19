// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

/**
 * @dev Deploy on L2 to receive the owner of an ENS name.
 */
contract ENSReceiver {
    address public owner;

    function receiveENSOwner(address _owner) external {
        owner = _owner;
        // do something with the owner...
    }
}
