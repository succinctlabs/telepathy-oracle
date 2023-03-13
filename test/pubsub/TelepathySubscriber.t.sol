pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {MockTelepathy} from "telepathy-contracts/amb/mocks/MockTelepathy.sol";
import {
    TelepathySubscriber,
    SubscriptionStatus,
    Subscription
} from "src/pubsub/TelepathySubscriber.sol";
import {TelepathyHandler} from "telepathy-contracts/amb/interfaces/TelepathyHandler.sol";

contract TelepathySubscriberTest is Test {
    event Subscribe(bytes32 indexed subscriptionId, Subscription Subscription);
    event Unsubscribe(bytes32 indexed subscriptionId, Subscription Subscription);

    MockTelepathy mockTelepathy;
    TelepathySubscriber telepathySubscriber;

    uint32 DESTINATION_CHAIN = 137;
    uint32 SOURCE_CHAIN = 1;
    address SOURCE_ADDRESS = makeAddr("Counter");
    address CALLBACK_ADDRESS = makeAddr("CounterSubscriber");
    bytes32 EVENT_SIG = keccak256("Incremented(uint256,address)");

    function setUp() public {
        mockTelepathy = new MockTelepathy(DESTINATION_CHAIN);
        telepathySubscriber = new TelepathySubscriber();
    }

    function testSubscribe() public {
        vm.expectEmit(true, true, true, true);
        emit Subscribe(
            keccak256(
                abi.encode(Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG))
            ),
            Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG)
        );
        bytes32 subscriptionId =
            telepathySubscriber.subscribe(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG);
        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.SUBSCRIBED
        );
    }

    function testSubscribeTwice() public {
        vm.expectEmit(true, true, true, true);
        emit Subscribe(
            keccak256(
                abi.encode(Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG))
            ),
            Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG)
        );
        bytes32 subscriptionId =
            telepathySubscriber.subscribe(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG);
        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.SUBSCRIBED
        );

        vm.expectRevert(
            abi.encodeWithSignature("SubscriptionAlreadyActive(bytes32)", subscriptionId)
        );
        telepathySubscriber.subscribe(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG);

        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.SUBSCRIBED
        );
    }

    function testUnsubscribe() public {
        vm.expectEmit(true, true, true, true);
        emit Subscribe(
            keccak256(
                abi.encode(Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG))
            ),
            Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG)
        );
        bytes32 subscriptionId =
            telepathySubscriber.subscribe(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG);
        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.SUBSCRIBED
        );

        vm.expectEmit(true, true, true, true);
        emit Unsubscribe(
            keccak256(
                abi.encode(Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG))
            ),
            Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG)
        );
        vm.prank(CALLBACK_ADDRESS);
        telepathySubscriber.unsubscribe(SOURCE_CHAIN, SOURCE_ADDRESS, EVENT_SIG);
        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.UNSUBSCIBED
        );
    }

    function testUnsubscribeTwice() public {
        vm.expectEmit(true, true, true, true);
        emit Subscribe(
            keccak256(
                abi.encode(Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG))
            ),
            Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG)
        );
        bytes32 subscriptionId =
            telepathySubscriber.subscribe(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG);
        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.SUBSCRIBED
        );

        vm.expectEmit(true, true, true, true);
        emit Unsubscribe(
            keccak256(
                abi.encode(Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG))
            ),
            Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG)
        );
        vm.prank(CALLBACK_ADDRESS);
        telepathySubscriber.unsubscribe(SOURCE_CHAIN, SOURCE_ADDRESS, EVENT_SIG);
        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.UNSUBSCIBED
        );

        vm.expectRevert(abi.encodeWithSignature("SubscriptionNotActive(bytes32)", subscriptionId));
        vm.prank(CALLBACK_ADDRESS);
        telepathySubscriber.unsubscribe(SOURCE_CHAIN, SOURCE_ADDRESS, EVENT_SIG);

        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.UNSUBSCIBED
        );
    }

    function testUnsubscribeFromWrongAddress() public {
        vm.expectEmit(true, true, true, true);
        emit Subscribe(
            keccak256(
                abi.encode(Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG))
            ),
            Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG)
        );
        bytes32 subscriptionId =
            telepathySubscriber.subscribe(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG);
        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.SUBSCRIBED
        );

        bytes32 mismatchSubscriptionId =
            keccak256(abi.encode(Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, msg.sender, EVENT_SIG)));
        vm.prank(msg.sender);
        vm.expectRevert(
            abi.encodeWithSignature("SubscriptionNotActive(bytes32)", mismatchSubscriptionId)
        );
        telepathySubscriber.unsubscribe(SOURCE_CHAIN, SOURCE_ADDRESS, EVENT_SIG);
        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.SUBSCRIBED
        );
    }
}
