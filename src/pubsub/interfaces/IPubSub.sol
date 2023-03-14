pragma solidity ^0.8.16;

/// @notice The possible states a subscription can be in.
enum SubscriptionStatus {
    UNSUBSCIBED,
    SUBSCRIBED
}

/// @notice Represents an active subscription, specific to the combination of all of the parameters.
/// @param sourceChainId The chain ID of the source contract.
/// @param sourceAddress The address of the source contract which emits the target event.
/// @param callbackAddress The address of the contract which will receive the event data. MUST be implement
///     the ISubscriptionCallbackReceiver interface.
/// @param eventSig The signature of the event to listen for.
/// @dev A subscription with will still be active even if the endBlock has passed. To renew a subscription
///     with different block ranges, unsubscribe and re-subscribe.
struct Subscription {
    uint32 sourceChainId;
    address sourceAddress;
    address callbackAddress;
    bytes32 eventSig;
}

/// @notice Represents emitted event data.
/// @param source The address of the contract that emitted the log.
/// @param topics The topics associated with the log, length changes with # of indexed fields.
/// @param data The data associated with the log.
/// @dev For easy off-chain usage, this is equivalant to:
///     https://github.com/ethereumjs/ethereumjs-monorepo/blob/2e1826e4a14fda708857f7d3243c2b897e4a10fa/packages/evm/src/types.ts#L234
///     export type Log = [address: Buffer, topics: Buffer[], data: Buffer]
struct EventLog {
    address source;
    bytes32[] topics;
    bytes data;
}

interface ISubscriber {
    /// @notice Emitted when a new subscription is created.
    /// @param subscriptionId The unique identifier for the subscription.
    /// @param startBlock The block number to start listening for events, 0 for all blocks.
    /// @param endBlock The block number to stop listening for events, 0 for infinite.
    /// @param subscription The subscription details.
    /// @dev The startBlock and endBlock are inclusive.
    event Subscribe(
        bytes32 indexed subscriptionId,
        uint256 indexed startBlock,
        uint256 indexed endBlock,
        Subscription subscription
    );

    /// @notice Emitted when a subscription is cancelled.
    /// @param subscriptionId The unique identifier for the subscription.
    /// @param subscription The subscription details.
    event Unsubscribe(bytes32 indexed subscriptionId, Subscription subscription);

    function subscribe(
        uint32 sourceChainId,
        address sourceAddress,
        address callbackAddress,
        bytes32 eventSig,
        uint256 startBlock,
        uint256 endBlock
    ) external returns (bytes32 subscriptionId);

    function unsubscribe(uint32 sourceChainId, address sourceAddress, bytes32 eventSig) external;
}

enum PublishStatus {
    NOT_EXECUTED,
    EXECUTION_FAILED,
    EXECUTION_SUCCEEDED
}

interface IPublisher {
    /// @notice Emitted when an event is published for a given subscription.
    /// @param subscriptionId The unique identifier for the subscription.
    /// @param sourceChainId The chain ID of the source contract.
    /// @param sourceAddress The address of the source contract which emitted the target event.
    /// @param callbackAddress The address of the contract which received the event data.
    /// @param success True if the callbackAddress successfully recieved the publish, false otherwise.
    event Publish(
        bytes32 indexed subscriptionId,
        uint32 indexed sourceChainId,
        address indexed sourceAddress,
        address callbackAddress,
        bool success
    );

    function publishEvent(
        bytes calldata srcSlotTxSlotPack,
        bytes32[] calldata receiptsRootProof,
        bytes32 receiptsRoot,
        bytes[] calldata receiptProof,
        bytes memory txIndexRLPEncoded,
        uint256 logIndex,
        Subscription calldata subscription
    ) external;
}
