// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Randomness is Initializable {
    event RandomnessRequestEvent(uint128 id, uint24 duration);

    struct RandomnessRequest {
        uint256 commitEndtime;
        uint24 duration;
    }

    uint128 idCounter;

    mapping(uint128 => RandomnessRequest) public idToRequest;
    mapping(uint128 => uint256) public idToRandomness;
    mapping(uint128 => mapping(uint256 => uint8))
        public idToRandomnessHashExists;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {}

    function requestRandomness(uint24 duration) public returns (uint128) {
        require(duration <= 1 days, "duration too long");

        uint256 commitEndtime = block.timestamp + duration;
        idToRequest[++idCounter] = RandomnessRequest({
            commitEndtime: commitEndtime,
            duration: duration
        });

        emit RandomnessRequestEvent(idCounter, duration);
        return idCounter;
    }

    function commitRandomness(uint128 id, uint256 randomnessHash) public {
        require(idToRequest[id].commitEndtime != 0, "request does not exist");
        require(
            block.timestamp <= idToRequest[id].commitEndtime,
            "commit period over"
        );

        require(
            idToRandomnessHashExists[id][randomnessHash] == 0,
            "already committed"
        );

        idToRandomnessHashExists[id][randomnessHash] = 1;
    }

    function revealRandomness(uint128 id, uint256 randomness) public {
        RandomnessRequest memory request = idToRequest[id];

        require(request.commitEndtime != 0, "request does not exist");
        require(
            block.timestamp > request.commitEndtime,
            "commit period not over"
        );

        require(
            block.timestamp <= request.commitEndtime + request.duration,
            "reveal period is over"
        );

        // the randomness should actually fit the hash
        require(
            idToRandomnessHashExists[id][hash(randomness)] == 1,
            "randomness hash does not exist"
        );

        // if there is no randomness yet, set it. Otherwise combine it with the newly committed randomness
        if (idToRandomness[id] == 0) {
            idToRandomness[id] = randomness;
        } else {
            idToRandomness[id] = combineRandomness(
                idToRandomness[id],
                randomness
            );
        }
    }

    function hash(uint256 randomness) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(randomness)));
    }

    function combineRandomness(
        uint256 randomness1,
        uint256 randomness2
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(randomness1, randomness2)));
    }
}