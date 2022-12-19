// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

contract MockENSRegistry {
    mapping(bytes32 => address) public resolver;

    function setResolver(bytes32 node, address _resolver) external {
        resolver[node] = _resolver;
    }
}

contract MockENSResolver {
    mapping(bytes32 => address) public addr;

    function setAddr(bytes32 node, address _addr) external {
        addr[node] = _addr;
    }
}
