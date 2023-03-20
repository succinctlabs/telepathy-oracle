pragma solidity ^0.8.16;

import {TelepathyPubSub} from "src/pubsub/TelepathyPubSub.sol";
import {SubscriptionReceiver} from "src/pubsub/interfaces/SubscriptionReceiver.sol";

import {BasicHomeAMB} from
    "tokenbridge-contracts/contracts/upgradeable_contracts/arbitrary_message/BasicHomeAMB.sol";
import {ArbitraryMessage} from "tokenbridge-contracts/contracts/libraries/ArbitraryMessage.sol";

contract TelepathyValidator is SubscriptionReceiver {
    error InvalidSourceChain(uint32 sourceChainId);
    error InvalidSourceAddress(address sourceAddress);
    error InvalidSlot(uint64 slot);
    error InvalidSubscriptionId(bytes32 subscriptionId);
    error InvalidEventSig(bytes32 eventSig);

    // event UserRequestForAffirmation(bytes32 indexed messageId, bytes encodedData);
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

        if (eventTopics[0] != AFFIRMATION_EVENT_SIG) {
            revert InvalidEventSig(eventTopics[0]);
        }

        (, bytes memory data) = abi.decode(eventdata, (bytes, bytes));
        BasicHomeAMB.executeAffirmation(message);
    }
}
