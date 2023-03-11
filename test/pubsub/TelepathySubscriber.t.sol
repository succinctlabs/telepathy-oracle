pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {MockTelepathy} from "telepathy-contracts/amb/mocks/MockTelepathy.sol";
import {TelepathySubscriber, SubscriptionStatus, SubscriptionData} from "src/pubsub/TelepathySubscriber.sol";
import {TelepathyHandler} from "telepathy-contracts/amb/interfaces/TelepathyHandler.sol";

// contract TelepathySubsciber {
//     event Subscribe(bytes32 indexed subscriptionId, SubscriptionData subscriptionData);
//     event Unsubscribe(bytes32 indexed subscriptionId, SubscriptionData subscriptionData);

//     error SubscriptionAlreadyActive(bytes32 subscriptionId);
//     error SubscriptionNotActive(bytes32 subscriptionId);

//     mapping(bytes32 => SubscriptionStatus) public subscriptions;

//     function subscribe(
//         uint32 _sourceChainId,
//         address _sourceAddress,
//         address _callbackAddress,
//         bytes32 _eventSig
//     ) external returns (bytes32 subscriptionId) {
//         SubscriptionData memory subscriptionData =
//             SubscriptionData(_sourceChainId, _sourceAddress, _callbackAddress, _eventSig);
//         subscriptionId = keccak256(abi.encode(subscriptionData));

//         if (subscriptions[subscriptionId] == SubscriptionStatus.SUBSCRIBED) {
//             revert SubscriptionAlreadyActive(subscriptionId);
//         }
//         subscriptions[subscriptionId] = SubscriptionStatus.SUBSCRIBED;

//         emit Subscribe(subscriptionId, subscriptionData);

//         return subscriptionId;
//     }

//     /// @dev Only the original callbackAddress contract will be able to unsubscribe.
//     function unsubscribe(uint32 _sourceChainId, address _sourceAddress, bytes32 _eventSig)
//         external
//     {
//         SubscriptionData memory subscriptionData =
//             SubscriptionData(_sourceChainId, _sourceAddress, msg.sender, _eventSig);
//         bytes32 subscriptionId = keccak256(abi.encode(subscriptionData));

//         if (subscriptions[subscriptionId] == SubscriptionStatus.UNSUBSCIBED) {
//             revert SubscriptionNotActive(subscriptionId);
//         }
//         subscriptions[subscriptionId] = SubscriptionStatus.UNSUBSCIBED;

//         emit Unsubscribe(subscriptionId, subscriptionData);
//     }
// }

contract TelepathySubscriberTest is Test {
    MockTelepathy mockTelepathy;
    TelepathySubscriber telepathySubscriber;

    function setUp() public {
        mockTelepathy = new MockTelepathy();
        telepathySubscriber = new TelepathySubscriber();
    }

    function testSubscribe() public {
        uint32 sourceChainId = 1;
        address sourceAddress = address(0x123);
        address callbackAddress = address(0x456);
        bytes32 eventSig = keccak256("Incremented(uint256,address)");

        bytes32 subscriptionId =
            telepathySubscriber.subscribe(
                sourceChainId,
                sourceAddress,
                callbackAddress,
                eventSig
            );

        assertEq(
            telepathySubscriber.subscriptions(subscriptionId),
            SubscriptionStatus.SUBSCRIBED
        );
    }
}