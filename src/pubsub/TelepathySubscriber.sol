pragma solidity ^0.8.16;

enum SubscriptionStatus {
    UNSUBSCIBED,
    SUBSCRIBED
}

struct Subscription {
    uint32 sourceChainId;
    address sourceAddress;
    address callbackAddress;
    bytes32 eventSig;
}

/// @title TelepathySubscriber
/// @author Succinct Labs
/// @notice This allows contracts to subscribe to cross-chain events from a source contract.
contract TelepathySubscriber {
    event Subscribe(bytes32 indexed subscriptionId, Subscription subscription);
    event Unsubscribe(bytes32 indexed subscriptionId, Subscription subscription);

    error SubscriptionAlreadyActive(bytes32 subscriptionId);
    error SubscriptionNotActive(bytes32 subscriptionId);

    mapping(bytes32 => SubscriptionStatus) public subscriptions;

    function subscribe(
        uint32 _sourceChainId,
        address _sourceAddress,
        address _callbackAddress,
        bytes32 _eventSig
    ) external returns (bytes32 subscriptionId) {
        Subscription memory subscription =
            Subscription(_sourceChainId, _sourceAddress, _callbackAddress, _eventSig);
        subscriptionId = keccak256(abi.encode(subscription));

        if (subscriptions[subscriptionId] == SubscriptionStatus.SUBSCRIBED) {
            revert SubscriptionAlreadyActive(subscriptionId);
        }
        subscriptions[subscriptionId] = SubscriptionStatus.SUBSCRIBED;

        emit Subscribe(subscriptionId, subscription);

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
