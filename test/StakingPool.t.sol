// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StakingPool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract stakingPoolTest is Test {
    MockERC20 public token;
    StakingPool pool;
    address owner = address(1);
    address alice = address(2);
    address bob = address(3);

    function setUp() public {
        vm.startPrank(owner);
        token = new MockERC20();
        pool = new StakingPool(address(token));
        token.mint(owner, 1000e18);
        pool.setRate(1e18);
        vm.stopPrank();

        token.mint(alice, 1000e18);
        token.mint(bob, 1000e18);

        vm.prank(owner);
        token.approve(address(pool), type(uint256).max);
        vm.prank(alice);
        token.approve(address(pool), type(uint256).max);
        vm.prank(bob);
        token.approve(address(pool), type(uint256).max);

        vm.startPrank(owner);
        pool.grantRole(pool.DEFAULT_ADMIN_ROLE(), owner);
        pool.grantRole(pool.RESCUER_ROLE(), bob);
        pool.grantRole(pool.PAUSER_ROLE(), alice);
        pool.grantRole(pool.TREASURY_ROLE(), owner);
        pool.grantRole(pool.RATE_MANAGER_ROLE(), owner);
        vm.stopPrank();
    }

    //ُStake tests
    function testStake() public {
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit StakingPool.Staked(address(alice), 100e18);
        pool.stake(100e18);
        assertEq(pool.balances(alice), 100e18);
        assertEq(pool.totalSupply(), 100e18);
        assertEq(token.balanceOf(alice), 900e18);
        assertEq(token.balanceOf(address(pool)), 100e18);
    }

    function testStakeZero() public {
        vm.prank(alice);
        vm.expectRevert(ZeroAmount.selector);
        pool.stake(0);
    }

    function testStakeWithoutApprove() public {
        address Charlie = address(4);
        token.mint(Charlie, 1000e18);
        vm.prank(Charlie);
        vm.expectRevert();
        pool.stake(100e18);
    }

    function testStakeWithoutBalance() public {
        address David = address(5);
        vm.startPrank(David);
        token.approve(address(pool), 1000e18);
        vm.expectRevert();
        pool.stake(100e18);
        vm.stopPrank();
    }

    //Withdraw tests
    function testWithdraw() public {
        vm.startPrank(alice);
        vm.expectEmit(true, false, false, true);
        emit StakingPool.Staked(address(alice), 100e18);
        pool.stake(100e18);
        vm.expectEmit(true, false, false, true);
        emit StakingPool.Withdrawn(address(alice), 40e18);
        pool.withdraw(40e18);
        vm.stopPrank();
        vm.assertEq(pool.balances(alice), 60e18);
        vm.assertEq(pool.totalSupply(), 60e18);
        vm.assertEq(token.balanceOf(alice), 940e18);
        vm.assertEq(token.balanceOf(address(pool)), 60e18);
    }

    function testWithdrawZero() public {
        vm.startPrank(alice);
        pool.stake(100e18);
        vm.expectRevert(ZeroAmount.selector);
        pool.withdraw(0);
        vm.stopPrank();
    }

    function testWithdrawMoreThanBalance() public {
        vm.startPrank(alice);
        pool.stake(100e18);
        vm.expectRevert(abi.encodeWithSelector(InsufficientStakedBalance.selector, 100e18, 200e18));
        pool.withdraw(200e18);
        vm.stopPrank();
    }

    //rewardPerToken tests
    function testRewardPerToken() public {
        vm.prank(alice);
        pool.stake(100e18);
        vm.warp(block.timestamp + 10);
        uint256 reward = pool.rewardPerToken();
        uint256 expectedReward = (10 * 1e18 * 1e18) / (100e18);
        assertEq(reward, expectedReward);
    }

    //earned tests
    function testEarned() public {
        vm.prank(alice);
        pool.stake(100e18);
        vm.warp(block.timestamp + 10);
        uint256 reward = pool.earned(alice);
        assertEq(reward, 10e18);
    }

    function testEarnedWithoutStake() public view {
        vm.assertEq(pool.earned(alice), 0);
    }

    function testEarnedImmediatelyAfterStake() public {
        vm.prank(alice);
        pool.stake(100e18);
        vm.assertEq(pool.earned(alice), 0);
    }

    function testEarnedTwoUsersEqualStake() public {
        vm.prank(alice);
        pool.stake(100e18);

        vm.prank(bob);
        pool.stake(300e18);
        vm.warp(block.timestamp + 10);
        uint256 aliceReward = pool.earned(alice);
        uint256 bobReward = pool.earned(bob);
        vm.assertEq(aliceReward, 25e17);
        vm.assertEq(bobReward, 75e17);
    }

    //ClaimReward tests
    function testClaimReward() public {
        vm.prank(owner);
        pool.fundRewards(500e18);
        vm.prank(alice);
        pool.stake(100e18);
        vm.warp(block.timestamp + 10);
        uint256 reward = pool.earned(alice);
        vm.expectEmit(true, false, false, true);
        emit StakingPool.RewardClaimed(address(alice), reward);
        vm.prank(alice);
        pool.claimReward();
        assertEq(token.balanceOf(alice), 900e18 + reward);
        assertEq(pool.rewards(alice), 0);
    }

    function testClaimRewardTwice() public {
        vm.prank(alice);
        pool.stake(100e18);
        vm.prank(owner);
        pool.fundRewards(500e18);
        vm.warp(block.timestamp + 10);
        vm.prank(alice);
        pool.claimReward();
        assertEq(pool.rewards(alice), 0);
        vm.prank(alice);
        vm.expectRevert(NoRewardsToClaim.selector);
        pool.claimReward();
    }

    function testClaimWithoutReward() public {
        vm.prank(owner);
        pool.fundRewards(500e18);
        vm.prank(alice);
        vm.expectRevert(NoRewardsToClaim.selector);
        pool.claimReward();
    }

    function testClaimAfterMultipleStakes() public {
        vm.prank(alice);
        pool.stake(100e18);
        vm.warp(block.timestamp + 10);
        vm.prank(alice);
        pool.stake(100e18);
        vm.prank(owner);
        pool.fundRewards(500e18);
        vm.warp(block.timestamp + 10);
        vm.prank(alice);
        pool.claimReward();
        assertEq(token.balanceOf(alice), 820e18);
        assertEq(pool.balances(alice), 200e18);
        assertEq(pool.totalSupply(), 200e18);
        assertEq(pool.rewards(alice), 0);
    }

    function testClaimRewardInsufficientPool() public {
        vm.prank(alice);
        pool.stake(100e18);
        vm.warp(block.timestamp + 10);
        vm.expectRevert(abi.encodeWithSelector(InsufficientRewardPool.selector, 0, 10e18));
        vm.prank(alice);
        pool.claimReward();
    }

    //SetRate tests
    function testSetRateByOwner() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit StakingPool.RewardRateUpdated(1e18, 2e18);
        pool.setRate(2e18);
        vm.assertEq(pool.rewardRate(), 2e18);
    }

    function testSetRate() public {
        vm.prank(alice);
        vm.expectRevert();
        pool.setRate(2e18);
    }

    //FundReward tests
    function testFundRewards() public {
        vm.startPrank(owner);
        vm.expectEmit(false, false, false, true);
        emit StakingPool.RewardFunded(200e18);
        pool.fundRewards(200e18);
        assertEq(pool.rewardPool(), 200e18);
        assertEq(token.balanceOf(owner), 800e18);
        assertEq(token.balanceOf(address(pool)), 200e18);
        vm.stopPrank();
    }

    function testFundRewardsRevertIfNotOwner() public {
        vm.startPrank(alice);
        vm.expectRevert();
        pool.fundRewards(100e18);
        vm.stopPrank();
    }

    function testFundRewardsZero() public {
        vm.prank(owner);
        vm.expectRevert(ZeroAmount.selector);
        pool.fundRewards(0);
    }

    //Constructor tests
    function testConstructorZeroAddress() public {
        vm.expectRevert(ZeroAddress.selector);
        new StakingPool(address(0));
    }

    //Pause tests
    function testCannotStakeWhenPaused() public {
        vm.prank(owner);
        pool.pause();
        vm.prank(alice);
        vm.expectRevert();
        pool.stake(100e18);
    }

    function testOwnerCanPause() public {
        vm.prank(owner);
        pool.pause();
        assertTrue(pool.paused());
    }

    //AccessControl tests
    function testOnlyRateManagerCanSetRate() public {
        vm.prank(owner);
        pool.setRate(2e18);
        vm.assertEq(pool.rewardRate(), 2e18);
        vm.prank(alice);
        vm.expectRevert();
        pool.setRate(2e18);
    }

    function testPauserCanPause() public {
        vm.prank(alice);
        pool.pause();
        assertTrue(pool.paused());
    }
    function testPauserCanUnPause() public {
        vm.startPrank(alice);
        pool.pause();
        pool.unpause();
        assertFalse(pool.paused());
        vm.stopPrank();
    }
    function testNonPauserCannotPause() public {
        vm.prank(bob);
        vm.expectRevert();
        pool.pause();
    }

    function testNonPauserCannotUnPause() public {
        vm.prank(alice);
        pool.pause();
        vm.prank(bob);
        vm.expectRevert();
        pool.unpause();
    }
    
    function testOnlyRescuerCanRescueToken() public {
        vm.prank(owner);
        assertTrue(token.transfer(address(pool), 100e18));
        assertEq(token.balanceOf(address(pool)),100e18);
        vm.startPrank(bob);
        pool.rescueTokens(address(token), 100e18);
        vm.assertEq(token.balanceOf(address(pool)), pool.totalSupply() + pool.rewardPool());
        vm.stopPrank();
    }
    
    function testNonRescuerCannotRescueToken() public {
        vm.prank(owner);
        assertTrue(token.transfer(address(pool), 100e18));
        vm.prank(alice);
        vm.expectRevert();
        pool.rescueTokens(address(token), 100e18);
    }

    function testOnlyTreasuryCanFundRewards() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit StakingPool.RewardFunded(200e18);
        pool.fundRewards(200e18);
        assertEq(pool.rewardPool(), 200e18);
        vm.prank(alice);
        vm.expectRevert();
        pool.fundRewards(100e18);
    }

    function testPauserRenounceRole() public {
        vm.startPrank(alice);
        pool.renounceRole(pool.PAUSER_ROLE(), alice);
        assertFalse(pool.hasRole(pool.PAUSER_ROLE(), alice));
        vm.expectRevert();
        pool.pause();
        vm.stopPrank();
    }
    function testRescuerRevokeRole() public {
        vm.startPrank(owner);
        assertTrue(token.transfer(address(pool), 100e18));
        pool.revokeRole(pool.RESCUER_ROLE(), bob);
        vm.stopPrank();
        vm.prank(bob);
        vm.expectRevert();
        pool.rescueTokens(address(token), 100e18);
    }
    function testGrantRateManagerRole() public {
        assertTrue(pool.hasRole(pool.DEFAULT_ADMIN_ROLE(), owner));
        vm.startPrank(owner);
        pool.grantRole(pool.RATE_MANAGER_ROLE(), alice);
        vm.stopPrank();
        vm.prank(alice);
        pool.setRate(2e18);
        assertEq(pool.rewardRate(), 2e18);
    }
}
