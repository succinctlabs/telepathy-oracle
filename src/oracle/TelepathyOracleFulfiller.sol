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
        bytes calldata _targetCalldata,
        address _callbackContract
    ) external {
        (bool success, bytes memory resultData) = _targetContract.call(
            _targetCalldata
        );
        bytes32 requestHash = keccak256(
            abi.encodePacked(
                _nonce,
                _targetContract,
                _callbackContract,
                _targetCalldata
            )
        );
        bytes memory data = abi.encode(
            _nonce,
            requestHash,
            _callbackContract,
            resultData,
            success
        );
        ITelepathyBroadcaster(sourceAmb).sendViaLog(
            _oracleChain,
            _oracleAddress,
            data
        );
    }
}
