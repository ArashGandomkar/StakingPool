// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error ZeroAmount();
error ZeroAddress();
error NoRewardsToClaim();
error InsufficientRewardPool(uint256 available, uint256 required);
error InsufficientStakedBalance(uint256 balance, uint256 requested);

contract StakingPool is ReentrancyGuard, Ownable, Pausable {
    event RewardFunded(uint256 amount);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);

    using SafeERC20 for IERC20;
    IERC20 public immutable stakingToken;
    uint256 public rewardRate;
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;
    uint256 public totalSupply;
    uint256 public rewardPool;
    uint256 private constant PRECISION = 1e18;

    mapping(address => uint256) public rewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public balances;

    constructor(address _stakingToken) Ownable(_msgSender()) {
        if (_stakingToken == address(0)) {
            revert ZeroAddress();
        }
        stakingToken = IERC20(_stakingToken);
        lastUpdateTime = block.timestamp;
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

    function fundRewards(uint256 amount) external onlyOwner {
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

    function stake(uint256 amount) external nonReentrant whenNotPaused updateReward(msg.sender) {
        //require(amount > 0, "Amount must be > 0");
        if (amount == 0) {
            revert ZeroAmount();
        }
        totalSupply += amount;
        balances[msg.sender] += amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant whenNotPaused updateReward(msg.sender) {
        //require(amount > 0 && balances[msg.sender] >= amount, "Invalid amount");
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (amount > balances[msg.sender]) {
            revert InsufficientStakedBalance(balances[msg.sender], amount);
        }
        unchecked {
            totalSupply -= amount;
            balances[msg.sender] -= amount;
        }
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function claimReward() external nonReentrant whenNotPaused updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        //require(reward > 0, "No reward to claim.");
        if (reward == 0) {
            revert NoRewardsToClaim();
        }
        rewards[msg.sender] = 0;
        //require(rewardPool >= reward, "Insufficient reward pool");
        if (reward > rewardPool) {
            revert InsufficientRewardPool(rewardPool, reward);
        }
        unchecked {
            rewardPool -= reward;
        }
        stakingToken.safeTransfer(msg.sender, reward);
        emit RewardClaimed(msg.sender, reward);
    }

    function setRate(uint256 _rate) external onlyOwner whenNotPaused updateReward(address(0)) {
        uint256 oldRate = rewardRate;
        rewardRate = _rate;
        emit RewardRateUpdated(oldRate, _rate);
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

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

}
