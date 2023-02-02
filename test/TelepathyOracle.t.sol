// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Message} from "telepathy/amb/interfaces/ITelepathy.sol";
import {MockTelepathy} from "telepathy/amb/mocks/MockAMB.sol";
import {TelepathyOracle, RequestStatus, RequestData} from "src/oracle/TelepathyOracle.sol";
import {TelepathyOracleFulfiller} from "src/oracle/TelepathyOracleFulfiller.sol";
import {IOracleCallbackReceiver} from "src/oracle/interfaces/IOracleCallbackReceiver.sol";

contract MockMainnetData {
    uint256 val = block.timestamp;

    function get() public view returns (uint256) {
        return val;
    }

    function hashString(string memory str) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(str));
    }
}

contract MockReceiver is IOracleCallbackReceiver {
    uint256 public result;

    function handleOracleResponse(
        uint256,
        bytes memory responseData,
        bool
    ) external override {
        result = abi.decode(responseData, (uint256));
    }
}

contract TelepathyOracleTest is Test {
    event CrossChainRequestSent(
        uint256 indexed nonce,
        address targetContract,
        bytes targetCalldata,
        address callbackContract
    );

    MockTelepathy sourceAmb;
    MockTelepathy targetAmb;
    TelepathyOracleFulfiller fulfiller;
    TelepathyOracle oracle;

    uint16 ORACLE_CHAIN = 137;
    uint16 FULFILLER_CHAIN = 1;

    function makeRequest(
        address targetContract,
        bytes memory targetCalldata,
        address callbackContract
    ) internal returns (RequestData memory requestData, bytes32 requestHash) {
        uint256 nonce = oracle.requestCrossChain(
            targetContract,
            targetCalldata,
            callbackContract
        );
        requestData = RequestData(
            nonce,
            targetContract,
            targetCalldata,
            callbackContract
        );
        requestHash = keccak256(abi.encode(requestData));
    }

    function setUp() public {
        sourceAmb = new MockTelepathy(FULFILLER_CHAIN);
        targetAmb = new MockTelepathy(ORACLE_CHAIN);
        sourceAmb.addTelepathyReceiver(ORACLE_CHAIN, targetAmb);
        fulfiller = new TelepathyOracleFulfiller(address(sourceAmb));
        oracle = new TelepathyOracle{salt: 0}(
            FULFILLER_CHAIN,
            address(targetAmb),
            address(fulfiller)
        );
    }

    function testSimple() public {
        MockMainnetData mockMainnetData = new MockMainnetData();
        MockReceiver receiver = new MockReceiver();
        assertEq(receiver.result(), 0);
        address targetContract = address(mockMainnetData);
        bytes memory targetCalldata = abi.encodeWithSelector(
            MockMainnetData.get.selector
        );
        address callbackContract = address(receiver);

        vm.expectEmit(true, true, true, false);
        emit CrossChainRequestSent(
            1,
            targetContract,
            targetCalldata,
            callbackContract
        );
        (RequestData memory requestData, bytes32 requestHash) = makeRequest(
            targetContract,
            targetCalldata,
            callbackContract
        );
        assertEq(requestData.nonce, 1);
        assertTrue(oracle.requests(requestHash) == RequestStatus.PENDING);

        fulfiller.fulfillCrossChainRequest(
            ORACLE_CHAIN,
            address(oracle),
            requestData
        );

        sourceAmb.executeNextMessage();

        assertEq(receiver.result(), mockMainnetData.get());
    }

    function testRevertNotFromAmb() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                TelepathyOracle.NotTargetAmb.selector,
                address(this)
            )
        );
        oracle.handleTelepathy(FULFILLER_CHAIN, address(fulfiller), "");
    }

    function testRevertWrongChainId() public {
        vm.prank(address(targetAmb));
        vm.expectRevert(
            abi.encodeWithSelector(
                TelepathyOracle.InvalidChainId.selector,
                12345
            )
        );
        oracle.handleTelepathy(12345, address(fulfiller), "");
    }

    function testRevertNotFromFulfiller() public {
        vm.prank(address(targetAmb));
        vm.expectRevert(
            abi.encodeWithSelector(
                TelepathyOracle.NotFulfiller.selector,
                address(this)
            )
        );
        oracle.handleTelepathy(FULFILLER_CHAIN, address(this), "");
    }

    function testRevertReplayResponse() public {
        MockMainnetData mockMainnetData = new MockMainnetData();
        MockReceiver receiver = new MockReceiver();
        assertEq(receiver.result(), 0);
        address targetContract = address(mockMainnetData);
        bytes memory targetCalldata = abi.encodeWithSelector(
            MockMainnetData.get.selector
        );
        address callbackContract = address(receiver);

        (RequestData memory requestData, bytes32 requestHash) = makeRequest(
            targetContract,
            targetCalldata,
            callbackContract
        );

        fulfiller.fulfillCrossChainRequest(
            ORACLE_CHAIN,
            address(oracle),
            requestData
        );
        (
            ,
            uint16 sourceChainId,
            address senderAddress,
            ,
            ,
            bytes memory data
        ) = sourceAmb.sentMessages(0);
        vm.prank(address(targetAmb));
        oracle.handleTelepathy(sourceChainId, senderAddress, data);

        fulfiller.fulfillCrossChainRequest(
            ORACLE_CHAIN,
            address(oracle),
            requestData
        );
        vm.prank(address(targetAmb));
        vm.expectRevert(
            abi.encodeWithSelector(
                TelepathyOracle.RequestNotPending.selector,
                requestHash
            )
        );
        oracle.handleTelepathy(sourceChainId, senderAddress, data);
    }

    function testRevertIncorrectResponseData() public {
        MockMainnetData mockMainnetData = new MockMainnetData();
        MockReceiver receiver = new MockReceiver();
        assertEq(receiver.result(), 0);
        address targetContract = address(mockMainnetData);
        bytes memory targetCalldata = abi.encodeWithSelector(
            MockMainnetData.hashString.selector,
            "hello world"
        );
        address callbackContract = address(receiver);

        bytes memory fakeTargetCalldata = abi.encodeWithSelector(
            MockMainnetData.hashString.selector,
            "goodbye world"
        );

        (RequestData memory realRequestData, ) = makeRequest(
            targetContract,
            targetCalldata,
            callbackContract
        );

        RequestData memory fakeRequestData = RequestData(
            realRequestData.nonce,
            realRequestData.targetContract,
            fakeTargetCalldata,
            realRequestData.callbackContract
        );

        fulfiller.fulfillCrossChainRequest(
            ORACLE_CHAIN,
            address(oracle),
            fakeRequestData
        );
        (
            ,
            uint16 sourceChainId,
            address senderAddress,
            ,
            ,
            bytes memory data
        ) = sourceAmb.sentMessages(0);

        bytes32 fakeRequestHash = keccak256(abi.encode(fakeRequestData));

        vm.prank(address(targetAmb));
        vm.expectRevert(
            abi.encodeWithSelector(
                TelepathyOracle.RequestNotPending.selector,
                fakeRequestHash
            )
        );
        oracle.handleTelepathy(sourceChainId, senderAddress, data);
    }
}
