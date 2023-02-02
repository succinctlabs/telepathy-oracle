pragma solidity ^0.8.14;

import {ITelepathyBroadcaster} from "telepathy/amb/interfaces/ITelepathy.sol";

contract TelepathyOracleFulfiller {
    ITelepathyBroadcaster telepathyBroadcaster;

    constructor(address _telepathyBroadcaster) {
        telepathyBroadcaster = ITelepathyBroadcaster(_telepathyBroadcaster);
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
                _targetCalldata,
                _callbackContract
            )
        );
        bytes memory data = abi.encode(
            _nonce,
            requestHash,
            _callbackContract,
            resultData,
            success
        );
        telepathyBroadcaster.sendViaLog(_oracleChain, _oracleAddress, data);
    }
}
