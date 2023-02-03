pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {NFTAirdrop} from "src/examples/nft/NFTAirdrop.sol";
import {MockTelepathy} from "telepathy/amb/mocks/MockAMB.sol";
import {TelepathyOracle, RequestData} from "src/oracle/TelepathyOracle.sol";
import {TelepathyOracleFulfiller} from "src/oracle/TelepathyOracleFulfiller.sol";
import {ENSUtil} from "src/examples/ens/ENSUtil.sol";
import {ENSQueryExample} from "src/examples/ens/ENSQueryExample.sol";

contract ENSQueryExampleTest is Test {
    MockTelepathy sourceAmb;
    MockTelepathy targetAmb;
    TelepathyOracleFulfiller fulfiller;
    TelepathyOracle oracle;
    ENSUtil ensUtil;
    ENSQueryExample query;

    uint16 ORACLE_CHAIN = 137;
    uint16 FULFILLER_CHAIN = 1;

    address USER = makeAddr("user");
    address USER2 = makeAddr("user2");

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 16550060);
        sourceAmb = new MockTelepathy(FULFILLER_CHAIN);
        targetAmb = new MockTelepathy(ORACLE_CHAIN);
        sourceAmb.addTelepathyReceiver(ORACLE_CHAIN, targetAmb);
        fulfiller = new TelepathyOracleFulfiller(address(sourceAmb));
        oracle = new TelepathyOracle(
            FULFILLER_CHAIN,
            address(targetAmb),
            address(fulfiller)
        );
        ensUtil = new ENSUtil(
            address(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e)
        );
        query = new ENSQueryExample(address(oracle), address(ensUtil));
    }

    function namehash(string memory _name) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    keccak256(
                        abi.encodePacked(
                            bytes32(
                                0x0000000000000000000000000000000000000000000000000000000000000000
                            ),
                            keccak256(abi.encodePacked("eth"))
                        )
                    ),
                    keccak256(abi.encodePacked(_name))
                )
            );
    }

    function testSimple() public {
        bytes32 node = namehash("vitalik");
        query.sendQuery(node);
        fulfiller.fulfillCrossChainRequest(
            ORACLE_CHAIN,
            address(oracle),
            RequestData(
                1,
                address(ensUtil),
                abi.encodeWithSelector(ENSUtil.resolve.selector, node),
                address(query)
            )
        );
        sourceAmb.executeNextMessage();
        (bool success, address addr, uint88 timestamp) = query.addresses(node);
        assertTrue(success);
        assertEq(addr, 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045);
        assertEq(timestamp, block.timestamp);
    }

    function testOffchainResolver() public {
        bytes32 node = namehash("offchainexample");
        query.sendQuery(node);
        fulfiller.fulfillCrossChainRequest(
            ORACLE_CHAIN,
            address(oracle),
            RequestData(
                1,
                address(ensUtil),
                abi.encodeWithSelector(ENSUtil.resolve.selector, node),
                address(query)
            )
        );
        sourceAmb.executeNextMessage();
        (bool success, , uint96 timestamp) = query.addresses(node);
        assertFalse(success);
        assertEq(timestamp, block.timestamp);
    }

    function testUnknownName() public {
        bytes32 node = namehash("lksjaflsefjasldifjaisljfli");
        query.sendQuery(node);
        fulfiller.fulfillCrossChainRequest(
            ORACLE_CHAIN,
            address(oracle),
            RequestData(
                1,
                address(ensUtil),
                abi.encodeWithSelector(ENSUtil.resolve.selector, node),
                address(query)
            )
        );
        sourceAmb.executeNextMessage();
        (bool success, , uint96 timestamp) = query.addresses(node);
        assertFalse(success);
        assertEq(timestamp, block.timestamp);
    }
}
