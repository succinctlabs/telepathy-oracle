pragma solidity ^0.8.16;

import {SubscriptionData} from "src/pubsub/TelepathySubscriber.sol";
import {Log, EventProof} from "src/pubsub/EventProofHelper.sol";

import {TelepathyRouter} from "telepathy-contracts/amb/TelepathyRouter.sol";
import {ITelepathyHandler} from "telepathy-contracts/amb/interfaces/TelepathyHandler.sol";
import {SSZ} from "telepathy-contracts/libraries/SimpleSerialize.sol";
import {Address} from "telepathy-contracts/libraries/Typecast.sol";

enum PublishStatus {
    NOT_EXECUTED,
    EXECUTION_FAILED,
    EXECUTION_SUCCEEDED
}

// TODO: This (and Oracle Fulfiller) probably should have access control so the router reference can be set again.

/// @title TelepathyPublisher
/// @author Succinct Labs
/// @notice A contract that can publish events to a TelepathySubscriber.
/// @dev For true "PubSub" we should handle N many Subscribers. This currently just handles one Subscriber per publish call.
contract TelepathyPublisher {
    event Publish(
        bytes32 indexed subscriptionId,
        uint32 indexed sourceChainId,
        address indexed sourceAddress,
        address callbackAddress,
        bool success
    );

    event ExecutedMessage(
        uint32 indexed sourceChainId,
        uint64 indexed nonce,
        bytes32 indexed msgHash,
        bytes message,
        bool status
    );

    TelepathyRouter telepathyRouter;

    mapping(bytes32 => PublishStatus) public eventsPublished;

    constructor(address _telepathyRouter) {
        telepathyRouter = TelepathyRouter(_telepathyRouter);
    }

    /// @notice Publishes an event emit to a callback Subscriber, given an event proof.
    /// @param srcSlotTxSlotPack The slot where we want to read the header from and the slot where
    ///                          the tx executed, packed as two uint64s.
    /// @param receiptsRootProof A merkle proof proving the receiptsRoot in the block header.
    /// @param receiptsRoot The receipts root which contains the event.
    /// @param txIndexRLPEncoded The index of our transaction inside the block RLP encoded.
    /// @param logIndex The index of the event in our transaction.
    /// @param subscriptionData The subscription data (sourceChainId, sourceAddress, callbackAddress, eventSig).
    /// @dev subscriptionData struct is being used to avoid stack-too-deep
    function publishEvent(
        bytes calldata srcSlotTxSlotPack,
        bytes32[] calldata receiptsRootProof,
        bytes32 receiptsRoot,
        bytes[] calldata receiptProof,
        bytes memory txIndexRLPEncoded,
        uint256 logIndex,
        Log calldata log,
        SubscriptionData calldata subscriptionData
    ) external {
        requireLightClientConsistency(subscriptionData.sourceChainId);
        requireNotFrozen(subscriptionData.sourceChainId);

        // Ensure the event has only been published to a subscriber once.
        bytes32 eventKey =
            keccak256(abi.encode(receiptsRoot, logIndex, subscriptionData.callbackAddress));
        require(eventsPublished[eventKey] == PublishStatus.NOT_EXECUTED, "Event already published");

        {
            (uint64 srcSlot, uint64 txSlot) = abi.decode(srcSlotTxSlotPack, (uint64, uint64));
            requireLightClientDelay(srcSlot, subscriptionData.sourceChainId);
            bytes32 headerRoot =
                telepathyRouter.lightClients(subscriptionData.sourceChainId).headers(srcSlot);
            require(headerRoot != bytes32(0), "HeaderRoot is missing");
            bool isValid =
                SSZ.verifyReceiptsRoot(receiptsRoot, receiptsRootProof, headerRoot, srcSlot, txSlot);
            require(isValid, "Invalid receipts root proof");
        }

        {
            EventProof.verifyEvent(receiptProof, receiptsRoot, txIndexRLPEncoded, logIndex, log);
        }

        _publish(subscriptionData, eventKey, log);
    }

    /// @notice Checks that the light client for a given chainId is consistent.
    function requireLightClientConsistency(uint32 chainId) internal view {
        require(
            address(telepathyRouter.lightClients(chainId)) != address(0), "Light client is not set."
        );
        require(telepathyRouter.lightClients(chainId).consistent(), "Light client is inconsistent.");
    }

    /// @notice Checks that the chainId is not frozen.
    function requireNotFrozen(uint32 chainId) internal view {
        require(!telepathyRouter.frozen(chainId), "Contract is frozen.");
    }

    /// @notice Checks that the light client delay is adequate.
    function requireLightClientDelay(uint64 slot, uint32 chainId) internal view {
        require(
            address(telepathyRouter.lightClients(chainId)) != address(0), "Light client is not set."
        );
        require(
            telepathyRouter.lightClients(chainId).timestamps(slot) != 0,
            "Timestamp is not set for slot."
        );
        uint256 elapsedTime =
            block.timestamp - telepathyRouter.lightClients(chainId).timestamps(slot);
        require(
            elapsedTime >= telepathyRouter.MIN_LIGHT_CLIENT_DELAY(),
            "Must wait longer to use this slot."
        );
    }

    /// @notice Executes the callback function on the subscriber, and marks the event publish as successful or failed.
    function _publish(
        SubscriptionData calldata subscriptionData,
        bytes32 eventKey,
        Log calldata log
    ) internal {
        bytes32 subscriptionId = keccak256(abi.encode(subscriptionData));
        bytes memory encodedData = abi.encode(subscriptionId, log);

        bool status;
        bytes memory data;
        {
            bytes memory receiveCall = abi.encodeWithSelector(
                ITelepathyHandler.handleTelepathy.selector,
                subscriptionData.sourceChainId,
                subscriptionData.sourceAddress,
                encodedData
            );
            (status, data) = subscriptionData.callbackAddress.call(receiveCall);
        }

        bool implementsHandler = false;
        if (data.length == 32) {
            (bytes4 magic) = abi.decode(data, (bytes4));
            implementsHandler = magic == ITelepathyHandler.handleTelepathy.selector;
        }

        if (status && implementsHandler) {
            eventsPublished[eventKey] = PublishStatus.EXECUTION_SUCCEEDED;
        } else {
            eventsPublished[eventKey] = PublishStatus.EXECUTION_FAILED;
        }

        emit Publish(
            subscriptionId,
            subscriptionData.sourceChainId,
            subscriptionData.sourceAddress,
            subscriptionData.callbackAddress,
            status
        );
    }
}
