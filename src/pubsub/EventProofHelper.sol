pragma solidity ^0.8.16;

import {RLPReader} from "optimism-bedrock-contracts/rlp/RLPReader.sol";
import {RLPWriter} from "optimism-bedrock-contracts/rlp/RLPWriter.sol";
import {MerkleTrie} from "optimism-bedrock-contracts/trie/MerkleTrie.sol";

// Equivalent to the https://github.com/succinctlabs/telepathy/blob/00482454f7301be012a165560e2368aa7d375992/node_modules/%40ethereumjs/evm/src/types.ts#L226
// export type Log = [address: Buffer, topics: Buffer[], data: Buffer]
struct Log {
    address source;
    bytes32[] topics;
    bytes data;
}

library EventProof {
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;
    
    /// @notice Verifies that the given log data is valid for the given event proof.
    function verifyEvent(
        bytes[] memory proof,
        bytes32 receiptRoot,
        bytes memory key,
        uint256 logIndex,
        Log memory log
    ) internal pure {
        bytes memory value = MerkleTrie.get(key, proof, receiptRoot);
        bytes1 txTypeOrFirstByte = value[0];

        // Currently, there are three possible transaction types on Ethereum. Receipts either come
        // in the form "TransactionType | ReceiptPayload" or "ReceiptPayload". The currently
        // supported set of transaction types are 0x01 and 0x02. In this case, we must truncate
        // the first byte to access the payload. To detect the other case, we can use the fact
        // that the first byte of a RLP-encoded list will always be greater than 0xc0.
        // Reference 1: https://eips.ethereum.org/EIPS/eip-2718
        // Reference 2: https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp
        uint256 offset;
        if (txTypeOrFirstByte == 0x01 || txTypeOrFirstByte == 0x02) {
            offset = 1;
        } else if (txTypeOrFirstByte >= 0xc0) {
            offset = 0;
        } else {
            revert("Unsupported transaction type");
        }

        // Truncate the first byte if eneded and get the RLP decoding of the receipt.
        uint256 ptr;
        assembly {
            ptr := add(value, 32)
        }
        RLPReader.RLPItem memory valueAsItem = RLPReader.RLPItem({
            length: value.length - offset,
            ptr: RLPReader.MemoryPointer.wrap(ptr + offset)
        });

        // The length of the receipt must be at least four, as the fourth entry contains events
        RLPReader.RLPItem[] memory valueAsList = valueAsItem.readList();
        require(valueAsList.length == 4, "Invalid receipt length");

        // Read the logs from the receipts and check that it is not ill-formed
        RLPReader.RLPItem[] memory logs = valueAsList[3].readList();
        require(logIndex < logs.length, "Log index out of bounds");
        RLPReader.RLPItem[] memory relevantLog = logs[logIndex].readList();

        // Validate that the correct contract emitted the event
        address sourceContract = relevantLog[0].readAddress();
        require(sourceContract == log.source, "Event was not emitted by source contract");

        // Validate that the correct topics were emitted
        RLPReader.RLPItem[] memory topics = relevantLog[1].readList();
        require(topics.length == log.topics.length, "Event topic length does not match");
        for (uint256 i = 0; i < topics.length; i++) {
            require(bytes32(topics[i].readUint256()) == log.topics[i], "Event topic does not match");
        }

        // Validate that the correct data was emitted
        bytes memory data = relevantLog[2].readBytes();
        require(data.length == log.data.length, "Event data does not match");
    }
}
