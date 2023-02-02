// SPDX-LicmockDatae-Identifier: UNLICMockDataED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Message} from "telepathy/amb/interfaces/ITelepathy.sol";
import {MockTelepathy} from "telepathy/amb/mocks/MockAMB.sol";
import {TelepathyOracle, RequestStatus} from "src/oracle/TelepathyOracle.sol";
import {TelepathyOracleFulfiller} from "src/oracle/TelepathyOracleFulfiller.sol";
import {IOracleCallbackReceiver} from "src/oracle/interfaces/IOracleCallbackReceiver.sol";

contract MockData {
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
        uint256 _nonce,
        bytes memory responseData,
        bool responseSuccess
    ) external override {
        result = abi.decode(responseData, (uint256));
    }
}

contract TelepathyOracleTest is Test {
    event CrossChainRequestSent(
        uint256 indexed nonce,
        address targetContract,
        bytes4 targetSelector,
        bytes targetData,
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
        bytes4 targetSelector,
        bytes memory targetData,
        address callbackContract
    ) internal returns (uint256 nonce, bytes32 requestHash) {
        nonce = oracle.requestCrossChain(
            targetContract,
            targetSelector,
            targetData,
            callbackContract
        );
        console.logBytes(targetData);
        requestHash = keccak256(
            abi.encodePacked(
                nonce,
                targetContract,
                targetSelector,
                callbackContract,
                targetData
            )
        );
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
        MockData mockData = new MockData();
        MockReceiver receiver = new MockReceiver();
        assertEq(receiver.result(), 0);
        address targetContract = address(mockData);
        bytes4 targetSelector = MockData.get.selector;
        bytes memory targetData = "";
        address callbackContract = address(receiver);

        vm.expectEmit(true, true, true, false);
        emit CrossChainRequestSent(
            1,
            targetContract,
            targetSelector,
            targetData,
            callbackContract
        );
        uint256 nonce = oracle.requestCrossChain(
            targetContract,
            targetSelector,
            targetData,
            callbackContract
        );
        assertEq(nonce, 1);
        bytes32 requestHash = keccak256(
            abi.encodePacked(
                nonce,
                targetContract,
                targetSelector,
                callbackContract,
                targetData
            )
        );
        assertTrue(oracle.requests(requestHash) == RequestStatus.PENDING);

        fulfiller.fulfillCrossChainRequest(
            ORACLE_CHAIN,
            address(oracle),
            nonce,
            targetContract,
            targetSelector,
            targetData,
            callbackContract
        );

        sourceAmb.executeNextMessage();

        assertEq(receiver.result(), mockData.get());
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
        MockData mockData = new MockData();
        MockReceiver receiver = new MockReceiver();
        assertEq(receiver.result(), 0);
        address targetContract = address(mockData);
        bytes4 targetSelector = MockData.get.selector;
        bytes memory targetData = "";
        address callbackContract = address(receiver);

        (uint256 nonce, bytes32 requestHash) = makeRequest(
            targetContract,
            targetSelector,
            targetData,
            callbackContract
        );

        fulfiller.fulfillCrossChainRequest(
            ORACLE_CHAIN,
            address(oracle),
            1,
            targetContract,
            targetSelector,
            targetData,
            callbackContract
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
            1,
            targetContract,
            targetSelector,
            targetData,
            callbackContract
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
        MockData mockData = new MockData();
        MockReceiver receiver = new MockReceiver();
        assertEq(receiver.result(), 0);
        address targetContract = address(mockData);
        bytes4 targetSelector = MockData.hashString.selector;
        bytes memory targetData = abi.encode("hello world");
        address callbackContract = address(receiver);

        bytes memory fakeData = abi.encode("goodbye world");

        (uint256 nonce, bytes32 requestHash) = makeRequest(
            targetContract,
            targetSelector,
            targetData,
            callbackContract
        );

        console.logBytes32(requestHash);

        fulfiller.fulfillCrossChainRequest(
            ORACLE_CHAIN,
            address(oracle),
            nonce,
            targetContract,
            targetSelector,
            fakeData,
            callbackContract
        );
        (
            ,
            uint16 sourceChainId,
            address senderAddress,
            ,
            ,
            bytes memory data
        ) = sourceAmb.sentMessages(0);

        bytes32 badRequestHash = keccak256(
            abi.encodePacked(
                nonce,
                targetContract,
                targetSelector,
                callbackContract,
                fakeData
            )
        );

        vm.prank(address(targetAmb));
        vm.expectRevert(
            abi.encodeWithSelector(
                TelepathyOracle.RequestNotPending.selector,
                badRequestHash
            )
        );
        oracle.handleTelepathy(sourceChainId, senderAddress, data);
    }
}
