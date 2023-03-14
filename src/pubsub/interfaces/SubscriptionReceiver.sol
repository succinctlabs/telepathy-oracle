pragma solidity ^0.8.16;

import {ISubscriptionReceiver} from "src/pubsub/interfaces/ISubscriptionReceiver.sol";

abstract contract SubscriptionReceiver is ISubscriptionReceiver {
    error NotFromTelepathyPubSub(address sender);

    address private _telepathyPubSub;

    constructor(address telepathyPubSub) {
        _telepathyPubSub = telepathyPubSub;
    }

    function handlePublish(
        bytes32 _subscriptionId,
        uint32 _sourceChainId,
        address _sourceAddress,
        bytes32[] memory _eventTopics,
        bytes memory _eventdata
    ) external
        override
        returns (bytes4)
    {
        if (msg.sender != _telepathyPubSub) {
            revert NotFromTelepathyPubSub(msg.sender);
        }
        handlePublishImpl(_subscriptionId, _sourceChainId, _sourceAddress, _eventTopics, _eventdata);
        return ISubscriptionReceiver.handlePublish.selector;
    }

    function handlePublishImpl(bytes32 _subscriptionId, uint32 _sourceChainId, address _sourceAddress, bytes32[] memory _eventTopics, bytes memory _eventdata)
        internal
        virtual;
}
