pragma solidity ^0.8.14;

import {ITelepathyBroadcaster} from "telepathy/amb/interfaces/ITelepathy.sol";

contract TelepathyOracleFulfiller {
    address sourceAmb;

    constructor(address _sourceAmb) {
        sourceAmb = _sourceAmb;
    }

    function fulfillCrossChainRequest(
        uint16 _oracleChain,
        address _oracleAddress,
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
                _callbackContract,
                _targetData
            )
        );
        bytes memory data = abi.encode(
            _nonce,
            requestHash,
            _callbackContract,
            responseData,
            responseSuccess
        );
        ITelepathyBroadcaster(sourceAmb).sendViaLog(
            _oracleChain,
            _oracleAddress,
            data
        );
    }
}
