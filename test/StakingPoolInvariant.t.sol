// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";

import "../src/StakingPool.sol";
import "./StakingPoolHandler.sol";
import "../src/MockERC20.sol";

contract StakingPoolInvariant is StdInvariant, Test {

    MockERC20 token;
    StakingPool pool;
    StakingPoolHandler handler;

    address owner = makeAddr("owner");

    function setUp() public {
        vm.startPrank(owner);

        token = new MockERC20();
        pool = new StakingPool(address(token));

        token.mint(owner, 1_000_000 ether);
        token.approve(address(pool), type(uint256).max);
        pool.setRate(1 ether);

        vm.stopPrank();
        handler = new StakingPoolHandler(pool, token, owner);
        targetContract(address(handler));
    }

    function invariant_TotalSupplyMatchesShadowAccounting() public view {
        assertEq(pool.totalSupply(), handler.totalStaked() - handler.totalWithdrawn());
    }

    function invariant_RewardPoolMatchesShadowAccounting() public view {
        assertEq(pool.rewardPool(), handler.ghostRewardPool());
    }

    function invariant_UserBalancesMatchShadowAccounting() public view {
        uint256 length = handler.actorsLength();

        for (uint256 i = 0; i < length; i++) {
            address user = handler.actorAt(i);

            assertEq(pool.balances(user), handler.ghostStakedBalance(user));
        }
    }

    function invariant_RewardPerTokenStoredNeverExceedsCurrent() public view {
        assertLe(
            pool.rewardPerTokenStored(),
            pool.rewardPerToken()
            );
        }

    function invariant_RewardPerTokenNeverDecreases() public view {
        assertGe(
            pool.rewardPerTokenStored(),
            handler.lastRewardPerTokenStored()
        );
    }

    function invariant_PauseStateMatchesHandler() public view {
        assertEq(pool.paused(), handler.isPaused());
    }

    function invariant_TokenConservation() public view {
        uint256 total = token.balanceOf(address(pool));
        uint256 length = handler.actorsLength();

        for (uint256 i = 0; i < length; i++) {
            total += token.balanceOf(handler.actorAt(i));
        }
        total += token.balanceOf(owner);
        assertEq(total, token.totalSupply());
    }

    function invariant_TotalSupplyEqualsAllBalances() public view {
        uint256 sum;
        uint256 length = handler.actorsLength();

        for (uint256 i = 0; i < length; i++) {
            sum += pool.balances(handler.actorAt(i));
        }
        assertEq(sum, pool.totalSupply());
    }

    function invariant_RewardPoolAccounting() public view {
        assertEq(handler.totalRewardsFunded()
        - handler.totalRewardsClaimed(),
        pool.rewardPool());
    }
}