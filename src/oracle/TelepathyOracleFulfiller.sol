pragma solidity ^0.8.14;

import {ITelepathyBroadcaster} from "telepathy/amb/interfaces/ITelepathy.sol";
import {RequestData} from "src/oracle/TelepathyOracle.sol";

contract TelepathyOracleFulfiller {
    ITelepathyBroadcaster telepathyBroadcaster;

    constructor(address _telepathyBroadcaster) {
        telepathyBroadcaster = ITelepathyBroadcaster(_telepathyBroadcaster);
    }

    function fulfillCrossChainRequest(
        uint16 _oracleChain,
        address _oracleAddress,
        RequestData calldata _requestData
    ) external {
        bool success = false;
        bytes memory resultData;
        if (_requestData.targetContract.code.length != 0) {
            (success, resultData) = _requestData.targetContract.call(
                _requestData.targetCalldata
            );
        }
        bytes32 requestHash = keccak256(abi.encode(_requestData));
        bytes memory data = abi.encode(
            _requestData.nonce,
            requestHash,
            _requestData.callbackContract,
            resultData,
            success
        );
        telepathyBroadcaster.sendViaLog(_oracleChain, _oracleAddress, data);
    }
}
