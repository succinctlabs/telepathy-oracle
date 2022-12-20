// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

interface IRequester {
    function requestView(
        address callbackContract,
        bytes4 callbackSelector,
        address target,
        bytes4 selector,
        bytes memory data,
        uint256 gasLimit
    ) external returns (bytes memory);
}

/**
 * @dev Deploy on L2 to receive the owner of an ENS name.
 */
contract ENSReceiver {
    address public owner;

    // TODO
    function requestENS(
        address requester,
        address ensFulfiller,
        bytes4 getENSOwnerSelector,
        bytes32 node,
        uint256 gasLimit
    ) external returns (bytes memory) {
        return IRequester(requester).requestView(
            address(this),
            this.receiveENSOwner.selector,
            address(ensFulfiller),
            getENSOwnerSelector,
            abi.encode(node),
            gasLimit
        );
    }

    function receiveENSOwner(address _owner) external {
        owner = _owner;
        // do something with the owner...
    }
}
