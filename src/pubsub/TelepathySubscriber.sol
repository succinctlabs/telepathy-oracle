pragma solidity ^0.8.16;

enum SubscriptionStatus {
    UNSUBSCIBED,
    SUBSCRIBED
}

struct SubscriptionData {
    uint32 sourceChainId;
    address sourceAddress;
    address callbackAddress;
    bytes32 eventSig;
}

contract TelepathySubscriber {
    event Subscribe(bytes32 indexed subscriptionId, SubscriptionData subscriptionData);
    event Unsubscribe(bytes32 indexed subscriptionId, SubscriptionData subscriptionData);

    error SubscriptionAlreadyActive(bytes32 subscriptionId);
    error SubscriptionNotActive(bytes32 subscriptionId);

    mapping(bytes32 => SubscriptionStatus) public subscriptions;

    function subscribe(
        uint32 _sourceChainId,
        address _sourceAddress,
        address _callbackAddress,
        bytes32 _eventSig
    ) external returns (bytes32 subscriptionId) {
        SubscriptionData memory subscriptionData =
            SubscriptionData(_sourceChainId, _sourceAddress, _callbackAddress, _eventSig);
        subscriptionId = keccak256(abi.encode(subscriptionData));

        if (subscriptions[subscriptionId] == SubscriptionStatus.SUBSCRIBED) {
            revert SubscriptionAlreadyActive(subscriptionId);
        }
        subscriptions[subscriptionId] = SubscriptionStatus.SUBSCRIBED;

        emit Subscribe(subscriptionId, subscriptionData);

        return subscriptionId;
    }

    /// @dev Only the original callbackAddress contract will be able to unsubscribe.
    function unsubscribe(uint32 _sourceChainId, address _sourceAddress, bytes32 _eventSig)
        external
    {
        SubscriptionData memory subscriptionData =
            SubscriptionData(_sourceChainId, _sourceAddress, msg.sender, _eventSig);
        bytes32 subscriptionId = keccak256(abi.encode(subscriptionData));

        if (subscriptions[subscriptionId] == SubscriptionStatus.UNSUBSCIBED) {
            revert SubscriptionNotActive(subscriptionId);
        }
        subscriptions[subscriptionId] = SubscriptionStatus.UNSUBSCIBED;

        emit Unsubscribe(subscriptionId, subscriptionData);
    }
}
