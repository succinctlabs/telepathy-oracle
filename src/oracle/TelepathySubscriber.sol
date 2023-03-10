pragma solidity ^0.8.16;

import {TelepathyHandler} from "telepathy-contracts/amb/interfaces/TelepathyHandler.sol";

enum SubscriptionStatus {
    UNSUBSCIBED,
    SUBSCRIBED
}

struct SubscriptionData {
    uint32 destinationChainId;
    address destinationAddress;
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
        uint32 _destinationChainId,
        address _destinationAddress,
        address _callbackAddress,
        bytes32 _eventSig
    ) external returns (bytes32 subscriptionId) {
        SubscriptionData memory subscriptionData =
            SubscriptionData(_destinationChainId, _destinationAddress, _callbackAddress, _eventSig);
        subscriptionId = keccak256(abi.encode(subscriptionData));

        if (subscriptions[subscriptionId] == SubscriptionStatus.SUBSCRIBED) {
            revert SubscriptionAlreadyActive(subscriptionId);
        }
        subscriptions[subscriptionId] = SubscriptionStatus.SUBSCRIBED;

        emit Subscribe(subscriptionId, subscriptionData);

        return subscriptionId;
    }

    /// @dev Only the original callbackAddress contract will be able to unsubscribe.
    function unsubscribe(uint32 _destinationChainId, address _destinationAddress, bytes32 _eventSig)
        external
        returns (bytes32)
    {
        SubscriptionData memory subscriptionData =
            SubscriptionData(_destinationChainId, _destinationAddress, msg.sender, _eventSig);
        bytes32 subscriptionId = keccak256(abi.encode(subscriptionData));

        if (subscriptions[subscriptionId] == SubscriptionStatus.UNSUBSCIBED) {
            revert SubscriptionNotActive(subscriptionId);
        }
        subscriptions[subscriptionId] = SubscriptionStatus.UNSUBSCIBED;

        emit Unsubscribe(subscriptionId, subscriptionData);
    }
}

/// @notice This contract is used to subscribe to a cross-chain events from a destination contract.
contract TestEventSubsciber is TelepathyHandler {
    event CrossChainIncremented(uint256 value, address sender);

    error InvalidDestinationChain(uint32 destinationChainId);
    error InvalidDestinationAddress(address destinationAddress);
    error InvalidSubscriptionId(bytes32 subscriptionId);
    error InvalidEventSig(bytes32 eventSig);

    TelepathySubsciber immutable telepathySubsciber;
    uint32 immutable EVENT_DESTINATION_CHAIN_ID;
    address immutable EVENT_DESTINATION_ADDRESS;
    bytes32 immutable EVENT_SIG; // e.g. keccak256("Incremented(uint256,address)");

    bytes32 subscriptionId;

    constructor(
        address _telepathySubsciber,
        address _telepathyRouter,
        uint32 _destinationChainId,
        address _destinationAddress,
        bytes32 _eventSig
    ) TelepathyHandler(_telepathyRouter) {
        telepathySubsciber = TelepathySubsciber(_telepathySubsciber);
        EVENT_DESTINATION_CHAIN_ID = _destinationChainId;
        EVENT_DESTINATION_ADDRESS = _destinationAddress;
        EVENT_SIG = _eventSig;
    }

    function subscribeToEvent(uint32 _destinationChainId, address _destinationAddress) external {
        bytes32 subscribeId = telepathySubsciber.subscribe(
            _destinationChainId, _destinationAddress, address(this), EVENT_SIG
        );
        subscriptionId = subscribeId;
    }

    function unsubscribeFromEvent(uint32 _destinationChainId, address _destinationAddress)
        external
    {
        telepathySubsciber.unsubscribe(_destinationChainId, _destinationAddress, EVENT_SIG);
    }

    function handleTelepathyImpl(
        uint32 _destinationChain,
        address _destinationAddress,
        bytes memory _data
    ) internal override {
        if (_destinationChain != EVENT_DESTINATION_CHAIN_ID) {
            revert InvalidDestinationChain(_destinationChain);
        }

        if (_destinationAddress != EVENT_DESTINATION_ADDRESS) {
            revert InvalidDestinationAddress(_destinationAddress);
        }

        (bytes32 subId, bytes32 eventSig, bytes memory eventData) =
            abi.decode(_data, (bytes32, bytes32, bytes));

        if (subId != subscriptionId) {
            revert InvalidSubscriptionId(subId);
        }
        if (eventSig != EVENT_SIG) {
            revert InvalidEventSig(eventSig);
        }

        (uint256 value, address incrementer) = abi.decode(eventData, (uint256, address));

        emit CrossChainIncremented(value, incrementer);
    }
}
