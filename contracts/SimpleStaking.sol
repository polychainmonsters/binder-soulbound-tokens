// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleStaking is Initializable, OwnableUpgradeable {
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);

    enum StakingStatus {
        Staked,
        NotStaked
    }

    struct StakingState {
        StakingStatus status;
        uint256 stakedAt;
    }

    mapping(address => StakingState) public stakingState;

    uint256 public constant STAKING_AMOUNT = 111;
    uint256 public immutable STAKING_LOCK = 90 days;

    IERC20 public immutable stakingToken;

    constructor(IERC20 _stakingToken) {
        _disableInitializers();

        stakingToken = _stakingToken;
    }

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
    }

    function stake() public {
        require(
            stakingState[msg.sender].status == StakingStatus.NotStaked,
            "Already staked"
        );
        stakingState[msg.sender] = StakingState({
            status: StakingStatus.Staked,
            stakedAt: block.timestamp
        });

        stakingToken.transferFrom(msg.sender, address(this), STAKING_AMOUNT);

        emit Staked(msg.sender, STAKING_AMOUNT);
    }

    function unstake() public {
        require(
            stakingState[msg.sender].status == StakingStatus.Staked,
            "Not staked"
        );
        require(
            block.timestamp - stakingState[msg.sender].stakedAt > STAKING_LOCK,
            "Staking is locked"
        );

        stakingState[msg.sender].status = StakingStatus.NotStaked;
        stakingToken.transfer(msg.sender, STAKING_AMOUNT);

        emit Unstaked(msg.sender, STAKING_AMOUNT);
    }
}
