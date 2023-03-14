pragma solidity ^0.8.16;

import {EventLog} from "src/pubsub/interfaces/IPubSub.sol";

interface ISubscriptionCallbackReceiver {
    function handlePublish(
        bytes32 sub,
        uint32 sourceChainId,
        address sourceAddress,
        EventLog memory log
    ) external;
}
