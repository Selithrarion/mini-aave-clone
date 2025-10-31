// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAToken is IERC20 {
	error OnlyLendingPool();

	function mint(address to, uint256 amount) external;
	function burn(address from, uint256 amount) external;
	function getNormalizedBalance(address user) external view returns (uint256);
}
