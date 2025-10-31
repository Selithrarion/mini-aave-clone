// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LendingPool} from "./LendingPool.sol";
import {LendingPoolSetup} from "./LendingPoolSetup.t.sol";
import {FlashLoanRecipient} from "./mocks/FlashLoanRecipient.sol";

abstract contract FlashLoanTest is LendingPoolSetup {
	function setUp() public override {
		super.setUp();
	}

	function test_Positive_FlashLoan() public {
		uint256 poolDeposit = 10000 * lendingPool.WAD();
		address poolDepositor = makeAddr("poolDepositor");
		dai.mint(poolDepositor, poolDeposit);

		vm.startPrank(poolDepositor);
		dai.approve(address(lendingPool), poolDeposit);
		lendingPool.deposit(address(dai), poolDeposit);
		vm.stopPrank();

		FlashLoanRecipient recipient = new FlashLoanRecipient(address(lendingPool));

		uint256 flashLoanAmount = 1000 * lendingPool.WAD();
		uint256 premium = (flashLoanAmount * 9) / 10000; // 0.09%
		vm.expectEmit(true, true, true, true);
		emit FlashLoan(address(recipient), address(this), address(dai), flashLoanAmount, premium);
		lendingPool.flashLoan(address(recipient), address(dai), flashLoanAmount, "");

		uint256 poolBalanceAfter = dai.balanceOf(address(lendingPool));
		assertEq(poolBalanceAfter, poolDeposit + premium, "Pool should have earned the fee(premium)");
	}

	function test_Negative_FlashLoan_NoRepay() public {
		address poolDepositor = makeAddr("poolDepositor");
		uint256 poolDeposit = 10000 * lendingPool.WAD();
		dai.mint(poolDepositor, poolDeposit);
		vm.startPrank(poolDepositor);
		dai.approve(address(lendingPool), poolDeposit);
		lendingPool.deposit(address(dai), poolDeposit);
		vm.stopPrank();

		address badRecipient = makeAddr("badRecipient");

		uint256 flashLoanAmount = 1000 * lendingPool.WAD();
		vm.expectRevert(FlashLoanExecutionFailed.selector);
		lendingPool.flashLoan(badRecipient, address(dai), flashLoanAmount, "");
	}

	function test_Negative_FlashLoan_NotEnoughLiquidity() public {
		FlashLoanRecipient recipient = new FlashLoanRecipient(address(lendingPool));
		uint256 flashLoanAmount = 1000 * lendingPool.WAD();

		vm.expectRevert(NotEnoughLiquidity.selector);
		lendingPool.flashLoan(address(recipient), address(dai), flashLoanAmount, "");
	}

	function test_Negative_FlashLoan_InvalidRepayment() public {
		uint256 poolDeposit = 10000 * lendingPool.WAD();
		address poolDepositor = makeAddr("poolDepositor");
		dai.mint(poolDepositor, poolDeposit);
		vm.startPrank(poolDepositor);
		dai.approve(address(lendingPool), poolDeposit);
		lendingPool.deposit(address(dai), poolDeposit);
		vm.stopPrank();

		FlashLoanRecipient recipient = new FlashLoanRecipient(address(lendingPool));
		vm.startPrank(address(recipient));
		recipient.setReturnStatus(false);
		vm.stopPrank();

		uint256 flashLoanAmount = 1000 * lendingPool.WAD();
		vm.expectRevert(FlashLoanExecutionFailed.selector);
		lendingPool.flashLoan(address(recipient), address(dai), flashLoanAmount, "");
	}

	function test_Negative_FlashLoan_ZeroAmount() public {
		FlashLoanRecipient recipient = new FlashLoanRecipient(address(lendingPool));

		vm.expectRevert(AmountMustBeGreaterThanZero.selector);
		lendingPool.flashLoan(address(recipient), address(dai), 0, "");
	}

	function test_Positive_FlashLoan_WithParams() public {
		uint256 poolDeposit = 10000 * lendingPool.WAD();
		address poolDepositor = makeAddr("poolDepositor");
		dai.mint(poolDepositor, poolDeposit);
		vm.startPrank(poolDepositor);
		dai.approve(address(lendingPool), poolDeposit);
		lendingPool.deposit(address(dai), poolDeposit);
		vm.stopPrank();

		FlashLoanRecipient recipient = new FlashLoanRecipient(address(lendingPool));

		uint256 flashLoanAmount = 1000 * lendingPool.WAD();
		uint256 expectedParamValue = 12345;
		bytes memory params = abi.encode(expectedParamValue);

		lendingPool.flashLoan(address(recipient), address(dai), flashLoanAmount, params);
	}

	function testFuzz_FlashLoan_DoesNotLoseMoney(uint96 amount) public {
		vm.assume(amount > 0 && amount < 5000 * 1e18);

		uint256 poolDeposit = 10000 * lendingPool.WAD();
		address poolDepositor = makeAddr("poolDepositor");
		dai.mint(poolDepositor, poolDeposit);
		vm.startPrank(poolDepositor);
		dai.approve(address(lendingPool), poolDeposit);
		lendingPool.deposit(address(dai), poolDeposit);
		vm.stopPrank();

		uint256 balanceBefore = dai.balanceOf(address(lendingPool));

		FlashLoanRecipient recipient = new FlashLoanRecipient(address(lendingPool));
		lendingPool.flashLoan(address(recipient), address(dai), amount, "");

		uint256 balanceAfter = dai.balanceOf(address(lendingPool));
		uint256 premium = (uint256(amount) * 9) / 10000;
		assertEq(balanceAfter, balanceBefore + premium, "Pool balance should increase by the premium amount");
	}
}
