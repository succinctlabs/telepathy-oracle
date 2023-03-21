pragma solidity ^0.8.16;

import {TelepathyPubSub} from "src/pubsub/TelepathyPubSub.sol";
import {SubscriptionReceiver} from "src/pubsub/interfaces/SubscriptionReceiver.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

/// @title TelepathyValidator
/// @author Succinct Labs
/// @notice A validator for the ETH (Foreign) -> Gnosis (Home) bridge that relies on the Telepathy Protocol
///         for proof of consensus in verifying the UserRequestForAffirmation event was emitted on Ethereum.
contract TelepathyValidator is SubscriptionReceiver, Ownable {
    event AffirmationHandled(bytes32 indexed messageId, bytes header, bytes data);

    error InvalidSourceChain(uint32 sourceChainId);
    error InvalidSourceAddress(address sourceAddress);
    error InvalidSlot(uint64 slot);
    error InvalidSubscriptionId(bytes32 subscriptionId);

    /// @dev Listen for event UserRequestForAffirmation(bytes32 indexed messageId, bytes encodedData)
    ///      where the encodedData is the ABI encoded message from the Foreign AMB.
    bytes32 constant AFFIRMATION_EVENT_SIG = keccak256("UserRequestForAffirmation(bytes32,bytes)");

    uint32 immutable EVENT_SOURCE_CHAIN_ID;
    address immutable EVENT_SOURCE_ADDRESS;
    uint64 immutable START_SLOT;
    uint64 immutable END_SLOT;
    IBasicHomeAMB immutable HOME_AMB;

    bytes32 public subscriptionId;
    bool executeAffirmationsEnabled;

    constructor(
        address _telepathyPubSub,
        uint32 _sourceChainId,
        address _sourceAddress,
        uint64 _startSlot,
        uint64 _endSlot,
        address _homeAMB,
        address _owner
    ) SubscriptionReceiver(_telepathyPubSub) {
        EVENT_SOURCE_CHAIN_ID = _sourceChainId;
        EVENT_SOURCE_ADDRESS = _sourceAddress;
        START_SLOT = _startSlot;
        END_SLOT = _endSlot;
        HOME_AMB = IBasicHomeAMB(_homeAMB);
        transferOwnership(_owner);
    }

    function toggleExecuteAffirmations() external onlyOwner {
        executeAffirmationsEnabled = !executeAffirmationsEnabled;
    }

    function subscribeToAffirmationEvent() external onlyOwner returns (bytes32) {
        subscriptionId = telepathyPubSub.subscribe(
            EVENT_SOURCE_CHAIN_ID,
            EVENT_SOURCE_ADDRESS,
            address(this),
            AFFIRMATION_EVENT_SIG,
            START_SLOT,
            END_SLOT
        );
        return subscriptionId;
    }

    /// @notice Handle the published affirmation event by executing the affirmation in the Home AMB.
    /// @dev We decode 'abi.encodePacked(header, _data)' to extract just the encoded message '_data' from the event.
    function handlePublishImpl(
        bytes32 _subscriptionId,
        uint32 _sourceChainId,
        address _sourceAddress,
        uint64 _slot,
        bytes32[] memory eventTopics,
        bytes memory eventdata
    ) internal override {
        if (_sourceChainId != EVENT_SOURCE_CHAIN_ID) {
            revert InvalidSourceChain(_sourceChainId);
        }

        if (_sourceAddress != EVENT_SOURCE_ADDRESS) {
            revert InvalidSourceAddress(_sourceAddress);
        }

        if (_slot < START_SLOT || _slot > END_SLOT) {
            revert InvalidSlot(_slot);
        }

        if (_subscriptionId != subscriptionId) {
            revert InvalidSubscriptionId(_subscriptionId);
        }

        (bytes memory header, bytes memory data) = abi.decode(eventdata, (bytes, bytes));

        if (executeAffirmationsEnabled) {
            HOME_AMB.executeAffirmation(data);
        }

        emit AffirmationHandled(eventTopics[1], header, data);
    }
}

