// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Mock20 is ERC20, Ownable {
    constructor() ERC20("Mock", "MCK") Ownable(msg.sender) {
        _mint(msg.sender, 10_000 ether);
    }
}
