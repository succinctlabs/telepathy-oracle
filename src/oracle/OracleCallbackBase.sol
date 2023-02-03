pragma solidity ^0.8.14;

import {IOracleCallbackReceiver} from "src/oracle/interfaces/IOracleCallbackReceiver.sol";

abstract contract OracleCallbackBase is IOracleCallbackReceiver {
    error NotFromOracle(address sender);

    address private _oracle;

    constructor(address oracle) {
        _oracle = oracle;
    }

    function rawHandleOracleResponse(
        uint256 nonce,
        bytes memory responseData,
        bool responseSuccess
    ) external override {
        if (msg.sender != _oracle) {
            revert NotFromOracle(msg.sender);
        }
        handleOracleResponse(nonce, responseData, responseSuccess);
    }

    function handleOracleResponse(
        uint256 nonce,
        bytes memory responseData,
        bool responseSuccess
    ) internal virtual;
}
