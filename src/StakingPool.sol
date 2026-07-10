// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingPool is ReentrancyGuard, Ownable{

    using SafeERC20 for IERC20;
    IERC20 public immutable stakingToken;
    uint256 public rewardRate;
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;
    uint256 public totalSupply;
    uint256 public rewardPool;

    mapping(address => uint256) public rewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public balances;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event RewardFunded(uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    
    constructor(address _stakingToken) Ownable(_msgSender()) {
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
    stakingToken.safeTransferFrom(msg.sender, address(this), amount);
    rewardPool += amount;
    emit RewardFunded(amount);
    }
    function rewardPerToken() public view returns(uint256) {
        if(totalSupply == 0) return rewardPerTokenStored;
        return rewardPerTokenStored +
        (((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalSupply);
    }
    function earned(address account) public view returns(uint256) {
        return ((balances[account] *
        (rewardPerToken() - rewardPerTokenPaid[account])) / 1e18) + rewards[account];
    }
    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Amount must be > 0");
        totalSupply += amount;
        balances[msg.sender] += amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }
    function withdraw(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0 && balances[msg.sender] >= amount, "Invalid amount");
        totalSupply -= amount;
        balances[msg.sender] -= amount;
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }
    function claimReward() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No reward to claim.");
        rewards[msg.sender] = 0;
        require(rewardPool >= reward, "Insufficient reward pool");
        rewardPool -= reward;
        stakingToken.safeTransfer(msg.sender, reward);
        emit RewardClaimed(msg.sender, reward);
    }
    function setRate(uint256 _rate) external onlyOwner updateReward(address(0)) {
        uint256 oldRate = rewardRate;
        rewardRate = _rate;
        emit RewardRateUpdated(oldRate, _rate);
    }
}