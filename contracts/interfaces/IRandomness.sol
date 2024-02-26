// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IRandomness {
    function requestRandomness(
        uint24 duration,
        uint24 amount
    ) external returns (uint128);
    function readRandomness(
        uint128 id
    ) external view returns (uint256[] memory);
}
