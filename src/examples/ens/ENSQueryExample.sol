pragma solidity ^0.8.14;

import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {TelepathyOracle} from "src/oracle/TelepathyOracle.sol";
import {IOracleCallbackReceiver} from "src/oracle/interfaces/IOracleCallbackReceiver.sol";
import {ENSUtil} from "src/examples/ens/ENSUtil.sol";

struct Request {
    address sender;
    bytes32 node;
}

struct ResolvedAddress {
    bool success;
    address addr;
    uint88 timestamp;
}

/// @title ENSQueryExample
/// @notice Example contract that queries mainnet to resolve an ENS name on chain
contract ENSQueryExample is IOracleCallbackReceiver {
    error NotFromOracle(address srcAddress);

    address ensUtil;
    TelepathyOracle oracle;

    /// @notice Maps oracle nonce to the address that requested the claim and the requested node
    mapping(uint256 => Request) public requests;
    /// @notice Maps resolved ENS names to their addresses (could be outdated)
    mapping(bytes32 => ResolvedAddress) public addresses;

    constructor(address _oracle, address _ensUtil) {
        oracle = TelepathyOracle(_oracle);
        ensUtil = _ensUtil;
    }

    function sendQuery(bytes32 _node) external returns (uint256) {
        uint256 nonce = oracle.requestCrossChain(
            address(ensUtil),
            abi.encodeWithSelector(ENSUtil.resolve.selector, _node),
            address(this)
        );
        requests[nonce] = Request(msg.sender, _node);
        return nonce;
    }

    function handleOracleResponse(
        uint256 _nonce,
        bytes memory _responseData,
        bool _responseSuccess
    ) external override {
        if (msg.sender != address(oracle)) {
            revert NotFromOracle(msg.sender);
        }
        address resolved;
        if (_responseSuccess) {
            resolved = abi.decode(_responseData, (address));
        }
        bytes32 node = requests[_nonce].node;
        delete requests[_nonce];
        // node => resolved
        addresses[node] = ResolvedAddress(
            _responseSuccess,
            resolved,
            uint88(block.timestamp)
        );
        // we can add extra effects here if desired
    }
}
