// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IAToken.sol";
import {LendingPool} from "./LendingPool.sol";

contract AToken is IAToken, ERC20 {
	address public immutable LENDING_POOL;
	address public immutable UNDERLYING_ASSET;

	constructor(
		address lendingPool,
		address underlyingAsset,
		string memory tokenName,
		string memory tokenSymbol
	) ERC20(tokenName, tokenSymbol) {
		LENDING_POOL = lendingPool;
		UNDERLYING_ASSET = underlyingAsset;
	}

	function totalSupply() public view override(ERC20, IERC20) returns (uint256) {
		uint256 scaledTotalSupply = super.totalSupply();
		if (scaledTotalSupply == 0) {
			return 0;
		}
		uint256 liquidityIndex = LendingPool(LENDING_POOL).getAssetData(UNDERLYING_ASSET).liquidityIndex;
		return (scaledTotalSupply * liquidityIndex) / LendingPool(LENDING_POOL).WAD();
	}

	function balanceOf(address account) public view override(ERC20, IERC20) returns (uint256) {
		uint256 scaledBalance = super.balanceOf(account);
		if (scaledBalance == 0) {
			return 0;
		}
		uint256 liquidityIndex = LendingPool(LENDING_POOL).getAssetData(UNDERLYING_ASSET).liquidityIndex;
		return (scaledBalance * liquidityIndex) / LendingPool(LENDING_POOL).WAD();
	}

	function mint(address to, uint256 amount) external override {
		if (msg.sender != LENDING_POOL) revert OnlyLendingPool();
		uint256 liquidityIndex = LendingPool(LENDING_POOL).getAssetData(UNDERLYING_ASSET).liquidityIndex;
		uint256 scaledAmount = (amount * LendingPool(LENDING_POOL).WAD()) / liquidityIndex;
		_mint(to, scaledAmount);
	}

	function burn(address from, uint256 amount) external override {
		if (msg.sender != LENDING_POOL) revert OnlyLendingPool();
		uint256 liquidityIndex = LendingPool(LENDING_POOL).getAssetData(UNDERLYING_ASSET).liquidityIndex;
		uint256 scaledAmount = (amount * LendingPool(LENDING_POOL).WAD()) / liquidityIndex;
		_burn(from, scaledAmount);
	}

	function getNormalizedBalance(address user) external view returns (uint256) {
		return super.balanceOf(user);
	}
}
