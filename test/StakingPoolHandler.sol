// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StakingPool.sol";
import "../src/MockERC20.sol";

contract StakingPoolHandler is Test {
    StakingPool public immutable pool;
    MockERC20 public immutable token;

    address public owner;

    address[] public actors;
    mapping(address => bool) public isActor;
    mapping(address => uint256) public ghostStakedBalance;
    mapping(address => uint256) public ghostRewardsClaimed;
    uint256 public lastRewardPerTokenStored;
    uint256 public ghostRewardPool;
    bool public isPaused;

    // Ghost Variables
    uint256 public stakeCalls;
    uint256 public withdrawCalls;
    uint256 public claimRewardCalls;
    uint256 public fundRewardCalls;
    uint256 public setRateCalls;
    uint256 public pauseCalls;
    uint256 public unpauseCalls;

    uint256 public totalStaked;
    uint256 public totalWithdrawn;
    uint256 public totalRewardsFunded;
    uint256 public totalRewardsClaimed;

    constructor(StakingPool _pool, MockERC20 _token, address _owner) {
        pool = _pool;
        token = _token;
        owner = _owner;
        _createActors();
        _mintActors();
    }

    modifier syncRewardPerToken() {
        _;
        lastRewardPerTokenStored = pool.rewardPerTokenStored();
    }

    function _createActors() internal {
        _addActor(makeAddr("Alice"));
        _addActor(makeAddr("Bob"));
        _addActor(makeAddr("Charlie"));
        _addActor(makeAddr("David"));
        _addActor(makeAddr("Eve"));
        _addActor(makeAddr("Frank"));
        _addActor(makeAddr("George"));
        _addActor(makeAddr("Henry"));
    }

    function _mintActors() internal {
        for (uint256 i; i < actors.length; i++) {
            token.mint(actors[i], 1_000_000 ether);
        }
    }

    function _addActor(address user) internal {
        if (!isActor[user]) {
            isActor[user] = true;
            actors.push(user);
        }
    }

    function _getActor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function stake(uint256 amount, uint256 userSeed) external syncRewardPerToken {
        if (isPaused) return;
        address user = _getActor(userSeed);
        uint256 balance = token.balanceOf(user);
        if (balance == 0) return;
        amount = bound(amount, 1, balance);

        vm.startPrank(user);
        token.approve(address(pool), amount);
        pool.stake(amount);
        vm.stopPrank();
        stakeCalls++;
        totalStaked += amount;
        ghostStakedBalance[user] += amount;
    }

    function withdraw(uint256 amount, uint256 userSeed) external syncRewardPerToken {
        if (isPaused) return;
        address user = _getActor(userSeed);
        uint256 staked = pool.balances(user);
        if (staked == 0) return;
        amount = bound(amount, 1, staked);

        vm.prank(user);
        pool.withdraw(amount);
        withdrawCalls++;
        totalWithdrawn += amount;
        ghostStakedBalance[user] -= amount;
    }

    function claimReward(uint256 userSeed) external syncRewardPerToken {
        if (isPaused) return;
        address user = _getActor(userSeed);
        if (pool.earned(user) == 0) return;
        vm.prank(user);
        uint256 claimed = pool.earned(user);
        pool.claimReward();
        claimRewardCalls++;
        totalRewardsClaimed += claimed;
        ghostRewardsClaimed[user] += claimed;
        ghostRewardPool -= claimed;
    }

    function fundRewards(uint256 amount) external syncRewardPerToken {
        if (isPaused) return;
        uint256 balance = token.balanceOf(owner);
        if (balance == 0) return;
        amount = bound(amount, 1, balance);

        vm.startPrank(owner);
        token.approve(address(pool), amount);
        pool.fundRewards(amount);
        vm.stopPrank();
        fundRewardCalls++;
        totalRewardsFunded += amount;
        ghostRewardPool += amount;
    }

    function setRate(uint256 rate) external syncRewardPerToken {
        if (isPaused) return;
        rate = bound(rate, 0, 10 ether);
        vm.prank(owner);
        pool.setRate(rate);
        setRateCalls++;
    }

    function pause() public {
        if (isPaused) return;
        vm.prank(owner);
        pool.pause();
        isPaused = true;
        pauseCalls++;
    }

    function unpause() public {
        if (!isPaused) return;
        vm.prank(owner);
        pool.unpause();
        isPaused = false;
        unpauseCalls++;
    }

    function actorsLength() external view returns (uint256) {
        return actors.length;
    }

    function actorAt(uint256 index) external view returns (address) {
        return actors[index];
    }
}
