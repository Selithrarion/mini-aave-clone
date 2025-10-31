// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IInterestRateStrategy.sol";

contract InterestRateStrategy is IInterestRateStrategy {
	uint256 public constant WAD = 1e18;
	uint256 public constant SECONDS_PER_YEAR = 365 days;

	uint256 public constant BASE_BORROW_RATE = 3 * 1e16; // 3% APY (3 * 10^16)
	uint256 public constant RATE_MULTIPLIER = 75 * 1e16; // 75% (75 * 10^16)

	function calculateInterestRates(
		uint256 totalDeposits,
		uint256 totalBorrows
	) external pure returns (uint256 depositRate, uint256 borrowRate) {
		if (totalDeposits == 0) {
			return (0, 0);
		}

		uint256 utilizationRate = (totalBorrows * WAD) / totalDeposits;
		uint256 borrowApy = BASE_BORROW_RATE + (utilizationRate * RATE_MULTIPLIER) / WAD; // 3% + Utilization * 75%
		uint256 depositApy = (borrowApy * utilizationRate) / WAD;

		depositRate = depositApy / SECONDS_PER_YEAR;
		borrowRate = borrowApy / SECONDS_PER_YEAR;
	}
}
