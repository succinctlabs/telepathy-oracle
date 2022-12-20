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

    /**
     * @dev Request the owner of an ENS name.
     * @param requester The address of the requester contract.
     * @param ensFulfiller The address of the ENS fulfiller contract on Ethereum.
     * @param getENSOwnerSelector The selector of the getENSOwner function on the ENS fulfiller contract.
     * @param node The ENS node of the name (namehash of .eth string).
     * @param gasLimit The gas limit for the callback.
     */
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

    /**
     * @dev Callback function to receive the owner of an ENS name.
     * @param _owner The owner of the ENS name.
     */
    function receiveENSOwner(address _owner) external {
        owner = _owner;
        // do something with the owner...
    }
}
