pragma solidity ^0.8.14;

import "telepathy/amb/interfaces/ITelepathy.sol";

enum RequestStatus {
    PENDING,
    SUCCESS,
    FAILED
}

struct Request {
    address _targetContract;
    bytes4 _targetSelector;
    address _callbackContract;
    Status status;
}

contract TelepathyOracleRequester is ITelepathyHandler {
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
    error InvalidResponse(bytes32 requestHash);

    mapping(bytes32 => Status) public requests;
    uint256 public nextNonce = 1;
    uint256 public fulfillerChainId;
    address public targetAmb;
    address public fulfiller;

    constructor(
        uint256 _fulfillerChainId,
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
                _targetData,
                _callbackContract
            )
        );
        requests[requestHash] = Status.PENDING;

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
        uint256 _sourceChain,
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
            address _callbackContract,
            bytes memory responseData,
            bool responseSuccess
        ) = abi.decode(data, (uint256, bytes32, address, bytes, bool));

        if (requests[requestHash] != Status.PENDING) {
            revert InvalidResponse(requestHash);
        }

        requests[requestHash] = responseSuccess
            ? Status.SUCCESS
            : Status.FAILED;

        _callbackContract.call(
            abi.encodeWithSelector(
                IOracleCallbackReceiver.handleOracleResponse.selector,
                nonce,
                responseData,
                responseSuccess
            )
        );
    }
}
