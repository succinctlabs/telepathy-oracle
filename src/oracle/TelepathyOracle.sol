pragma solidity ^0.8.14;

import "forge-std/console.sol";
import {ITelepathyHandler} from "telepathy/amb/interfaces/ITelepathy.sol";
import {IOracleCallbackReceiver} from "src/oracle/interfaces/IOracleCallbackReceiver.sol";

enum RequestStatus {
    UNSENT,
    PENDING,
    SUCCESS,
    FAILED
}

contract TelepathyOracle is ITelepathyHandler {
    event CrossChainRequestSent(
        uint256 indexed nonce,
        address targetContract,
        bytes4 targetSelector,
        bytes targetData,
        address callbackContract
    );

    error InvalidChainId(uint256 sourceChain);
    error NotFulfiller(address srcAddress);
    error NotTargetAmb(address srcAddress);
    error RequestNotPending(bytes32 requestHash);

    mapping(bytes32 => RequestStatus) public requests;
    uint256 public nextNonce = 1;
    address public targetAmb;
    address public fulfiller;
    uint16 public fulfillerChainId;

    constructor(
        uint16 _fulfillerChainId,
        address _targetAmb,
        address _fulfiller
    ) {
        fulfillerChainId = _fulfillerChainId;
        targetAmb = _targetAmb;
        fulfiller = _fulfiller;
    }

    function requestCrossChain(
        address _targetContract,
        bytes4 _targetSelector,
        bytes calldata _targetData,
        address _callbackContract
    ) external returns (uint256 nonce) {
        unchecked {
            nonce = nextNonce++;
        }
        bytes32 requestHash = keccak256(
            abi.encodePacked(
                nonce,
                _targetContract,
                _targetSelector,
                _callbackContract,
                _targetData
            )
        );
        requests[requestHash] = RequestStatus.PENDING;

        emit CrossChainRequestSent(
            nonce,
            _targetContract,
            _targetSelector,
            _targetData,
            _callbackContract
        );
        return nonce;
    }

    function handleTelepathy(
        uint16 _sourceChain,
        address _senderAddress,
        bytes memory _data
    ) external override {
        if (_sourceChain != fulfillerChainId) {
            revert InvalidChainId(_sourceChain);
        }
        if (msg.sender != targetAmb) {
            revert NotTargetAmb(msg.sender);
        }
        if (_senderAddress != fulfiller) {
            revert NotFulfiller(_senderAddress);
        }

        (
            uint256 nonce,
            bytes32 requestHash,
            address callbackContract,
            bytes memory responseData,
            bool responseSuccess
        ) = abi.decode(_data, (uint256, bytes32, address, bytes, bool));

        if (requests[requestHash] != RequestStatus.PENDING) {
            revert RequestNotPending(requestHash);
        }

        requests[requestHash] = responseSuccess
            ? RequestStatus.SUCCESS
            : RequestStatus.FAILED;

        callbackContract.call(
            abi.encodeWithSelector(
                IOracleCallbackReceiver.handleOracleResponse.selector,
                nonce,
                responseData,
                responseSuccess
            )
        );
    }
}
