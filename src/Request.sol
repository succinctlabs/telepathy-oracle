// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./libraries/MerklePatriciaTrie.sol";
import "./interfaces/ILightClient.sol";

/**
 * @dev deploy on an alt-evm chain, make a request for a view function
 *  or storage slot on Ethereum and have it fulfilled via Telepathy.
 */
contract TelepathyOracleRequest {
    address fulfiller;
    ILightClient lightClient;
    uint256 public viewNonce;
    uint256 public storageNonce;
    mapping(uint256 => Request) public requests;
    mapping(uint256 => bytes32) public storageRequests;

    struct Request {
        address callbackContract;
        bytes4 callbackSelector;
    }

    event RequestSent(uint256 indexed viewNonce, address target, bytes data);
    event StorageRequestSent(
        uint256 indexed storageNonce,
        address l1Address,
        uint64 storageSlot,
        uint256 beaconSlot,
        bytes4 callbackSelector,
        address callbackContract
    );

    error CallFailed(uint256 nonce);
    error NotFulfiller(address srcAddress);
    error InvalidData(bytes32 data);
    error InvalidNonce(uint256 nonce);

    constructor(address _fulfiller, address _lightClient) {
        fulfiller = _fulfiller;
        lightClient = ILightClient(_lightClient);
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
        address callbackContract,
        bytes4 callbackSelector,
        address target,
        bytes4 selector,
        bytes memory data,
        uint256 gasLimit
    ) external returns (bytes memory) {
        requests[++viewNonce] = Request(callbackContract, callbackSelector);

        bytes memory callData = abi.encodeWithSelector(selector, data);
        bytes memory fullData = abi.encode(viewNonce, address(this), gasLimit, callData);

        emit RequestSent(viewNonce, target, fullData);
        return fullData;
    }

    function receiveSuccinct(address srcAddress, bytes calldata data) external {
        if (srcAddress != fulfiller) {
            revert NotFulfiller(srcAddress);
        }
        (uint256 requestNonce, bytes memory result) = abi.decode(data, (uint256, bytes));
        Request storage req = requests[requestNonce];
        (bool success,) = req.callbackContract.call(abi.encodePacked(req.callbackSelector, result));
        if (!success) {
            revert CallFailed(requestNonce);
        }
        delete requests[requestNonce];
    }

    /**
     * @notice lets you request a storage slot from eth
     * @param l1Address contract to read from
     * @param storageSlot slot on contract to read
     * @param beaconSlot block number to read at
     * @param callbackSelector function selector on sender contract to callback with result
     * @param callbackContract contract to callback with result
     */
    function requestStorage(
        address l1Address,
        uint64 storageSlot,
        uint256 beaconSlot,
        bytes4 callbackSelector,
        address callbackContract
    ) external {
        storageRequests[++storageNonce] =
            keccak256(abi.encodePacked(l1Address, storageSlot, callbackSelector, callbackContract));
        emit StorageRequestSent(
            storageNonce, l1Address, storageSlot, beaconSlot, callbackSelector, callbackContract
            );
    }

    /**
     * @notice verifies storage proof and executes callback from storage request
     * @param requestNonce nonce of storage request
     * @param l1Address contract that was read
     * @param storageSlot storage slot that was read
     * @param callbackSelector function selector on sender contract to callback with result
     * @param callbackContract contract to callback with result
     * @param accountProof account proof from rpc call
     * @param storageProof storage proof from rpc call
     * @param dataAtSlot data at storage slot
     * @param slotKey slot key
     */
    function receiveStorage(
        uint256 requestNonce,
        address l1Address,
        uint64 storageSlot,
        uint256 beaconSlot,
        bytes4 callbackSelector,
        address callbackContract,
        bytes[] calldata accountProof,
        bytes[] calldata storageProof,
        bytes32 dataAtSlot,
        bytes32 slotKey
    ) public {
        // validate with light client
        {
            bytes32 executionStateRoot = lightClient.executionStateRoots(beaconSlot);
            bytes32 storageRoot = MPT.verifyAccount(accountProof, l1Address, executionStateRoot);
            bytes32 slotValue = bytes32(MPT.verifyStorage(slotKey, storageRoot, storageProof));
            if (slotValue != dataAtSlot) {
                revert InvalidData(dataAtSlot);
            }
        }

        // verify nonce
        bytes32 callDataHash =
            keccak256(abi.encodePacked(l1Address, storageSlot, callbackSelector, callbackContract));
        if (storageRequests[requestNonce] != callDataHash) {
            revert InvalidNonce(requestNonce);
        }
        // execute callback
        (bool success,) = callbackContract.call(abi.encodePacked(callbackSelector, dataAtSlot));
        if (!success) {
            revert CallFailed(requestNonce);
        }
        delete storageRequests[requestNonce];
    }
}
