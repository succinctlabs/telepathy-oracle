// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Fulfill.sol";
import "../src/Request.sol";
import "./testHelpers/SourceAMB.sol";
import "./testHelpers/Dummy.sol";
import "./testHelpers/LightClientMock.sol";
import "./testHelpers/Proofs.sol";

import "./testHelpers/MockENS.sol";
import "../src/ens/ENSFulfiller.sol";
import "../src/ens/ENSReceiver.sol";

contract ENSTest is Test {
    uint256 GAS_LIMIT = 100_000;
    uint256 targetChainId = block.chainid;
    SourceAMB public sourceAMB;

    TelepathyOracleRequest public requester;
    TelepathyOracleFulfill public fulfiller;

    MockENSRegistry public ensRegistry;
    MockENSResolver public ensResolver;

    ENSFulfiller public ensFulfiller;
    ENSReceiver public ensReceiver;

    LightClientMock lightClient;

    function setUp() public {
        lightClient = new LightClientMock();
        sourceAMB = new SourceAMB();
        fulfiller = new TelepathyOracleFulfill(address(sourceAMB));
        requester = new TelepathyOracleRequest(address(fulfiller), address(lightClient));

        ensRegistry = new MockENSRegistry();
        ensResolver = new MockENSResolver();

        ensFulfiller = new ENSFulfiller(address(ensRegistry));
        ensReceiver = new ENSReceiver();
    }

    function testGetENSOwner() public {
        // namehash succinctlabs.eth and add to mock registry
        bytes32 node = 0x6f2c0d613ec8485350d2d21565058141c30504e9d138b4f1a79ef9e3cd466437;
        ensRegistry.setResolver(node, address(ensResolver));
        ensResolver.setAddr(node, address(0x1234));

        // request view
        bytes memory data = ensReceiver.requestENS(
            address(requester),
            address(ensFulfiller),
            ensFulfiller.getENSOwner.selector,
            node,
            GAS_LIMIT
        );

        // calculate messageroot
        bytes32 messageRoot = fulfiller.fulfillRequest(address(ensFulfiller), data);

        // calculate return data
        bytes memory callData = abi.encode(
            requester.viewNonce(), targetChainId, abi.encode(ensFulfiller.getENSOwner(node))
        );

        // assert correct return message
        assertTrue(
            messageRoot
                == keccak256(
                    abi.encode(
                        sourceAMB.nonce() - 1,
                        address(fulfiller),
                        address(requester),
                        targetChainId,
                        GAS_LIMIT,
                        callData
                    )
                )
        );

        // enact message
        requester.receiveSuccinct(address(fulfiller), callData);

        // assert correct return data
        assertTrue(ensReceiver.owner() == ensFulfiller.getENSOwner(node));
    }
}
