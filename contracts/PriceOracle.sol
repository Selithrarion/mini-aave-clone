// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IPriceOracle.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract PriceOracle is IPriceOracle, Ownable {
	mapping(address => uint256) public assetPrices;

	constructor() Ownable(msg.sender) {}

	function setAssetPrice(address asset, uint256 price) external onlyOwner {
		require(asset != address(0), "PriceOracle: Invalid asset address");
		assetPrices[asset] = price;
	}

	function getAssetPrice(address asset) external view returns (uint256) {
		uint256 price = assetPrices[asset];
		require(price > 0, "PriceOracle: Price not set for this asset");
		return price;
	}
}
