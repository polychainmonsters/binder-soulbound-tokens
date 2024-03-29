// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import {IRandomness} from "./interfaces/IRandomness.sol";

contract Soulbound is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721BurnableUpgradeable,
    OwnableUpgradeable
{
    using Checkpoints for Checkpoints.Trace208;

    Checkpoints.Trace208 private _totalCumulativePoints;
    mapping(uint16 => Checkpoints.Trace208) private _weeklyCumulativePoints;

    struct Token {
        uint48 points;
        uint16 rank;
        uint16 week;
    }

    // @todo: a bit unnecessary to have a struct here but not so imporant at the current state
    struct PointsPick {
        uint48 totalPoints;
        uint128 randomnessRequestId;
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

    IRandomness public randomness;
    uint24 public randomnessRequestLength; // the duration for the randomness generation

    PointsPick[] internal _totalPointsPicks;
    mapping(uint16 => PointsPick[]) internal _weeklyPointsPicks;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(IRandomness _randomness) public initializer {
        __ERC721_init("Polymon Binder Battles", "PMBB");
        __ERC721Enumerable_init();
        __ERC721Burnable_init();
        __Ownable_init(msg.sender);

        randomness = _randomness;
        randomnessRequestLength = 15 minutes;
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

        _push(_totalCumulativePoints, _nextTokenId, token.points);
        _push(_weeklyCumulativePoints[token.week], _nextTokenId, token.points);

        _mint(to, _nextTokenId);

        _nextTokenId++;
    }

    /** POINTS */

    // see https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.1/contracts/governance/utils/Votes.sol

    function _push(
        Checkpoints.Trace208 storage store,
        uint256 tokenId,
        uint48 deltaPoints
    ) private returns (uint208, uint208) {
        // push(key, value)
        // we use the cumulative points as key
        (, uint48 _newestKey, ) = store.latestCheckpoint();
        return
            store.push(_newestKey + deltaPoints, SafeCast.toUint208(tokenId));
    }

    function upperLookupTotal(uint48 searchKey) public view returns (uint208) {
        return _upperLookup(_totalCumulativePoints, searchKey);
    }

    function upperLookupWeekly(
        uint48 searchKey,
        uint16 week
    ) public view returns (uint208) {
        return _upperLookup(_weeklyCumulativePoints[week], searchKey);
    }

    function _upperLookup(
        Checkpoints.Trace208 storage store,
        uint48 searchKey
    ) internal view returns (uint208) {
        (, uint48 _newestKey, ) = store.latestCheckpoint();
        require(searchKey <= _newestKey, "searchKey too high");
        return store.lowerLookup(searchKey);
    }

    /** PICK */

    function requestTotalPointsPick(uint24 amount) public onlyOwner {
        _requestPick(_totalCumulativePoints, _totalPointsPicks, amount);
    }

    function requestWeeklyPointsPick(
        uint16 week,
        uint24 amount
    ) public onlyOwner {
        _requestPick(
            _weeklyCumulativePoints[week],
            _weeklyPointsPicks[week],
            amount
        );
    }

    function _requestPick(
        Checkpoints.Trace208 storage store,
        PointsPick[] storage picks,
        uint24 amount
    ) internal {
        (, uint48 _newestKey, ) = store.latestCheckpoint();
        picks.push(
            PointsPick(
                _newestKey,
                randomness.requestRandomness(randomnessRequestLength, amount)
            )
        );
    }

    function readTotalPointsPick(
        uint256 pickIndex
    ) public view returns (uint48, uint128) {
        return (
            _totalPointsPicks[pickIndex].totalPoints,
            _totalPointsPicks[pickIndex].randomnessRequestId
        );
    }

    function readWeeklyPointsPick(
        uint16 week,
        uint256 pickIndex
    ) public view returns (uint48, uint128) {
        return (
            _weeklyPointsPicks[week][pickIndex].totalPoints,
            _weeklyPointsPicks[week][pickIndex].randomnessRequestId
        );
    }

    /** WINNERS */

    function getNumOfWeeklyPicks(uint16 week) public view returns (uint256) {
        return _weeklyPointsPicks[week].length;
    }

    function getNumOfTotalPicks() public view returns (uint256) {
        return _totalPointsPicks.length;
    }

    function getWeeklyWinnerAtIndex(
        uint16 week,
        uint256 pickIndex,
        uint256 winnerIndex
    ) public view returns (uint256, address) {
        uint256 tokenId = upperLookupWeekly(
            _getRandomIndex(_weeklyPointsPicks[week], pickIndex, winnerIndex),
            week
        );
        return (tokenId, ownerOf(tokenId));
    }

    function getTotalWinnerAtIndex(
        uint256 pickIndex,
        uint256 winnerIndex
    ) public view returns (uint256, address) {
        uint256 tokenId = upperLookupTotal(
            _getRandomIndex(_totalPointsPicks, pickIndex, winnerIndex)
        );
        return (tokenId, ownerOf(tokenId));
    }

    function _getRandomIndex(
        PointsPick[] storage picks,
        uint256 pickIndex, // index of the pick
        uint256 winnerIndex // index of the winner
    ) internal view returns (uint48) {
        PointsPick memory pick = picks[pickIndex];
        uint256[] memory randomnessValues = randomness.readRandomness(
            pick.randomnessRequestId
        );
        return uint48(randomnessValues[winnerIndex] % pick.totalPoints);
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

    /** ADMIN SETTERS */

    function setRandomness(IRandomness _randomness) public onlyOwner {
        randomness = _randomness;
    }

    function setRandomnessRequestLength(
        uint24 _randomnessRequestLength
    ) public onlyOwner {
        randomnessRequestLength = _randomnessRequestLength;
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
