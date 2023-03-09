pragma solidity ^0.8.14;

import {ITelepathyHandler} from "telepathy-contracts/amb/interfaces/ITelepathy.sol";
import {IOracleCallbackReceiver} from "src/oracle/interfaces/IOracleCallbackReceiver.sol";

enum RequestStatus {
    UNSENT,
    PENDING,
    SUCCESS,
    FAILED
}

struct RequestData {
    uint256 nonce;
    address targetContract;
    bytes targetCalldata;
    address callbackContract;
}

contract TelepathyOracle is ITelepathyHandler {
    event CrossChainRequestSent(
        uint256 indexed nonce,
        address targetContract,
        bytes targetCalldata,
        address callbackContract
    );

    error InvalidChainId(uint256 sourceChain);
    error NotFulfiller(address srcAddress);
    error NotTargetAmb(address srcAddress);
    error RequestNotPending(bytes32 requestHash);

    /// @notice Maps request hashes to their status
    /// @dev The hash of a request is keccak256(abi.encode(RequestData))
    mapping(bytes32 => RequestStatus) public requests;
    /// @notice The next nonce to use when sending a cross-chain request
    uint256 public nextNonce = 1;
    /// @notice The address of the target AMB contract
    address public targetAmb;
    /// @notice The address of the fulfiller contract on the other chain
    address public fulfiller;
    /// @notice The chain ID of the fulfiller contract
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
        bytes calldata _targetCalldata,
        address _callbackContract
    ) external returns (uint256 nonce) {
        unchecked {
            nonce = nextNonce++;
        }
        RequestData memory requestData = RequestData(
            nonce,
            _targetContract,
            _targetCalldata,
            _callbackContract
        );
        bytes32 requestHash = keccak256(abi.encode(requestData));
        requests[requestHash] = RequestStatus.PENDING;

        emit CrossChainRequestSent(
            nonce,
            _targetContract,
            _targetCalldata,
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
