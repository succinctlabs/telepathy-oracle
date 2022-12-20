// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "telepathy/amb/libraries/MerklePatriciaTrie.sol";
import "telepathy/lightclient/interfaces/ILightClient.sol";

enum Status {
    SUCCEEDED,
    FAILED
}

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

    mapping(uint256 => Status) public requestResult;
    mapping(uint256 => Status) public storageRequestResult;

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
    error DirectCallFailed();
    error NotFulfiller(address srcAddress);
    error InvalidChainId(uint16 targetChainId);
    error InvalidData(bytes32 data);
    error InvalidNonce(uint256 nonce);

    /**
     * @dev contract constructor
     * @param _fulfiller address of the contract that can fulfill requests on Ethereum L1
     * @param _lightClient address of the light client contract
     */
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

        bytes memory callData = abi.encodePacked(selector, data);
        bytes memory fullData =
            abi.encode(viewNonce, address(this), gasLimit, block.chainid, callData);

        emit RequestSent(viewNonce, target, fullData);
        return fullData;
    }

    /**
     * @dev telepathy relayer calls this function to fulfill a request
     * @param srcAddress address of the OracleFulfill contract on eth
     * @param data result of view call
     */
    function receiveSuccinct(address srcAddress, bytes calldata data) external {
        if (srcAddress != fulfiller) {
            revert NotFulfiller(srcAddress);
        }
        (uint256 requestNonce, uint16 targetChainId, bytes memory result) =
            abi.decode(data, (uint256, uint16, bytes));

        if (targetChainId != block.chainid) {
            revert InvalidChainId(targetChainId);
        }

        Request storage req = requests[requestNonce];
        (bool success,) = req.callbackContract.call(abi.encodePacked(req.callbackSelector, result));
        if (!success) {
            requestResult[requestNonce] = Status.FAILED;
        } else {
            requestResult[requestNonce] = Status.SUCCEEDED;
            delete requests[requestNonce];
        }
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
     * @param beaconSlot beacon slot
     * @param callbackSelector function selector on sender contract to callback with result
     * @param callbackContract contract to callback with result
     * @param accountProof account proof from rpc call
     * @param storageProof storage proof from rpc call
     * @param dataAtSlot data at storage slot
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
        bytes32 dataAtSlot
    ) public {
        bytes32 slotKey = keccak256(abi.encode(storageSlot));
        _validateWithLightClient(
            l1Address, beaconSlot, accountProof, storageProof, dataAtSlot, slotKey
        );

        // verify nonce
        if (
            storageRequests[requestNonce]
                != keccak256(
                    abi.encodePacked(l1Address, storageSlot, callbackSelector, callbackContract)
                )
        ) {
            revert InvalidNonce(requestNonce);
        }
        // execute callback
        (bool success,) = callbackContract.call(abi.encodePacked(callbackSelector, dataAtSlot));
        if (!success) {
            storageRequestResult[requestNonce] = Status.FAILED;
        } else {
            storageRequestResult[requestNonce] = Status.SUCCEEDED;
            delete storageRequests[requestNonce];
        }
    }

    /**
     * @notice verifies storage proof and executes provided callback in single call
     * @param l1Address contract that was read
     * @param storageSlot storage slot that was read
     * @param beaconSlot beacon slot
     * @param callbackSelector function selector on sender contract to callback with result
     * @param callbackContract contract to callback with result
     * @param accountProof account proof from rpc call
     * @param storageProof storage proof from rpc call
     * @param dataAtSlot data at storage slot
     */
    function receiveStorageDirect(
        address l1Address,
        uint64 storageSlot,
        uint256 beaconSlot,
        bytes4 callbackSelector,
        address callbackContract,
        bytes[] calldata accountProof,
        bytes[] calldata storageProof,
        bytes32 dataAtSlot
    ) public {
        bytes32 slotKey = keccak256(abi.encode(storageSlot));
        _validateWithLightClient(
            l1Address, beaconSlot, accountProof, storageProof, dataAtSlot, slotKey
        );

        // execute callback
        (bool success,) = callbackContract.call(abi.encodePacked(callbackSelector, dataAtSlot));
        if (!success) {
            revert DirectCallFailed();
        }
    }

    /**
     * @notice verifies storage proof
     * @param l1Address contract that was read
     * @param beaconSlot beacon slot
     * @param accountProof account proof from rpc call
     * @param storageProof storage proof from rpc call
     * @param dataAtSlot data at storage slot
     * @param slotKey slot key
     */
    function _validateWithLightClient(
        address l1Address,
        uint256 beaconSlot,
        bytes[] calldata accountProof,
        bytes[] calldata storageProof,
        bytes32 dataAtSlot,
        bytes32 slotKey
    ) internal view {
        bytes32 executionStateRoot = lightClient.executionStateRoots(beaconSlot);
        bytes32 storageRoot = MPT.verifyAccount(accountProof, l1Address, executionStateRoot);
        bytes32 slotValue = bytes32(MPT.verifyStorage(slotKey, storageRoot, storageProof));
        if (slotValue != dataAtSlot) {
            revert InvalidData(dataAtSlot);
        }
    }
}
