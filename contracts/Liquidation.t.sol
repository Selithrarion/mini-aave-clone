// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MockERC20} from "./mocks/MockERC20.sol";
import {AToken} from "./AToken.sol";
import {LendingPoolSetup} from "./LendingPoolSetup.t.sol";

abstract contract LiquidationTest is LendingPoolSetup {
	function setUp() public override {
		super.setUp();
	}

	function test_Positive_HealthFactorCalculation() public {
		uint256 depositAmount = 1 * lendingPool.WAD();
		uint256 borrowAmount = 1000 * lendingPool.WAD();

		vm.startPrank(alice);
		weth.approve(address(lendingPool), depositAmount);
		lendingPool.deposit(address(weth), depositAmount);
		lendingPool.borrow(address(dai), borrowAmount);
		vm.stopPrank();

		(, , , uint256 healthFactor) = lendingPool.getUserAccountData(alice);

		uint256 expectedHealthFactor = (17 * lendingPool.WAD()) / 10;
		assertApproxEqAbs(healthFactor, expectedHealthFactor, 1e10, "Health factor should be correct");
	}

	function test_Negative_LiquidationOfHealthyAccount() public {
		test_Positive_HealthFactorCalculation();

		address bob = makeAddr("bob");
		vm.startPrank(bob);

		vm.expectRevert(HealthFactorIsGood.selector);
		lendingPool.liquidate(address(weth), address(dai), alice, 500 * lendingPool.WAD());

		vm.stopPrank();
	}

	function test_Positive_Liquidation() public {
		test_Positive_HealthFactorCalculation();

		priceOracle.setAssetPrice(address(weth), 1000 * lendingPool.ORACLE_PRECISION());

		(, , , uint256 healthFactor) = lendingPool.getUserAccountData(alice);
		assertTrue(healthFactor < lendingPool.WAD(), "Health factor should be below 1");

		address bob = makeAddr("bob");
		uint256 debtToCover = 500 * lendingPool.WAD();
		dai.mint(bob, debtToCover);

		uint256 bobDaiBalance_before = dai.balanceOf(bob);
		uint256 bobWethBalance_before = weth.balanceOf(bob);
		uint256 aliceDebt_before = lendingPool.getUserBorrowBalance(alice, address(dai));

		vm.startPrank(bob);
		dai.approve(address(lendingPool), debtToCover);
		lendingPool.liquidate(address(weth), address(dai), alice, debtToCover);
		vm.stopPrank();

		uint256 bobDaiBalance_after = dai.balanceOf(bob);
		uint256 bobWethBalance_after = weth.balanceOf(bob);
		uint256 aliceDebt_after = lendingPool.getUserBorrowBalance(alice, address(dai));

		assertApproxEqAbs(aliceDebt_after, aliceDebt_before - debtToCover, 1, "Alice's debt should decrease");
		assertEq(bobDaiBalance_after, bobDaiBalance_before - debtToCover, "Bob should have spent his DAI");
		uint256 expectedCollateral = (525 * lendingPool.WAD()) / 1000;
		assertApproxEqAbs(
			bobWethBalance_after,
			bobWethBalance_before + expectedCollateral,
			1e12,
			"Bob should receive collateral with a bonus"
		);
	}

	function test_Positive_HealthFactor_WithMultipleAssets() public {
		MockERC20 uni = new MockERC20("Uniswap", "UNI");
		priceOracle.setAssetPrice(address(uni), 10 * lendingPool.ORACLE_PRECISION()); // UNI = $10
		AToken aUni = new AToken(address(lendingPool), address(uni), "aUNI", "aUNI");
		lendingPool.addAsset(address(uni), address(aUni), 5000, 6000, 11000); // LTV 50%, Threshold 60%

		vm.startPrank(alice);
		weth.approve(address(lendingPool), 1 * lendingPool.WAD());
		lendingPool.deposit(address(weth), 1 * lendingPool.WAD());

		uni.mint(alice, 100 * lendingPool.WAD());
		uni.approve(address(lendingPool), 100 * lendingPool.WAD());
		lendingPool.deposit(address(uni), 100 * lendingPool.WAD());

		lendingPool.borrow(address(dai), 1000 * lendingPool.WAD());
		lendingPool.borrow(address(weth), lendingPool.WAD() / 10); // 0.1 WETH
		vm.stopPrank();

		(uint256 totalCollateral, uint256 totalDebt, , uint256 healthFactor) = lendingPool.getUserAccountData(alice);

		uint256 expectedTotalCollateral = 3000 * lendingPool.WAD();
		uint256 expectedTotalDebt = 1200 * lendingPool.WAD(); // $1000 (DAI) + $200 (WETH)
		assertApproxEqAbs(totalCollateral, expectedTotalCollateral, 1, "Total collateral should be $3000");
		assertApproxEqAbs(totalDebt, expectedTotalDebt, 1, "Total debt should be $1200");

		uint256 weightedCollateral = ((2000 * 8500 + 1000 * 6000) * lendingPool.WAD()) / 10000;
		uint256 expectedHealthFactor = (weightedCollateral * lendingPool.WAD()) / expectedTotalDebt;
		assertApproxEqAbs(healthFactor, expectedHealthFactor, 1e10, "Complex health factor should be correct");
	}
}
