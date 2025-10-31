// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ILendingPool {
	error AmountMustBeGreaterThanZero();
	error AssetNotSupported();
	error AssetAlreadyAdded();
	error NotEnoughCollateral(uint256 collateralValue, uint256 borrowValue);
	error HealthFactorIsGood();
	error InvalidFlashLoanRepayment();
	error NotEnoughLiquidity();
	error RepayAmountTooHigh();
	error FlashLoanExecutionFailed();

	function deposit(address asset, uint256 amount) external;

	function withdraw(address asset, uint256 amount) external;

	function borrow(address asset, uint256 amount) external;

	function repay(address asset, uint256 amount) external;

	function accrueInterest(address asset) external;

	function liquidate(address collateralAsset, address debtAsset, address user, uint256 debtToCover) external;

	function flashLoan(address receiverAddress, address asset, uint256 amount, bytes calldata params) external;

	function getUserAccountData(
		address user
	) external view returns (uint256 totalCollateralUSD, uint256 totalDebtUSD, uint256 earnedInterestUSD, uint256 healthFactor);

	event Deposit(address indexed reserve, address indexed user, uint256 amount);

	event Withdraw(address indexed reserve, address indexed user, uint256 amount);

	event Borrow(address indexed reserve, address indexed user, uint256 amount);

	event Repay(address indexed reserve, address indexed user, address indexed repayer, uint256 amount);

	event LiquidationCall(
		address indexed collateralAsset,
		address indexed debtAsset,
		address indexed user,
		uint256 debtToCover,
		uint256 liquidatedCollateralAmount,
		address liquidator
	);

	event FlashLoan(address indexed target, address indexed initiator, address indexed asset, uint256 amount, uint256 premium);
}
