pragma solidity ^0.8.14;

import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {TelepathyOracle} from "src/oracle/TelepathyOracle.sol";
import {OracleCallbackBase} from "src/oracle/OracleCallbackBase.sol";

struct Claim {
    address sender;
    uint256 tokenId;
}

abstract contract NFTAirdrop is OracleCallbackBase {
    event AirdropClaimed(address indexed sender, uint256 indexed tokenId);

    error NotOwnerOfToken(address owner, uint256 tokenId);
    error AlreadyClaimed(uint256 tokenId);
    error OracleQueryFailed();

    address sourceNft;
    TelepathyOracle oracle;

    /// @notice Maps oracle nonce to the address that requested the claim
    mapping(uint256 => Claim) public claimRequests;
    /// @notice Maps token IDs to whether they have been claimed
    mapping(uint256 => bool) public claimed;

    constructor(address _sourceNft, address _oracle)
        OracleCallbackBase(_oracle)
    {
        sourceNft = _sourceNft;
        oracle = TelepathyOracle(_oracle);
    }

    function claimAirdrop(uint256 _tokenId) external {
        if (claimed[_tokenId]) {
            revert AlreadyClaimed(_tokenId);
        }
        uint256 nonce = oracle.requestCrossChain(
            address(sourceNft),
            abi.encodeWithSelector(IERC721.ownerOf.selector, _tokenId),
            address(this)
        );
        claimRequests[nonce] = Claim(msg.sender, _tokenId);
    }

    function handleOracleResponse(
        uint256 _nonce,
        bytes memory _responseData,
        bool _responseSuccess
    ) internal override {
        if (!_responseSuccess) {
            revert OracleQueryFailed();
        }
        address owner = abi.decode(_responseData, (address));
        Claim storage claim = claimRequests[_nonce];
        if (claimed[claim.tokenId]) {
            revert AlreadyClaimed(claim.tokenId);
        }
        if (owner != claim.sender) {
            revert NotOwnerOfToken(claim.sender, claim.tokenId);
        }
        delete claimRequests[_nonce];
        claimed[claim.tokenId] = true;
        emit AirdropClaimed(owner, claim.tokenId);
        _giveAirdrop(owner, claim.tokenId);
    }

    function _giveAirdrop(address _owner, uint256 _tokenId) internal virtual;
}
