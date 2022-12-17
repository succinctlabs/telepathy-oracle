// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {IBroadcaster} from "./interfaces/IBroadcaster.sol";

/**
 * @dev Deploy on Ethereum. Fulfills requests to view functions from the
 *  TelepathyOracleRequest contract and returns result on Telepathy
 */
contract TelepathyOracleFulfill {
    IBroadcaster succinct;
    uint16 public targetChainId;

    error CallFailed(bytes callData);

    constructor(address _succinct, uint16 _targetChainId) {
        succinct = IBroadcaster(_succinct);
        targetChainId = _targetChainId;
    }

    /**
     * @notice handles request for view function and send result to telepathy
     * @param target contract address to call
     * @param data calldata for view call
     * @return messageRoot from .send call to AMB
     */
    function fulfillRequest(
        address target,
        bytes calldata data,
        address callbackContract,
        bytes4 callbackSelector
    ) external returns (bytes32) {
        // unwrap data
        (uint256 requestNonce, address receiver, uint256 gasLimit, bytes memory callData) =
            abi.decode(data, (uint256, address, uint256, bytes));

        // make view call
        (bool success, bytes memory result) = target.call(callData);
        if (!success) {
            revert CallFailed(callData);
        }

        // rewrap nonce with result to send back
        bytes memory returnVal =
            abi.encode(requestNonce, callbackContract, callbackSelector, result);

        return succinct.send(receiver, targetChainId, gasLimit, returnVal);
    }
}
