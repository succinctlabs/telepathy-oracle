pragma solidity ^0.8.14;

import "telepathy/amb/interfaces/ITelepathy.sol";

contract CrossChainOracleFulfiller {
    uint256 requesterChainId;
    address sourceAmb;
    address requester;

    constructor(
        uint256 _requesterChainId,
        address _sourceAmb,
        address _requester
    ) {
        requesterChainId = _requesterChainId;
        sourceAmb = _sourceAmb;
        requester = _requester;
    }

    function fulfillCrossChainRequest(
        uint256 _nonce,
        address _targetContract,
        bytes4 _targetSelector,
        bytes calldata _targetData,
        address _callbackContract
    ) external {
        (bool responseSuccess, bytes memory responseData) = _targetContract
            .staticcall(abi.encodeWithSelector(_targetSelector, _targetData));
        bytes32 requestHash = keccak256(
            abi.encodePacked(
                _nonce,
                _targetContract,
                _targetSelector,
                _targetData,
                _callbackContract
            )
        );
        bytes memory data = abi.encodePacked(
            _nonce,
            requestHash,
            _callbackContract,
            responseData,
            responseSuccess
        );
        IAMB(sourceAmb).sendViaLog(requesterChainId, requester, data);
    }
}
