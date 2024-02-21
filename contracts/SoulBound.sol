// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

// enumerable

contract Soulbound is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721BurnableUpgradeable,
    OwnableUpgradeable
{
    struct Token {
        uint224 points;
        uint16 rank;
        uint16 week;
    }

    enum MintingStatus {
        NotMinted,
        Minted
    }

    uint256 private _nextTokenId;

    mapping(uint256 => Token) public tokenIdToToken;
    mapping(uint16 => bytes32) public weekToRoot;
    mapping(uint16 => mapping(uint16 => MintingStatus))
        public weekToRankToMintingStatus;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC721_init("Polymon Binder Battles", "PMBB");
        __ERC721Enumerable_init();
        __ERC721Burnable_init();
        __Ownable_init(msg.sender);
    }

    /** MERKLE TREE ROOTS*/
    function addWeeklyRoot(bytes32 root, uint16 week) public onlyOwner {
        require(weekToRoot[week] == 0, "already set");
        weekToRoot[week] = root;
    }

    function removeWeeklyRoot(uint16 week) public onlyOwner {
        delete weekToRoot[week];
    }

    function _verify(
        bytes32[] memory proof,
        bytes32 root,
        address to,
        Token memory token
    ) internal pure {
        bytes32 leaf = keccak256(
            bytes.concat(
                keccak256(abi.encode(to, token.points, token.rank, token.week))
            )
        );
        require(MerkleProof.verify(proof, root, leaf), "Invalid proof");
    }

    /** MINTING */

    function mint(
        address to,
        Token memory token,
        bytes32[] memory proof
    ) public {
        require(
            weekToRankToMintingStatus[token.week][token.rank] ==
                MintingStatus.NotMinted,
            "Token already minted"
        );

        _verify(proof, weekToRoot[token.week], to, token);

        tokenIdToToken[_nextTokenId] = token;
        weekToRankToMintingStatus[token.week][token.rank] = MintingStatus
            .Minted;

        _mint(to, _nextTokenId);

        _nextTokenId++;
    }

    /** TOKEN URI */

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        Token memory token = tokenIdToToken[tokenId];
        string memory attributes = string(
            abi.encodePacked(
                "[",
                '{"trait_type":"Rank", "value":"',
                Strings.toString(token.rank),
                '"},',
                '{"trait_type":"Points", "value":"',
                Strings.toString(token.points),
                '"},',
                '{"trait_type":"Week", "value":"',
                Strings.toString(token.week),
                '"}',
                "]"
            )
        );

        // Building the JSON metadata string without animationUrl
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name":"',
                        Strings.toString(tokenId),
                        '", "image":"',
                        '"https://drive.polychainmonsters.com/ipfs/QmeCdu2ZCWB9SmW6DMqYXXLdkJEbNHbQ8gYewJSxsw5zoL"',
                        '", "attributes":',
                        attributes,
                        "}"
                    )
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    /** ERC721 OVERRIDES */

    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
