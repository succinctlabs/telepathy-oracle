pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {MockTelepathy} from "telepathy-contracts/amb/mocks/MockTelepathy.sol";
import {
    TelepathySubscriber,
    SubscriptionStatus,
    SubscriptionData
} from "src/pubsub/TelepathySubscriber.sol";
import {TelepathyHandler} from "telepathy-contracts/amb/interfaces/TelepathyHandler.sol";

import {RLPReader} from "optimism-bedrock-contracts/rlp/RLPReader.sol";
import {RLPWriter} from "optimism-bedrock-contracts/rlp/RLPWriter.sol";
import {MerkleTrie} from "optimism-bedrock-contracts/trie/MerkleTrie.sol";

import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

import {Log, EventProof} from "src/pubsub/EventProofHelper.sol";
import {EventProofFixture} from "test/pubsub/EventProofFixture.sol";

contract EventProofHelperTest is Test, EventProofFixture {
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;

    uint256 constant FIXTURE_START = 22;
    uint256 constant FIXTURE_END = 22;

    Fixture[] fixtures;

    function setUp() public {
        // read all event proof fixtures
        for (uint256 i = FIXTURE_START; i <= FIXTURE_END; i++) {
            uint256 msgNonce = i;

            string memory filename = string.concat("eventProof", Strings.toString(msgNonce));
            console.log("/test/pubsub/fixtures/", filename, ".json");
            string memory path =
                string.concat(vm.projectRoot(), "/test/pubsub/fixtures/", filename, ".json");
            try vm.readFile(path) returns (string memory file) {
                bytes memory parsed = vm.parseJson(file);
                fixtures.push(abi.decode(parsed, (Fixture)));
            } catch {
                console.log("fixture not found: %s", path);
                continue;
            }

            console.log("loaded fixture: %s", filename);
        }
    }

    function test_SetUp() public view {
        require(fixtures.length > 0, "no fixtures found");
    }

    function test_VerifyEvent() public view {
        for (uint256 i = 0; i < fixtures.length; i++) {
            Fixture memory fixture = fixtures[i];

            bytes[] memory proof = buildEventProof(fixture);

            Log memory log = Log(fixture.logSource, fixture.logTopics, fixture.logData);

            EventProof.verifyEvent(
                proof, fixture.receiptsRoot, vm.parseBytes(fixture.key), fixture.logIndex, log
            );
        }
    }

    function test_VerifyEvent_WhenLogSourceInvalid() public {
        for (uint256 i = 0; i < fixtures.length; i++) {
            Fixture memory fixture = fixtures[i];

            bytes[] memory proof = buildEventProof(fixture);

            Log memory log = Log(address(0), fixture.logTopics, fixture.logData);
            vm.expectRevert();
            EventProof.verifyEvent(
                proof, fixture.receiptsRoot, vm.parseBytes(fixture.key), fixture.logIndex, log
            );
        }
    }
}
