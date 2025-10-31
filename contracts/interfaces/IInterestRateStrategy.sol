// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IInterestRateStrategy {
	function calculateInterestRates(
		uint256 totalDeposits,
		uint256 totalBorrows
	) external view returns (uint256 depositRate, uint256 borrowRate);
}
