pragma solidity ^0.8.14;

abstract contract IENSRegistry {
    function resolver(bytes32 node) public view virtual returns (IResolver);
}

abstract contract IResolver {
    function addr(bytes32 node) public view virtual returns (address);
}

/// @title ENSUtil
/// @notice Simple util to resolve an ENS name to an address in one function
contract ENSUtil {
    IENSRegistry public registry;

    constructor(address _registry) {
        registry = IENSRegistry(_registry);
    }

    /// @dev If the resolver is an offchain resolver, this will revert with OffchainLookup error
    function resolve(bytes32 _node) external view returns (address) {
        return registry.resolver(_node).addr(_node);
    }
}
