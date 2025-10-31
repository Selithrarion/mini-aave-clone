// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {LendingPool} from "./LendingPool.sol";
import {PriceOracle} from "./PriceOracle.sol";
import {InterestRateStrategy} from "./InterestRateStrategy.sol";
import {AToken} from "./AToken.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

abstract contract LendingPoolSetup is Test, ILendingPool {
	LendingPool internal lendingPool;
	PriceOracle internal priceOracle;
	InterestRateStrategy internal interestRateStrategy;

	MockERC20 internal weth; // collateral
	MockERC20 internal dai; // borrowable

	AToken internal aWeth;
	AToken internal aDai;

	address internal alice = makeAddr("alice");

	function setUp() public virtual {
		priceOracle = new PriceOracle();
		interestRateStrategy = new InterestRateStrategy();
		lendingPool = new LendingPool(address(priceOracle), address(interestRateStrategy));

		weth = new MockERC20("Wrapped Ether", "WETH");
		dai = new MockERC20("Dai Stablecoin", "DAI");

		aWeth = new AToken(address(lendingPool), address(weth), "Aave WETH", "aWETH");
		aDai = new AToken(address(lendingPool), address(dai), "Aave DAI", "aDAI");

		lendingPool.addAsset(address(weth), address(aWeth), 8000, 8500, 10500);
		lendingPool.addAsset(address(dai), address(aDai), 7500, 8000, 10500);

		priceOracle.setAssetPrice(address(weth), 2000 * lendingPool.ORACLE_PRECISION()); // WETH = $2000
		priceOracle.setAssetPrice(address(dai), 1 * lendingPool.ORACLE_PRECISION()); // DAI = $1

		weth.mint(alice, 10 * 1e18); // mint weth for user
		dai.mint(address(lendingPool), 100000 * 1e18); // add dai liquidity for pool
	}
}
