// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LendingPool} from "./LendingPool.sol";
import {AToken} from "./AToken.sol";
import {LendingPoolSetup} from "./LendingPoolSetup.t.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

abstract contract LendingPoolTest is LendingPoolSetup {
	function setUp() public override {
		super.setUp();
	}

	function test_Positive_Deposit() public {
		uint256 depositAmount = 1 * lendingPool.WAD();
		vm.startPrank(alice);
		weth.approve(address(lendingPool), depositAmount);

		vm.expectEmit(true, true, false, true);
		emit Deposit(address(weth), alice, depositAmount);
		lendingPool.deposit(address(weth), depositAmount);
		vm.stopPrank();

		assertApproxEqAbs(aWeth.balanceOf(alice), depositAmount, 1, "Alice should have ~1 aWETH");
		assertEq(weth.balanceOf(address(lendingPool)), depositAmount, "Pool should have 1 WETH");
	}

	function test_Positive_Deposit_UserDepositedAssetsUpdated() public {
		uint256 depositAmount = 1 * lendingPool.WAD();
		vm.startPrank(alice);
		weth.approve(address(lendingPool), depositAmount);
		lendingPool.deposit(address(weth), depositAmount);
		vm.stopPrank();

		assertEq(lendingPool.userDepositedAssets(alice, 0), address(weth), "WETH should be in userDepositedAssets");
	}

	function test_Negative_Deposit_UnsupportedAsset() public {
		MockERC20 unsupported = new MockERC20("Unsupported", "UNS");
		vm.startPrank(alice);
		vm.expectRevert(AssetNotSupported.selector);
		lendingPool.deposit(address(unsupported), 1 * lendingPool.WAD());
		vm.stopPrank();
	}

	function test_Positive_Withdraw() public {
		uint256 amount = 1 * lendingPool.WAD();
		vm.startPrank(alice);
		weth.approve(address(lendingPool), amount);
		lendingPool.deposit(address(weth), amount);

		vm.expectEmit(true, true, false, true);
		emit Withdraw(address(weth), alice, amount);
		lendingPool.withdraw(address(weth), amount);
		vm.stopPrank();

		assertEq(aWeth.balanceOf(alice), 0, "Alice should have 0 aWETH after full withdraw");
		assertEq(weth.balanceOf(alice), 10 * lendingPool.WAD(), "Alice should have her 10 WETH back");
	}

	function test_Negative_Withdraw_InsufficientBalance() public {
		vm.startPrank(alice);
		vm.expectRevert();
		lendingPool.withdraw(address(weth), 1 * lendingPool.WAD());
		vm.stopPrank();
	}

	function test_Positive_Borrow() public {
		vm.startPrank(alice);
		weth.approve(address(lendingPool), 1 * lendingPool.WAD()); // 1 WETH = $2000
		lendingPool.deposit(address(weth), 1 * lendingPool.WAD());

		uint256 borrowAmount = 100 * lendingPool.WAD(); // 100 DAI

		vm.expectEmit(true, true, false, true);
		emit Borrow(address(dai), alice, borrowAmount);
		lendingPool.borrow(address(dai), borrowAmount);
		vm.stopPrank();

		assertEq(dai.balanceOf(alice), borrowAmount, "Alice should have borrowed 100 DAI");
		assertApproxEqAbs(lendingPool.getUserBorrowBalance(alice, address(dai)), borrowAmount, 1, "Borrow balance should be correct");
	}

	function test_Negative_Borrow_NotEnoughCollateral() public {
		vm.startPrank(alice);
		vm.expectRevert(NotEnoughCollateral.selector);
		lendingPool.borrow(address(dai), 1 * lendingPool.WAD());
		vm.stopPrank();
	}

	function test_Positive_Repay() public {
		test_Positive_Borrow();

		uint256 repayAmount = 100 * lendingPool.WAD();

		vm.startPrank(alice);
		dai.approve(address(lendingPool), repayAmount);

		vm.expectEmit(true, true, true, true);
		emit Repay(address(dai), alice, alice, repayAmount);
		lendingPool.repay(address(dai), repayAmount);
		vm.stopPrank();

		assertEq(lendingPool.getUserBorrowBalance(alice, address(dai)), 0, "Debt should be zero after full repay");
	}

	function test_Negative_Repay_AmountTooHigh() public {
		test_Positive_Borrow();

		vm.startPrank(alice);
		vm.expectRevert(RepayAmountTooHigh.selector);
		lendingPool.repay(address(dai), 101 * lendingPool.WAD());
		vm.stopPrank();
	}

	function test_Negative_Repay_NoDebt() public {
		vm.startPrank(alice);
		dai.approve(address(lendingPool), 1 * lendingPool.WAD());
		vm.expectRevert(RepayAmountTooHigh.selector);
		lendingPool.repay(address(dai), 1 * lendingPool.WAD());
		vm.stopPrank();
	}

	function test_InterestAccruesOverTime() public {
		address bob = makeAddr("bob");
		uint256 aliceDeposit = 1000 * lendingPool.WAD();
		uint256 bobDeposit = 1000 * lendingPool.WAD();
		uint256 aliceBorrow = 500 * lendingPool.WAD();

		dai.mint(alice, aliceDeposit);
		dai.mint(bob, bobDeposit);

		vm.startPrank(alice);
		dai.approve(address(lendingPool), aliceDeposit);
		lendingPool.deposit(address(dai), aliceDeposit);
		vm.stopPrank();

		vm.startPrank(bob);
		dai.approve(address(lendingPool), bobDeposit);
		lendingPool.deposit(address(dai), bobDeposit);
		vm.stopPrank();

		vm.startPrank(alice);
		lendingPool.borrow(address(dai), aliceBorrow);
		vm.stopPrank();

		uint256 totalDeposits = aliceDeposit + bobDeposit;
		uint256 totalBorrows = aliceBorrow;
		(uint256 depositRate, uint256 borrowRate) = interestRateStrategy.calculateInterestRates(totalDeposits, totalBorrows);

		uint256 oneYear = 365 days;

		uint256 initialIndex = lendingPool.WAD();
		uint256 liquidityAccrued = (initialIndex * depositRate * oneYear) / lendingPool.WAD();
		uint256 borrowAccrued = (initialIndex * borrowRate * oneYear) / lendingPool.WAD();
		uint256 expectedLiquidityIndex = initialIndex + liquidityAccrued;
		uint256 expectedBorrowIndex = initialIndex + borrowAccrued;

		vm.warp(block.timestamp + oneYear);

		lendingPool.accrueInterest(address(dai));

		LendingPool.AssetData memory data = lendingPool.getAssetData(address(dai));

		assertApproxEqAbs(data.liquidityIndex, expectedLiquidityIndex, 1e10, "Liquidity index should accrue correctly");
		assertApproxEqAbs(data.borrowIndex, expectedBorrowIndex, 1e10, "Borrow index should accrue correctly");
	}

	function test_Negative_Withdraw_NotEnoughCollateral() public {

		vm.startPrank(alice);
		weth.approve(address(lendingPool), 5 * lendingPool.WAD());
		lendingPool.deposit(address(weth), 5 * lendingPool.WAD());

		lendingPool.borrow(address(dai), 1600 * lendingPool.WAD());

		vm.expectRevert(NotEnoughCollateral.selector);
		lendingPool.withdraw(address(weth), 1 * lendingPool.WAD());
		vm.stopPrank();
	}

	function test_Negative_Actions_WithZeroAmount() public {
		vm.startPrank(alice);
		vm.expectRevert(AmountMustBeGreaterThanZero.selector);
		lendingPool.deposit(address(weth), 0);
		vm.expectRevert(AmountMustBeGreaterThanZero.selector);
		lendingPool.withdraw(address(weth), 0);
		vm.expectRevert(AmountMustBeGreaterThanZero.selector);
		lendingPool.borrow(address(dai), 0);
		vm.expectRevert(AmountMustBeGreaterThanZero.selector);
		lendingPool.repay(address(dai), 0);
		vm.stopPrank();
	}
}
