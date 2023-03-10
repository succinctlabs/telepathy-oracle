pragma solidity ^0.8.16;

import {TelepathyHandler} from "telepathy-contracts/amb/interfaces/TelepathyHandler.sol";

enum SubscriptionStatus {
    UNSUBSCIBED,
    SUBSCRIBED
}

struct SubscriptionData {
    uint256 nonce;
    uint32 destinationChainId;
    bytes32 destinationAddress;
    address callbackAddress;
    bytes eventSig;
}


contract TelepathySubsciber {
    event Subscribe(
        uint256 indexed nonce,
        address destinationContract,
        bytes destinationCalldata,
        address callbackContract,
        bytes eventSig
    );

    event Unsubscribe(
        uint256 indexed nonce,
        address destinationContract,
        bytes destinationCalldata,
        address callbackContract,
        bytes eventSig
    );

    error SubscriptionAlreadyActive(bytes32 subscriptionHash);
    error SubscriptionNotActive(bytes32 subscriptionHash);

    uint256 public nextNonce = 1;
    mapping(bytes32 => SubscriptionStatus) public subscriptions;

    function subscribe(uint32 _destinationChainId, bytes32 _destinationAddress, address _callbackAddress, bytes calldata _eventSig)
        external
        returns (uint256 nonce)
    {
        unchecked {
            nonce = nextNonce++;
        }

        SubscriptionData memory subscriptionData =
            SubscriptionData(nonce, _destinationChainId, _destinationAddress, _callbackAddress, _eventSig);
        bytes32 subscriptionHash = keccak256(abi.encode(subscriptionData));
        if(subscriptions[subscriptionHash] == SubscriptionStatus.SUBSCRIBED)  {
            revert SubscriptionAlreadyActive(subscriptionHash);
        }
        subscriptions[subscriptionHash] = SubscriptionStatus.SUBSCRIBED;

        emit Subscribe(nonce, subscriptionHash, subscriptionData);
    }

    /// @dev Only the original callbackAddress contract will be able to unsubscribe.
    function unsubscribe(uint256 nonce, uint32 _destinationChainId, bytes32 _destinationAddress, bytes calldata _eventSig)
        external
        returns (bytes32)
    {
        SubscriptionData memory subscriptionData =
            SubscriptionData(nonce, _destinationChainId, _destinationAddress, msg.sender, _eventSig);
        bytes32 subscriptionHash = keccak256(abi.encode(subscriptionData));
        if(subscriptions[subscriptionHash] == SubscriptionStatus.UNSUBSCIBED)  {
            revert SubscriptionNotActive(subscriptionHash);
        }
        subscriptions[subscriptionHash] = SubscriptionStatus.UNSUBSCIBED;
        
        emit Unsubscribe(nonce, subscriptionHash, subscriptionData);
    }
}

contract TestEventSubsciber {
    bytes32 EVENT_SIG = keccak256("SentMessage(uint64,bytes32,bytes)");

    TelepathySubsciber public telepathySubsciber;
    uint256 subscriptionId;

    constructor(address _telepathySubsciber, address _telepathyRouter) TelepathyHandler(_telepathyRouter) {
        telepathySubsciber = TelepathySubsciber(_telepathySubsciber);
    }

    function subscribeToEvent(uint32 _destinationChainId, bytes32 _destinationAddress) external {
        uint256 id = telepathySubsciber.subscribe(_destinationChainId, _destinationAddress, address(this), EVENT_SIG);
        subscriptionId = id;
    }

    function unsubscribeFromEvent(uint32 _destinationChainId, bytes32 _destinationAddress) external {
        telepathySubsciber.unsubscribe(subscriptionId, _destinationChainId, _destinationAddress, EVENT_SIG);
    }

    function handleTelepathyImpl(uint32 _sourceChain, address _senderAddress, bytes memory _data)
        internal
        override
    {
        (
            uint256 nonce,
            uint32 destinationChainId,
            bytes32 destinationAddress,
            address callbackAddress,
            bytes memory eventSig,
            bytes memory eventData
        ) = abi.decode(_data, (uint256, address, bytes, address, bytes));

        abi.encodeWithSignature(keccak256("SentMessage(uint64,bytes32,bytes)"), arg);
        SubscriptionData memory subscriptionData =
            SubscriptionData(nonce, _destinationChainId, _destinationAddress, _callbackAddress, _eventSig);
        bytes32 subscriptionHash = keccak256(abi.encode(subscriptionData));
        if(subscriptions[subscriptionHash] == SubscriptionStatus.UNSUBSCIBED)  {
            revert SubscriptionNotActive(subscriptionHash);
        }

        callbackContract.call(
            abi.encodeWithSelector(
                IOracleCallbackReceiver.handleOracleResponse.selector,
                nonce,
                responseData,
                responseSuccess
            )
        );
    }
}