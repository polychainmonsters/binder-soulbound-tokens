// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";

contract Soulbound is
    Initializable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    OwnableUpgradeable
{
    struct Token {
        uint240 points;
        uint16 rank;
    }

    uint256 private _nextTokenId;

    mapping(uint256 => Token) public tokenIdToToken;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC721_init("Polymon Binder Battles", "PMBB");
        __ERC721Burnable_init();
        __Ownable_init(msg.sender);
    }

    function mint(
        address[] memory to,
        uint240[] memory points,
        uint16[] memory ranks
    ) public onlyOwner {
        require(
            to.length == points.length && to.length == ranks.length,
            "Invalid input"
        );

        uint256 tokenId = _nextTokenId;
        for (uint256 i = 0; i < to.length; i++) {
            tokenIdToToken[tokenId + i] = Token({
                points: points[i],
                rank: ranks[i]
            });
            _mint(to[i], tokenId + i);
        }
        _nextTokenId += to.length;
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
}
