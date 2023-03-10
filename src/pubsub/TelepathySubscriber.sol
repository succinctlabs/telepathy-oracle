pragma solidity ^0.8.16;

import {TelepathyHandler} from "telepathy-contracts/amb/interfaces/TelepathyHandler.sol";

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

contract TelepathySubsciber {
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
        returns (bytes32)
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

/// @notice This contract is used to subscribe to a cross-chain events from a source contract.
contract TestEventSubsciber is TelepathyHandler {
    event CrossChainIncremented(uint256 value, address sender);

    error InvalidSourceChain(uint32 sourceChainId);
    error InvalidSourceAddress(address sourceAddress);
    error InvalidSubscriptionId(bytes32 subscriptionId);
    error InvalidEventSig(bytes32 eventSig);

    TelepathySubsciber immutable telepathySubsciber;
    uint32 immutable EVENT_SOURCE_CHAIN_ID;
    address immutable EVENT_SOURCE_ADDRESS;
    bytes32 immutable EVENT_SIG; // e.g. keccak256("Incremented(uint256,address)");

    bytes32 subscriptionId;

    constructor(
        address _telepathySubsciber,
        address _telepathyRouter,
        uint32 _sourceChainId,
        address _sourceAddress,
        bytes32 _eventSig
    ) TelepathyHandler(_telepathyRouter) {
        telepathySubsciber = TelepathySubsciber(_telepathySubsciber);
        EVENT_SOURCE_CHAIN_ID = _sourceChainId;
        EVENT_SOURCE_ADDRESS = _sourceAddress;
        EVENT_SIG = _eventSig;
    }

    function subscribeToEvent(uint32 _sourceChainId, address _sourceAddress) external {
        bytes32 subscribeId = telepathySubsciber.subscribe(
            _sourceChainId, _sourceAddress, address(this), EVENT_SIG
        );
        subscriptionId = subscribeId;
    }

    function unsubscribeFromEvent(uint32 _sourceChainId, address _sourceAddress)
        external
    {
        telepathySubsciber.unsubscribe(_sourceChainId, _sourceAddress, EVENT_SIG);
    }

    function handleTelepathyImpl(
        uint32 _sourceChain,
        address _sourceAddress,
        bytes memory _data
    ) internal override {
        if (_sourceChain != EVENT_SOURCE_CHAIN_ID) {
            revert InvalidSourceChain(_sourceChain);
        }

        if (_sourceAddress != EVENT_SOURCE_ADDRESS) {
            revert InvalidSourceAddress(_sourceAddress);
        }

        (bytes32 subId, bytes memory eventData) =
            abi.decode(_data, (bytes32, bytes));

        if (subId != subscriptionId) {
            revert InvalidSubscriptionId(subId);
        }

        (uint256 value, address incrementer) = abi.decode(eventData, (uint256, address));

        emit CrossChainIncremented(value, incrementer);
    }
}
