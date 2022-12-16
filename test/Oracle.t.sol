// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Fulfill.sol";
import "../src/Request.sol";
import "../src/test/SourceAMB.sol";
import "../src/test/Dummy.sol";

contract OracleTtest is Test {
    uint256 GAS_LIMIT = 100_000;
    SourceAMB public sourceAMB;

    TelepathyOracleRequest public requester;
    TelepathyOracleFulfill public fulfiller;

    DummyCallback public callbackContract;
    DummyView public viewContract;

    address lightClient = address(5); // TODO

    function setUp() public {
        sourceAMB = new SourceAMB();
        fulfiller = new TelepathyOracleFulfill(address(sourceAMB));
        requester = new TelepathyOracleRequest(address(fulfiller), lightClient, address(sourceAMB));

        callbackContract = new DummyCallback();
        viewContract = new DummyView();
    }

    function testRequestView() public {
        // request view
        bytes memory data = callbackContract.requestGetNumber(
            address(requester), address(viewContract), viewContract.getNumber.selector, GAS_LIMIT
        );

        // calculate messageroot
        bytes32 messageRoot = fulfiller.fulfillRequest(address(viewContract), data);

        // calculate return data
        bytes memory callData = abi.encode(requester.nonce(), abi.encode(viewContract.getNumber()));
        // assert correct return message
        assertTrue(
            messageRoot
                == keccak256(
                    abi.encode(
                        sourceAMB.nonce() - 1,
                        address(fulfiller),
                        address(requester),
                        fulfiller.chainId(),
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
}
