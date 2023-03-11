pragma solidity ^0.8.16;

import {TelepathyOracle} from "src/oracle/TelepathyOracle.sol";
import {TelepathySubscriber, SubscriptionStatus, SubscriptionData} from "src/pubsub/TelepathySubscriber.sol";
import {TelepathyHandler} from "telepathy-contracts/amb/interfaces/TelepathyHandler.sol";

/// @notice This contract is used to subscribe to a cross-chain events from a source contract.
contract CounterSubsciber is TelepathyHandler {
    event CrossChainIncremented(uint256 value, address sender);

    error InvalidSourceChain(uint32 sourceChainId);
    error InvalidSourceAddress(address sourceAddress);
    error InvalidSubscriptionId(bytes32 subscriptionId);
    error InvalidEventSig(bytes32 eventSig);

    TelepathySubsciber immutable telepathySubsciber;
    uint32 immutable EVENT_SOURCE_CHAIN_ID;
    address immutable EVENT_SOURCE_ADDRESS;
    bytes32 immutable EVENT_SIG = keccak256("Incremented(uint256,address)");

    bytes32 subscriptionId;

    constructor(
        address _telepathySubsciber,
        address _telepathyRouter,
        uint32 _sourceChainId,
        address _sourceAddress
    ) TelepathyHandler(_telepathyRouter) {
        telepathySubsciber = TelepathySubsciber(_telepathySubsciber);
        EVENT_SOURCE_CHAIN_ID = _sourceChainId;
        EVENT_SOURCE_ADDRESS = _sourceAddress;
    }

    function subscribeToEvent(uint32 _sourceChainId, address _sourceAddress) external {
        subscriptionId = telepathySubsciber.subscribe(_sourceChainId, _sourceAddress, address(this), EVENT_SIG);
    }

    function unsubscribeFromEvent(uint32 _sourceChainId, address _sourceAddress) external {
        telepathySubsciber.unsubscribe(_sourceChainId, _sourceAddress, EVENT_SIG);
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