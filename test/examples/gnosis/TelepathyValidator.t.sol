pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {MockTelepathy} from "telepathy-contracts/amb/mocks/MockTelepathy.sol";
import {TelepathyPubSub, SubscriptionStatus, Subscription} from "src/pubsub/TelepathyPubSub.sol";
import {TelepathyHandler} from "telepathy-contracts/amb/interfaces/TelepathyHandler.sol";
import {TelepathyValidator} from "src/examples/gnosis/TelepathyValidator.sol";

import {BasicHomeAMB} from "tokenbridge/upgradeable_contracts/arbitrary_message/BasicHomeAMB.sol";
import {ForeignAMB} from "tokenbridge/upgradeable_contracts/arbitrary_message/ForeignAMB.sol";

contract TelepathyValidator is Test {
    event Subscribe(
        bytes32 indexed subscriptionId,
        uint64 indexed startSlot,
        uint64 indexed endSlot,
        Subscription subscription
    );

    MockTelepathy mockTelepathy;
    TelepathyPubSub telepathyPubSub;
    BasicHomeAMB basicHomeAMB;
    ForeignAMB foreignAMB;
    TelepathyValidator telepathyValidator;

    uint32 DESTINATION_CHAIN = 100;
    uint32 SOURCE_CHAIN = 1;
    bytes32 EVENT_SIG = keccak256("UserRequestForAffirmation(bytes32,bytes)");

    function setUp() public {
        mockTelepathy = new MockTelepathy(DESTINATION_CHAIN);
        telepathyPubSub = new TelepathyPubSub(mockTelepathy);

        basicHomeAMB = new BasicHomeAMB();
        foreignAMB = new ForeignAMB();

        telepathyValidator = new TelepathyValidator(
            telepathyPubSub,
            basicHomeAMB,
            SOURCE_CHAIN,
            foreignAMB,
            0,
            0
        );
    }

    function test_SubscribeToAffirmation() public {
        vm.expectEmit(true, true, true, true);
        emit Subscribe(
            keccak256(
                abi.encode(
                    Subscription(
                        SOURCE_CHAIN, SOURCE_ADDRESS, address(telepathyValidator), EVENT_SIG
                    )
                )
            ),
            uint64(0),
            uint64(0),
            Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, address(telepathyValidator), EVENT_SIG)
        );
        telepathyValidator.subscribeToAffirmation();
    }
}
