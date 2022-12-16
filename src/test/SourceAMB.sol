// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {IBroadcaster} from "../interfaces/IBroadcaster.sol";

contract SourceAMB is IBroadcaster {
    mapping(uint256 => bytes32) public messages;
    uint256 public nonce = 1;

    function send(address recipient, uint16 recipientChainId, uint256 gasLimit, bytes calldata data)
        external
        returns (bytes32)
    {
        bytes memory message =
            abi.encode(nonce, msg.sender, recipient, recipientChainId, gasLimit, data);
        bytes32 messageRoot = keccak256(message);
        messages[nonce] = messageRoot;
        emit SentMessage(nonce++, messageRoot, message);
        return messageRoot;
    }
}
