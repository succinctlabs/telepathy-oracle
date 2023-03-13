pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {MockTelepathy} from "telepathy-contracts/amb/mocks/MockTelepathy.sol";
import {
    TelepathySubscriber,
    SubscriptionStatus,
    SubscriptionData
} from "src/pubsub/TelepathySubscriber.sol";
import {TelepathyPublisher} from "src/pubsub/TelepathyPublisher.sol";
import {TelepathyHandler} from "telepathy-contracts/amb/interfaces/TelepathyHandler.sol";

// contract MockSubscriber is TelepathyHandler {
//     uint256 public recievedCount;

//     function handleTelepathyImpl(uint32 _sourceChain, address _sourceAddress, bytes memory _data)
//         internal
//         override
//     {
//         recievedCount++;
//     }
// }

contract TelepathyPublisherTest is Test {
    MockTelepathy mockTelepathy;
    // MockSubscriber mockSubscriber;

    function setUp() public {
        mockTelepathy = new MockTelepathy(1);
        // mockSubscriber = new MockSubscriber();
    }

    function test() public {
        // TODO after implementation is finalized
    }

    // TODO after implementation is finalized
}
