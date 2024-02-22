// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleStaking is Initializable, OwnableUpgradeable {
    /// @dev ID is the binder battles ID
    event Staked(address indexed user, uint256 indexed id, uint256 amount);
    event Unstaked(address indexed user, uint256 indexed id, uint256 amount);

    enum StakingStatus {
        NotStaked,
        Staked
    }

    struct StakingState {
        StakingStatus status;
        uint256 stakedAt;
    }

    mapping(address => StakingState) public stakingState;
    mapping(uint256 => address) public userAddress;

    uint256 public constant STAKING_AMOUNT = 111;
    uint256 public constant STAKING_LOCK = 1 hours;

    IERC20 public stakingToken;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _stakingToken) public initializer {
        __Ownable_init(msg.sender);

        stakingToken = IERC20(_stakingToken);
    }

    function stake(uint256 id) public {
        require(
            stakingState[msg.sender].status == StakingStatus.NotStaked,
            "Already staked"
        );
        require(userAddress[id] == address(0), "Already staked");

        stakingState[msg.sender] = StakingState({
            status: StakingStatus.Staked,
            stakedAt: block.timestamp
        });

        stakingToken.transferFrom(msg.sender, address(this), STAKING_AMOUNT);

        emit Staked(msg.sender, id, STAKING_AMOUNT);
    }

    function unstake(uint256 id) public {
        require(
            stakingState[msg.sender].status == StakingStatus.Staked,
            "Not staked"
        );
        require(
            block.timestamp - stakingState[msg.sender].stakedAt > STAKING_LOCK,
            "Staking is locked"
        );
        require(
            userAddress[id] == msg.sender,
            "Not yours"
        );

        stakingState[msg.sender].status = StakingStatus.NotStaked;
        stakingToken.transfer(msg.sender, STAKING_AMOUNT);

        emit Unstaked(msg.sender, id, STAKING_AMOUNT);
    }
}
