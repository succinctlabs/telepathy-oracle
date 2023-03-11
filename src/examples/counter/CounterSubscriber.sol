pragma solidity ^0.8.16;

import {
    TelepathySubscriber,
    SubscriptionStatus,
    SubscriptionData
} from "src/pubsub/TelepathySubscriber.sol";
import {TelepathyHandler} from "telepathy-contracts/amb/interfaces/TelepathyHandler.sol";

/// @notice Example counter deployed on the source chain to listen to.
contract Counter {
    uint256 public counter = 0;

    event Incremented(uint256 count, address sender);

    function increment() external {
        counter += 1;
        emit Incremented(counter, msg.sender);
    }
}

/// @notice This contract is used to subscribe to a cross-chain events from a source counter.
contract CounterSubscriber is TelepathyHandler {
    event CrossChainIncremented(uint256 value, address sender);

    error InvalidSourceChain(uint32 sourceChainId);
    error InvalidSourceAddress(address sourceAddress);
    error InvalidSubscriptionId(bytes32 subscriptionId);
    error InvalidEventSig(bytes32 eventSig);

    TelepathySubscriber immutable telepathySubscriber;
    uint32 immutable EVENT_SOURCE_CHAIN_ID;
    address immutable EVENT_SOURCE_ADDRESS;
    bytes32 immutable EVENT_SIG = keccak256("Incremented(uint256,address)");

    bytes32 subscriptionId;

    constructor(
        address _telepathySubscriber,
        address _telepathyRouter,
        uint32 _sourceChainId,
        address _sourceAddress
    ) TelepathyHandler(_telepathyRouter) {
        telepathySubscriber = TelepathySubscriber(_telepathySubscriber);
        EVENT_SOURCE_CHAIN_ID = _sourceChainId;
        EVENT_SOURCE_ADDRESS = _sourceAddress;
    }

    function subscribeToEvent(uint32 _sourceChainId, address _sourceAddress) external {
        subscriptionId =
            telepathySubscriber.subscribe(_sourceChainId, _sourceAddress, address(this), EVENT_SIG);
    }

    function unsubscribeFromEvent(uint32 _sourceChainId, address _sourceAddress) external {
        telepathySubscriber.unsubscribe(_sourceChainId, _sourceAddress, EVENT_SIG);
    }

    function handleTelepathyImpl(uint32 _sourceChain, address _sourceAddress, bytes memory _data)
        internal
        override
    {
        if (_sourceChain != EVENT_SOURCE_CHAIN_ID) {
            revert InvalidSourceChain(_sourceChain);
        }

        if (_sourceAddress != EVENT_SOURCE_ADDRESS) {
            revert InvalidSourceAddress(_sourceAddress);
        }

        (bytes32 subId, bytes memory eventData) = abi.decode(_data, (bytes32, bytes));

        if (subId != subscriptionId) {
            revert InvalidSubscriptionId(subId);
        }

        (uint256 value, address incrementer) = abi.decode(eventData, (uint256, address));

        emit CrossChainIncremented(value, incrementer);
    }
}
