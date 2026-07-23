// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

error ZeroAmount();
error ZeroAddress();
error NoRewardsToClaim();
error RateTooHigh(uint256 maxRate);
error InsufficientRewardPool(uint256 available, uint256 required);
error InsufficientStakedBalance(uint256 balance, uint256 requested);
error RescueAmountExceedsAvailable(uint256 available, uint256 requested);

contract StakingPool is ReentrancyGuard, AccessControl, Pausable {
    event RewardFunded(uint256 amount);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant RESCUER_ROLE = keccak256("RESCUER_ROLE");
    bytes32 public constant TREASURY_ROLE  = keccak256("TREASURY_ROLE");
    bytes32 public constant RATE_MANAGER_ROLE = keccak256("RATE_MANAGER_ROLE");

    using SafeERC20 for IERC20;
    IERC20 public immutable stakingToken;
    uint256 public rewardRate;
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;
    uint256 public totalSupply;
    uint256 public rewardPool;
    uint256 private constant PRECISION = 1e18;
    uint256 public constant MAX_REWARD_RATE = 5 ether;

    mapping(address => uint256) public rewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public balances;

    constructor(address _stakingToken) {
        if (_stakingToken == address(0)) {
            revert ZeroAddress();
        }
        stakingToken = IERC20(_stakingToken);
        lastUpdateTime = block.timestamp;

        address admin = _msgSender();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(RESCUER_ROLE, admin);
        _grantRole(TREASURY_ROLE, admin);
        _grantRole(RATE_MANAGER_ROLE, admin);
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earned(account);
            rewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function fundRewards(uint256 amount) external onlyRole(TREASURY_ROLE) {
        if (amount == 0) {
            revert ZeroAmount();
        }
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        rewardPool += amount;
        emit RewardFunded(amount);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) return rewardPerTokenStored;
        return rewardPerTokenStored + (((block.timestamp - lastUpdateTime) * rewardRate * PRECISION) / totalSupply);
    }

    function earned(address account) public view returns (uint256) {
        return ((balances[account] * (rewardPerToken() - rewardPerTokenPaid[account])) / PRECISION) + rewards[account];
    }

    function _stake(address user, uint256 amount) internal updateReward(user) {
        if (amount == 0) {
            revert ZeroAmount();
        }
        totalSupply += amount;
        balances[user] += amount;
        stakingToken.safeTransferFrom(user, address(this), amount);
        emit Staked(user, amount);
    }

    function stake(uint256 amount) external nonReentrant whenNotPaused {
        _stake(msg.sender, amount);
        
    }

    function _withdraw(address user, uint256 amount) internal updateReward(user) {
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (amount > balances[user]) {
            revert InsufficientStakedBalance(balances[user], amount);
        }
        unchecked {
            totalSupply -= amount;
            balances[user] -= amount;
        }
        stakingToken.safeTransfer(user, amount);
        emit Withdrawn(user, amount);
    }

    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        _withdraw(msg.sender, amount);
    }

    function _claimReward(address user) internal updateReward(user) {
        uint256 reward = rewards[user];
        if (reward == 0) {
            revert NoRewardsToClaim();
        }
        rewards[user] = 0;
        if (reward > rewardPool) {
            revert InsufficientRewardPool(rewardPool, reward);
        }
        unchecked {
            rewardPool -= reward;
        }
        stakingToken.safeTransfer(user, reward);
        emit RewardClaimed(user, reward);
    }

    function claimReward() external nonReentrant whenNotPaused {
        _claimReward(msg.sender);
    }

    function setRate(uint256 _rate) external onlyRole(RATE_MANAGER_ROLE) whenNotPaused updateReward(address(0)) {
        if (_rate > MAX_REWARD_RATE) {
            revert RateTooHigh(MAX_REWARD_RATE);
        }
        uint256 oldRate = rewardRate;
        rewardRate = _rate;
        emit RewardRateUpdated(oldRate, _rate);
    }

    function rescueTokens(address token, uint256 amount) external onlyRole(RESCUER_ROLE) {
        if (token == address(0)) {
            revert ZeroAddress();
        }
        IERC20 rescueToken = IERC20(token);
        if (token == address(stakingToken)) {
            uint256 rescueable =
                rescueToken.balanceOf(address(this)) - totalSupply - rewardPool;
            if (amount > rescueable) {
                revert RescueAmountExceedsAvailable(rescueable, amount);
            }
        }
        rescueToken.safeTransfer(msg.sender, amount);
    }

    function getUserInfo(address user)
        external
        view
        returns (uint256 staked, uint256 pendingReward, uint256 rewardPerTokenPaid_)
    {
        staked = balances[user];
        pendingReward = earned(user);
        rewardPerTokenPaid_ = rewardPerTokenPaid[user];
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
