pragma solidity ^0.8.16;

import {SubscriptionData} from "src/pubsub/TelepathySubscriber.sol";
import {EventProof} from "src/pubsub/EventProofHelper.sol";

import {TelepathyRouter} from "telepathy-contracts/amb/TelepathyRouter.sol";
import {ITelepathyHandler} from "telepathy-contracts/amb/interfaces/TelepathyHandler.sol";
import {SSZ} from "telepathy-contracts/libraries/SimpleSerialize.sol";
import {Address} from "telepathy-contracts/libraries/Typecast.sol";

// TODO: This (and Oracle Fulfiller) probably should have access control so the router reference can be set again.

/// @notice A contract that can publish events to a TelepathySubscriber.
/// @dev For true "PubSub" we should handle N many subscribers. This currently just handles one subscriber per publish call.
contract TelepathyPublisher {
    event Publish(bytes32 indexed subscriptionId, bool received);

    TelepathyRouter telepathyRouter;

    constructor(address _telepathyRouter) {
        telepathyRouter = TelepathyRouter(_telepathyRouter);
    }

    /// @notice Publishes an event emit to a callback subscriber, given an event proof.
    /// @param srcSlotTxSlotPack The slot where we want to read the header from and the slot where
    ///                          the tx executed, packed as two uint64s.
    /// @param receiptsRootProof A merkle proof proving the receiptsRoot in the block header.
    /// @param receiptsRoot The receipts root which contains the event.
    /// @param txIndexRLPEncoded The index of our transaction inside the block RLP encoded.
    /// @param logIndex The index of the event in our transaction.
    /// @param subscriptionData The subscription data (sourceChainId, sourceAddress, callbackAddress, eventSig).
    /// @param eventData The data the event was emitted with. T
    /// @dev subscriptionData struct is being used to avoid stack-too-deep
    function publishEvent(
        bytes calldata srcSlotTxSlotPack,
        bytes32[] calldata receiptsRootProof,
        bytes32 receiptsRoot,
        bytes[] calldata receiptProof,
        bytes memory txIndexRLPEncoded,
        uint256 logIndex,
        SubscriptionData calldata subscriptionData,
        bytes calldata eventData
    ) external {
        if (
            address(telepathyRouter.lightClients(subscriptionData.sourceChainId)) == address(0)
                || telepathyRouter.broadcasters(subscriptionData.sourceChainId) == address(0)
        ) {
            revert("Light client or broadcaster for source chain is not set");
        }

        requireLightClientConsistency(subscriptionData.sourceChainId);
        requireNotFrozen(subscriptionData.sourceChainId);

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
            EventProof.verifyEvent(
                receiptProof,
                receiptsRoot,
                txIndexRLPEncoded,
                logIndex,
                telepathyRouter.broadcasters(subscriptionData.sourceChainId),
                subscriptionData.eventSig
            );
        }

        _publish(subscriptionData, eventData);
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

    function _publish(SubscriptionData calldata subscriptionData, bytes memory eventData)
        internal
    {
        bytes32 subscriptionId = keccak256(abi.encode(subscriptionData));
        bytes memory data = abi.encode(subscriptionId, eventData);

        bool recieved;
        {
            bytes memory receiveCall = abi.encodeWithSelector(
                ITelepathyHandler.handleTelepathy.selector,
                subscriptionData.sourceChainId,
                subscriptionData.sourceAddress,
                data
            );
            (recieved,) = subscriptionData.callbackAddress.call(receiveCall);
        }

        emit Publish(subscriptionId, recieved);
    }
}
