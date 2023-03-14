pragma solidity ^0.8.16;

import {Subscription, SubscriptionStatus, ISubscriber} from "src/pubsub/interfaces/IPubSub.sol";

/// @title TelepathySubscriber
/// @author Succinct Labs
/// @notice This allows contracts to subscribe to cross-chain events from a source contract.
contract TelepathySubscriber is ISubscriber {
    error SubscriptionAlreadyActive(bytes32 subscriptionId);
    error SubscriptionNotActive(bytes32 subscriptionId);
    error InvalidBlockRange(uint256 startBlock, uint256 endBlock);

    mapping(bytes32 => SubscriptionStatus) public subscriptions;

    /// @dev The block ranges use as a signal to off-chain, and are NOT enforced by the publisher.
    ///     If events should only a certain range should be valid, the callbackAddress should do their
    ///     own validation when handling the publish.
    function subscribe(
        uint32 _sourceChainId,
        address _sourceAddress,
        address _callbackAddress,
        bytes32 _eventSig,
        uint256 _startBlock,
        uint256 _endBlock
    ) external returns (bytes32 subscriptionId) {
        Subscription memory subscription =
            Subscription(_sourceChainId, _sourceAddress, _callbackAddress, _eventSig);
        subscriptionId = keccak256(abi.encode(subscription));

        if (subscriptions[subscriptionId] == SubscriptionStatus.SUBSCRIBED) {
            revert SubscriptionAlreadyActive(subscriptionId);
        }
        subscriptions[subscriptionId] = SubscriptionStatus.SUBSCRIBED;

        // Either both blocks are 0, or endBlock is must greater than startBlock.
        if (_endBlock < _startBlock) {
            revert InvalidBlockRange(_startBlock, _endBlock);
        }

        emit Subscribe(subscriptionId, _startBlock, _endBlock, subscription);

        return subscriptionId;
    }

    /// @dev Only the original callbackAddress contract will be able to unsubscribe.
    function unsubscribe(uint32 _sourceChainId, address _sourceAddress, bytes32 _eventSig)
        external
    {
        Subscription memory subscription =
            Subscription(_sourceChainId, _sourceAddress, msg.sender, _eventSig);
        bytes32 subscriptionId = keccak256(abi.encode(subscription));

        if (subscriptions[subscriptionId] == SubscriptionStatus.UNSUBSCIBED) {
            revert SubscriptionNotActive(subscriptionId);
        }
        subscriptions[subscriptionId] = SubscriptionStatus.UNSUBSCIBED;

        emit Unsubscribe(subscriptionId, subscription);
    }
}
