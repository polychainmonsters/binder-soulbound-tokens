// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Randomness is Initializable {
    event RandomnessRequestEvent(uint128 id, uint24 duration);

    struct RandomnessRequest {
        uint256 commitEndtime;
    }

    uint128 idCounter;

    mapping(uint128 => RandomnessRequest) public idToRequest;
    mapping(uint128 => uint256) public idToRandomness;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {}

    function requestRandomness(uint24 duration) public returns (uint128) {
        require(duration <= 1 days, "duration too long");

        uint256 commitEndtime = block.timestamp + duration;
        idToRequest[++idCounter] = RandomnessRequest({
            commitEndtime: commitEndtime
        });

        emit RandomnessRequestEvent(idCounter, duration);
        return idCounter;
    }

    function commitRandomness(uint128 id, uint256 randomness) public {
        require(idToRequest[id].commitEndtime != 0, "request does not exist");
        require(
            block.timestamp <= idToRequest[id].commitEndtime,
            "commit period over"
        );

        idToRandomness[id] = randomness;
    }
}
