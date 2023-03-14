pragma solidity ^0.8.16;

import {ISubscriber, Subscription, EventLog} from "src/pubsub/interfaces/IPubSub.sol";

import {ISubscriptionCallbackReceiver} from
    "src/pubsub/interfaces/ISubscriptionCallbackReceiver.sol";

/// @notice Example counter deployed on the source chain to listen to.
/// @dev Importantly, this contract does not need any special logic to handle it's events being subscribed to.
contract Counter {
    uint256 public counter = 0;

    event Incremented(uint256 indexed count, address sender);

    function increment() external {
        counter += 1;
        emit Incremented(counter, msg.sender);
    }
}

/// @notice This contract is used to subscribe to a cross-chain events from a source counter.
contract CounterSubscriber is ISubscriptionCallbackReceiver {
    event CrossChainIncremented(uint256 value, address sender);

    error InvalidSourceChain(uint32 sourceChainId);
    error InvalidSourceAddress(address sourceAddress);
    error InvalidSubscriptionId(bytes32 subscriptionId);
    error InvalidEventSig(bytes32 eventSig);

    ISubscriber immutable telepathySubscriber;
    uint32 immutable EVENT_SOURCE_CHAIN_ID;
    address immutable EVENT_SOURCE_ADDRESS;
    bytes32 immutable EVENT_SIG = keccak256("Incremented(uint256,address)");

    bytes32 subscriptionId;

    // function handlePublish(
    //     bytes32 subscriptionId,
    //     uint32 sourceChainId,
    //     address sourceAddress,
    //     EventLog memory log
    // ) external;

    constructor(address _telepathySubscriber, uint32 _sourceChainId, address _sourceAddress) {
        telepathySubscriber = ISubscriber(_telepathySubscriber);
        EVENT_SOURCE_CHAIN_ID = _sourceChainId;
        EVENT_SOURCE_ADDRESS = _sourceAddress;
    }

    function subscribeToEvent(uint32 _sourceChainId, address _sourceAddress) external {
        subscriptionId = telepathySubscriber.subscribe(
            _sourceChainId, _sourceAddress, address(this), EVENT_SIG, 0, 0
        );
    }

    function unsubscribeFromEvent(uint32 _sourceChainId, address _sourceAddress) external {
        telepathySubscriber.unsubscribe(_sourceChainId, _sourceAddress, EVENT_SIG);
    }

    function handlePublish(
        bytes32 _subscriptionId,
        uint32 _sourceChainId,
        address _sourceAddress,
        EventLog memory _eventlog
    ) external {
        if (_sourceChainId != EVENT_SOURCE_CHAIN_ID) {
            revert InvalidSourceChain(_sourceChainId);
        }

        if (_sourceAddress != EVENT_SOURCE_ADDRESS) {
            revert InvalidSourceAddress(_sourceAddress);
        }

        if (_subscriptionId != subscriptionId) {
            revert InvalidSubscriptionId(_subscriptionId);
        }

        emit CrossChainIncremented(uint256(_eventlog.topics[1]), _eventlog.source);
    }
}
