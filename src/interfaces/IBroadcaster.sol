// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IBroadcaster {
    event SentMessage(
        uint256 indexed nonce,
        bytes32 indexed msgHash,
        bytes message
    );
    event ShortSentMessage(uint256 indexed nonce, bytes32 indexed msgHash);

    function send(
        address recipient,
        uint16 recipientChainId,
        uint256 gasLimit,
        bytes calldata data
    ) external returns (bytes32);
}
