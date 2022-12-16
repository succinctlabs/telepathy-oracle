// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 @dev deploy on an alt-evm chain, make a request for a view function 
 or storage slot on Ethereum and have it fulfilled via Telepathy.
 */
contract TelepathyOracleRequest {
    address fulfiller;
    address lightClient;
    uint256 public nonce;
    mapping(uint256 => Request) public requests;

    struct Request {
        address sender;
        bytes4 callbackSelector;
    }

    event RequestSent(uint256 indexed nonce, address target, bytes data);
    event StorageRequestSent(
        uint256 indexed nonce,
        address l1Address,
        uint256 storageSlot,
        uint256 blockNumber
    );

    error CallFailed(bytes callData);

    constructor(address _fulfiller, address _lightClient) {
        fulfiller = _fulfiller;
        lightClient = _lightClient;
    }

    /**
     * @notice lets you request a view function read from eth
     * @param callbackSelector function selector on sender contract to callback with result
     * @param target address to call on eth
     * @param selector function selector on eth
     * @param data calldata to call on eth
     * @param gasLimit gas limit for callback
     */
    function requestView(
        bytes4 callbackSelector,
        address target,
        bytes4 selector,
        bytes memory data,
        uint256 gasLimit
    ) external returns (bytes memory) {
        requests[++nonce] = Request(msg.sender, callbackSelector);

        bytes memory callData = abi.encodeWithSelector(selector, data);
        bytes memory fullData = abi.encode(
            nonce,
            address(this),
            gasLimit,
            callData
        );

        emit RequestSent(nonce, target, fullData);
        return fullData;
    }

    function receiveSuccinct(address srcAddress, bytes calldata data)
        external
    {
        require(srcAddress == fulfiller, "Not fulfiller");
        (uint256 requestNonce, bytes memory result) = abi.decode(
            data,
            (uint256, bytes)
        );

        Request storage req = requests[requestNonce];
        (bool success, ) = req.sender.call(
            abi.encodePacked(req.callbackSelector, result)
        );
        if (!success) {
            revert CallFailed(data);
        }
    }

    /**
     * @notice lets you request a storage slot from eth
     * @param l1Address contract to read from
     * @param storageSlot slot on contract to read
     * @param blockNumber block number to read at
     * @param callbackSelector function selector on sender contract to callback with result
     */
    function requestStorage(
        address l1Address,
        uint256 storageSlot,
        uint256 blockNumber,
        bytes4 callbackSelector
    ) external {
        requests[++nonce] = Request(msg.sender, callbackSelector);
        emit StorageRequestSent(nonce, l1Address, storageSlot, blockNumber);
    }

    function receiveStorage(
        uint64 slot,
        bytes calldata messageBytes,
        bytes[] calldata accountProof,
        bytes[] calldata storageProof,
        bytes calldata data
    ) public {
        // validate with light client ala targetamb
        {
            bytes32 executionStateRoot = lightClient.executionStateRoots(slot);
            bytes32 storageRoot = MPT.verifyAccount(accountProof, sourceAMB, executionStateRoot);
            bytes32 slotKey = keccak256(abi.encode(keccak256(abi.encode(message.nonce, 0))));
            uint256 slotValue = MPT.verifyStorage(slotKey, storageRoot, storageProof);

            if (bytes32(slotValue) != messageRoot) {
                revert("Invalid message hash.");
            }
        }
        
        // do call back
         (uint256 requestNonce, bytes memory result) = abi.decode(
            data,
            (uint256, bytes)
        );

        Request storage req = requests[requestNonce];
        (bool success, ) = req.sender.call(
            abi.encodePacked(req.callbackSelector, result)
        );
        if (!success) {
            revert CallFailed(data);
        }
    }    
}
