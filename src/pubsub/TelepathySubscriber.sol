pragma solidity ^0.8.16;

enum SubscriptionStatus {
    UNSUBSCIBED,
    SUBSCRIBED
}

/// @notice Represents an active subscription.
/// @dev A subscription with will still be active even if the endBlock has passed. To renew a subscription
///      with different block ranges, unsubscribe and re-subscribe.
/// @param sourceChainId The chain ID of the source contract.
/// @param sourceAddress The address of the source contract which emits the target event.
/// @param callbackAddress The address of the contract which will receive the event data.
/// @param eventSig The signature of the event to listen for.
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
    /// @param subscriptionId The unique identifier for the subscription.
    /// @param startBlock The block number to start listening for events, 0 for all blocks.
    /// @param endBlock The block number to stop listening for events, 0 for infinite.
    /// @param subscription The subscription details.
    event Subscribe(
        bytes32 indexed subscriptionId,
        uint256 indexed startBlock,
        uint256 indexed endBlock,
        Subscription subscription
    );

    /// @param subscriptionId The unique identifier for the subscription.
    /// @param subscription The subscription details.
    event Unsubscribe(bytes32 indexed subscriptionId, Subscription subscription);

    error SubscriptionAlreadyActive(bytes32 subscriptionId);
    error SubscriptionNotActive(bytes32 subscriptionId);
    error InvalidBlockRange(uint256 startBlock, uint256 endBlock);

    mapping(bytes32 => SubscriptionStatus) public subscriptions;

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

        // If a startBlock is specified, endBlock must be specified and after it.
        if (_startBlock > 0 && _endBlock < _startBlock) {
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