interface IBasicHomeAMB {
    function executeAffirmation(bytes calldata message) external;
}

/// @notice Copied from tokenbridge-contracts for solidity compiler compatibility.
library ArbitraryMessage {
    /**
     * @dev Unpacks data fields from AMB message
     * layout of message :: bytes:
     * offset  0              : 32 bytes :: uint256 - message length
     * offset 32              : 32 bytes :: bytes32 - messageId
     * offset 64              : 20 bytes :: address - sender address
     * offset 84              : 20 bytes :: address - executor contract
     * offset 104             : 4 bytes  :: uint32  - gasLimit
     * offset 108             : 1 bytes  :: uint8   - source chain id length (X)
     * offset 109             : 1 bytes  :: uint8   - destination chain id length (Y)
     * offset 110             : 1 bytes  :: uint8   - dataType
     * offset 111             : X bytes  :: bytes   - source chain id
     * offset 111 + X         : Y bytes  :: bytes   - destination chain id
     *
     * NOTE: when message structure is changed, make sure that MESSAGE_PACKING_VERSION from VersionableAMB is updated as well
     * NOTE: assembly code uses calldatacopy, make sure that message is passed as the first argument in the calldata
     * @param _data encoded message
     */
    function unpackData(bytes memory _data)
        internal
        pure
        returns (
            bytes32 messageId,
            address sender,
            address executor,
            uint32 gasLimit,
            uint8 dataType,
            uint256[2] memory chainIds,
            bytes memory data
        )
    {
        // 32 (message id) + 20 (sender) + 20 (executor) + 4 (gasLimit) + 1 (source chain id length) + 1 (destination chain id length) + 1 (dataType)
        uint256 srcdataptr = 32 + 20 + 20 + 4 + 1 + 1 + 1;
        uint256 datasize;

        assembly {
            messageId := mload(add(_data, 32)) // 32 bytes
            sender := and(mload(add(_data, 52)), 0xffffffffffffffffffffffffffffffffffffffff) // 20 bytes

            // executor (20 bytes) + gasLimit (4 bytes) + srcChainIdLength (1 byte) + dstChainIdLength (1 bytes) + dataType (1 byte) + remainder (5 bytes)
            let blob := mload(add(_data, 84))

            // after bit shift left 12 bytes are zeros automatically
            executor := shr(96, blob)
            gasLimit := and(shr(64, blob), 0xffffffff)

            dataType := byte(26, blob)

            // load source chain id length
            let chainIdLength := byte(24, blob)

            // at this moment srcdataptr points to sourceChainId

            // mask for sourceChainId
            // e.g. length X -> (1 << (X * 8)) - 1
            let mask := sub(shl(shl(3, chainIdLength), 1), 1)

            // increase payload offset by length of source chain id
            srcdataptr := add(srcdataptr, chainIdLength)

            // write sourceChainId
            mstore(chainIds, and(mload(add(_data, srcdataptr)), mask))

            // at this moment srcdataptr points to destinationChainId

            // load destination chain id length
            chainIdLength := byte(25, blob)

            // mask for destinationChainId
            // e.g. length X -> (1 << (X * 8)) - 1
            mask := sub(shl(shl(3, chainIdLength), 1), 1)

            // increase payload offset by length of destination chain id
            srcdataptr := add(srcdataptr, chainIdLength)

            // write destinationChainId
            mstore(add(chainIds, 32), and(mload(add(_data, srcdataptr)), mask))

            // at this moment srcdataptr points to payload

            // datasize = message length - payload offset
            datasize := sub(mload(_data), srcdataptr)
        }

        data = new bytes(datasize);
        assembly {
            // 36 = 4 (selector) + 32 (bytes length header)
            srcdataptr := add(srcdataptr, 36)

            // calldataload(4) - offset of first bytes argument in the calldata
            calldatacopy(add(data, 32), add(calldataload(4), srcdataptr), datasize)
        }
    }
}
