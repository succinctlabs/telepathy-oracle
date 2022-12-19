// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

interface IENSRegistry {
    function resolver(bytes32 node) external view returns (address);
}

interface IResolver {
    function addr(bytes32 node) external view returns (address);
}

/**
 * @dev deploy on ethereum mainnet to get the owner of an ENS name
 */
contract ENSFulfiller {
    address public registry;

    constructor(address _registry) {
        registry = _registry;
    }

    function getENSOwner(bytes32 node) external view returns (address) {
        // call resolver on the ENS registry with the node
        address resolver = IENSRegistry(registry).resolver(node);

        // call the resolver's addr() function
        address addr = IResolver(resolver).addr(node);
        return addr;
    }
}
