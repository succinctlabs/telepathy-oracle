// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Fulfill.sol";
import "../src/Request.sol";
import {SourceAMB} from "telepathy/amb/SourceAMB.sol";
import "./testHelpers/Dummy.sol";
import "telepathy-test/amb/LightClientMock.sol";
import "./testHelpers/Proofs.sol";

contract OracleTest is Test {
    uint256 GAS_LIMIT = 100_000;
    uint256 targetChainId = block.chainid;
    SourceAMB public sourceAMB;

    TelepathyOracleRequest public requester;
    TelepathyOracleFulfill public fulfiller;

    DummyCallback public callbackContract;
    DummyView public viewContract;

    LightClientMock lightClient;

    function setUp() public {
        lightClient = new LightClientMock();
        sourceAMB = new SourceAMB();
        fulfiller = new TelepathyOracleFulfill(address(sourceAMB));
        requester = new TelepathyOracleRequest(address(fulfiller), address(lightClient));

        callbackContract = new DummyCallback();
        viewContract = new DummyView();
    }

    function testRequestView() public {
        // request view
        bytes memory data = requester.requestView(
            address(callbackContract),
            callbackContract.addToSum.selector,
            address(viewContract),
            viewContract.getNumber.selector,
            "",
            GAS_LIMIT
        );

        // calculate messageroot
        bytes32 messageRoot = fulfiller.fulfillRequest(address(viewContract), data);

        // calculate return data
        bytes memory callData =
            abi.encode(requester.viewNonce(), targetChainId, abi.encode(viewContract.getNumber()));
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
        // enact receive with verified return val
        requester.receiveSuccinct(address(fulfiller), callData);

        // assert callback called
        assertTrue(callbackContract.sum() == 1);
    }

    function testRequestStorage() public {
        // reading value at first storage slot of UNI token - total supply constant
        address l1Address = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
        uint64 storageSlot = 0;

        uint256 beaconSlot = 5377744;
        bytes4 callbackSelector = callbackContract.saveStorageVal.selector;

        // setup light client with verified roots
        bytes32 executionRoot = 0xd78a6c6b3b75ca85ad35617f689e6b107cbf34ec61a2ae7c54ca1522bde9045f;
        lightClient.setExecutionRoot(beaconSlot, executionRoot);

        // request storage
        requester.requestStorage(
            l1Address, storageSlot, beaconSlot, callbackSelector, address(callbackContract)
        );

        // proofs
        bytes[] memory accountProof = Proofs.accountProof();
        bytes[] memory storageProof = Proofs.storageProof();

        // data at slot
        bytes32 dataAtSlot = bytes32(uint256(1000000000000000000000000000));

        // call receive storage
        requester.receiveStorage(
            requester.storageNonce(),
            l1Address,
            storageSlot,
            beaconSlot,
            callbackSelector,
            address(callbackContract),
            accountProof,
            storageProof,
            dataAtSlot
        );

        // assert callback called
        assertTrue(callbackContract.externalStorageVal() == uint256(dataAtSlot));
    }

    function testReceiveStorageDirect() public {
        // reading value at first storage slot of UNI token - total supply constant
        address l1Address = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
        uint64 storageSlot = 0;

        uint256 beaconSlot = 5377744;
        bytes4 callbackSelector = callbackContract.saveStorageVal.selector;

        // setup light client with verified roots
        bytes32 executionRoot = 0xd78a6c6b3b75ca85ad35617f689e6b107cbf34ec61a2ae7c54ca1522bde9045f;
        lightClient.setExecutionRoot(beaconSlot, executionRoot);

        // proofs
        bytes[] memory accountProof = Proofs.accountProof();
        bytes[] memory storageProof = Proofs.storageProof();

        // data at slot
        bytes32 dataAtSlot = bytes32(uint256(1000000000000000000000000000));

        // call receive storage
        requester.receiveStorageDirect(
            l1Address,
            storageSlot,
            beaconSlot,
            callbackSelector,
            address(callbackContract),
            accountProof,
            storageProof,
            dataAtSlot
        );

        // assert callback called
        assertTrue(callbackContract.externalStorageVal() == uint256(dataAtSlot));
    }
}
