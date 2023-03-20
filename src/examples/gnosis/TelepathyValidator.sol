pragma solidity ^0.8.16;

import {TelepathyPubSub} from "src/pubsub/TelepathyPubSub.sol";
import {SubscriptionReceiver} from "src/pubsub/interfaces/SubscriptionReceiver.sol";

import {BasicHomeAMB} from "tokenbridge/upgradeable_contracts/arbitrary_message/BasicHomeAMB.sol";
import {ArbitraryMessage} from "tokenbridge/libraries/ArbitraryMessage.sol";

contract TelepathyValidator is SubscriptionReceiver {
    error InvalidSourceChain(uint32 sourceChainId);
    error InvalidSourceAddress(address sourceAddress);
    error InvalidSlot(uint64 slot);
    error InvalidSubscriptionId(bytes32 subscriptionId);

    /// @dev Listen for event UserRequestForAffirmation(bytes32 indexed messageId, bytes encodedData)
    ///      where the encodedData is the ABI encoded message from the Foreign AMB.
    bytes32 constant AFFIRMATION_EVENT_SIG = keccak256("UserRequestForAffirmation(bytes32,bytes)");

    uint32 immutable EVENT_SOURCE_CHAIN_ID;
    address immutable EVENT_SOURCE_ADDRESS;
    uint64 immutable START_SLOT;
    uint64 immutable END_SLOT;
    address immutable HOME_AMB;

    bytes32 public subscriptionId;

    constructor(
        address _telepathyPubSub,
        address _homeAMB,
        uint32 _sourceChainId,
        address _sourceAddress,
        uint64 _startSlot,
        uint64 _endSlot
    ) SubscriptionReceiver(_telepathyPubSub) {
        HOME_AMB = _homeAMB;
        EVENT_SOURCE_CHAIN_ID = _sourceChainId;
        EVENT_SOURCE_ADDRESS = _sourceAddress;
        START_SLOT = _startSlot;
        END_SLOT = _endSlot;
    }

    function subscribeToAffirmationEvent() external {
        subscriptionId = telepathyPubSub.subscribe(
            EVENT_SOURCE_CHAIN_ID,
            EVENT_SOURCE_ADDRESS,
            address(this),
            INCREMENT_EVENT_SIG,
            START_SLOT,
            END_SLOT
        );
    }

    /// @notice Handle the published affirmation event by executing the affirmation in the Home AMB.
    /// @dev We decode 'abi.encodePacked(header, _data)' to extract just the encoded message '_data' from the event.
    function handlePublishImpl(
        bytes32 _subscriptionId,
        uint32 _sourceChainId,
        address _sourceAddress,
        uint64 _slot,
        bytes32[] memory eventTopics,
        bytes memory eventdata
    ) internal override {
        if (_sourceChainId != EVENT_SOURCE_CHAIN_ID) {
            revert InvalidSourceChain(_sourceChainId);
        }

        if (_sourceAddress != EVENT_SOURCE_ADDRESS) {
            revert InvalidSourceAddress(_sourceAddress);
        }

        if (_slot < START_SLOT || _slot > END_SLOT) {
            revert InvalidSlot(_slot);
        }

        if (_subscriptionId != subscriptionId) {
            revert InvalidSubscriptionId(_subscriptionId);
        }

        (, bytes memory data) = abi.decode(eventdata, (bytes, bytes));
        BasicHomeAMB.executeAffirmation(data);
    }
}
