// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IFlashLoanRecipient.sol";
import "./interfaces/ILendingPool.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IInterestRateStrategy.sol";
import "./interfaces/IAToken.sol";
import {ILendingNFT} from "./interfaces/ILendingNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LendingPool is ILendingPool, Ownable(msg.sender) {
	struct AssetConfiguration {
		address aToken;
		uint64 ltv; // Loan-To-Value. 8000 for 80%
		uint64 liquidationThreshold; // 8500 for 85%
		uint64 liquidationBonus; // 10500 for 5%
	}

	struct AssetData {
		uint256 totalDeposits;
		uint256 totalBorrows;
		uint256 liquidityIndex;
		uint256 borrowIndex;
		uint64 lastUpdateTimestamp;
	}

	IPriceOracle public immutable priceOracle;
	IInterestRateStrategy public immutable interestRateStrategy;

	uint256 public constant WAD = 1e18;
	uint256 public constant ORACLE_PRECISION = 1e8;
	uint256 public constant LTV_PRECISION = 10000;
	uint256 public constant FLASHLOAN_PREMIUM_TOTAL = 9; // 0.09% fee

	mapping(address => AssetConfiguration) public assetConfigs;
	mapping(address => AssetData) public assetData;

	// user -> array of assets -> value
	mapping(address => mapping(address => uint256)) public userBorrows;
	mapping(address => address[]) public userDepositedAssets;
	mapping(address => address[]) public userBorrowedAssets;

	ILendingNFT public lendingNFT;
	mapping(address => bool) public hasNFT;

	address[] public supportedAssets;

	constructor(address _priceOracle, address _interestRateStrategy) {
		priceOracle = IPriceOracle(_priceOracle);
		interestRateStrategy = IInterestRateStrategy(_interestRateStrategy);
	}

	function setNFTContract(address _nftAddress) external onlyOwner {
		lendingNFT = ILendingNFT(_nftAddress);
	}

	function addAsset(
		address asset,
		address aToken,
		uint256 ltv,
		uint256 liquidationThreshold,
		uint256 liquidationBonus
	) external onlyOwner {
		if (assetConfigs[asset].aToken != address(0)) revert AssetAlreadyAdded();
		assetConfigs[asset] = AssetConfiguration({
			aToken: aToken,
			ltv: uint64(ltv),
			liquidationThreshold: uint64(liquidationThreshold),
			liquidationBonus: uint64(liquidationBonus)
		});

		AssetData storage data = assetData[asset];
		data.liquidityIndex = WAD;
		data.borrowIndex = WAD;
		data.lastUpdateTimestamp = uint64(block.timestamp);

		supportedAssets.push(asset);
	}

	function deposit(address asset, uint256 amount) external override {
		_updateState(asset);
		if (amount == 0) revert AmountMustBeGreaterThanZero();
		address aTokenAddress = assetConfigs[asset].aToken;
		if (aTokenAddress == address(0)) revert AssetNotSupported();

		IERC20(asset).transferFrom(msg.sender, address(this), amount);
		IAToken(aTokenAddress).mint(msg.sender, amount);
		assetData[asset].totalDeposits += amount;
		bool found = false;
		for (uint256 i = 0; i < userDepositedAssets[msg.sender].length; i++) {
			if (userDepositedAssets[msg.sender][i] == asset) {
				found = true;
				break;
			}
		}
		if (!found) {
			userDepositedAssets[msg.sender].push(asset);
		}
		if (!hasNFT[msg.sender]) {
			lendingNFT.mint(msg.sender);
			hasNFT[msg.sender] = true;
		}

		emit Deposit(asset, msg.sender, amount);
	}

	function withdraw(address asset, uint256 amount) external override {
		_updateState(asset);
		if (amount == 0) revert AmountMustBeGreaterThanZero();
		address aTokenAddress = assetConfigs[asset].aToken;
		if (aTokenAddress == address(0)) revert AssetNotSupported();

		IAToken(aTokenAddress).burn(msg.sender, amount);
		assetData[asset].totalDeposits -= amount;
		IERC20(asset).transfer(msg.sender, amount);

		emit Withdraw(asset, msg.sender, amount);
	}

	function borrow(address asset, uint256 amount) external override {
		_updateState(asset);
		if (amount == 0) revert AmountMustBeGreaterThanZero();
		if (assetConfigs[asset].aToken == address(0)) revert AssetNotSupported();

		uint256 totalCollateralValue = _calculateUserCollateralValue(msg.sender);

		uint256 borrowAssetPrice = priceOracle.getAssetPrice(asset);
		uint256 newBorrowValue = (amount * borrowAssetPrice) / ORACLE_PRECISION;

		if (totalCollateralValue < newBorrowValue) revert NotEnoughCollateral(totalCollateralValue, newBorrowValue);

		uint256 borrowIndex = assetData[asset].borrowIndex;
		userBorrows[msg.sender][asset] += (amount * WAD) / borrowIndex;
		assetData[asset].totalBorrows += amount;

		bool found = false;
		for (uint256 i = 0; i < userBorrowedAssets[msg.sender].length; i++) {
			if (userBorrowedAssets[msg.sender][i] == asset) {
				found = true;
				break;
			}
		}
		if (!found) {
			userBorrowedAssets[msg.sender].push(asset);
		}

		IERC20(asset).transfer(msg.sender, amount);

		emit Borrow(asset, msg.sender, amount);
	}

	function repay(address asset, uint256 amount) external override {
		_updateState(asset);
		if (amount == 0) revert AmountMustBeGreaterThanZero();
		if (assetConfigs[asset].aToken == address(0)) revert AssetNotSupported();

		uint256 userDebt = getUserBorrowBalance(msg.sender, asset);
		if (amount > userDebt) revert RepayAmountTooHigh();

		uint256 borrowIndex = assetData[asset].borrowIndex;
		userBorrows[msg.sender][asset] -= (amount * WAD) / borrowIndex;

		assetData[asset].totalBorrows -= amount;

		IERC20(asset).transferFrom(msg.sender, address(this), amount);

		emit Repay(asset, msg.sender, msg.sender, amount);
	}

	function accrueInterest(address asset) external override {
		_updateState(asset);
	}

	function liquidate(address collateralAsset, address debtAsset, address user, uint256 debtToCover) external override {
		_updateState(collateralAsset);
		_updateState(debtAsset);

		(, , , uint256 healthFactor) = getUserAccountData(user);
		if (healthFactor >= WAD) revert HealthFactorIsGood();

		uint256 userDebt = getUserBorrowBalance(user, debtAsset);
		uint256 actualDebtToCover = debtToCover > userDebt ? userDebt : debtToCover;

		uint256 debtAssetPrice = priceOracle.getAssetPrice(debtAsset);
		uint256 collateralAssetPrice = priceOracle.getAssetPrice(collateralAsset);
		uint256 debtToCoverInUSD = (actualDebtToCover * debtAssetPrice) / ORACLE_PRECISION;

		AssetConfiguration storage collateralConfig = assetConfigs[collateralAsset];
		uint256 collateralToLiquidateInUSD = (debtToCoverInUSD * collateralConfig.liquidationBonus) / LTV_PRECISION;
		uint256 collateralToLiquidateAmount = (collateralToLiquidateInUSD * ORACLE_PRECISION) / collateralAssetPrice;

		IERC20(debtAsset).transferFrom(msg.sender, address(this), actualDebtToCover);

		uint256 debtAssetBorrowIndex = assetData[debtAsset].borrowIndex;
		userBorrows[user][debtAsset] -= (actualDebtToCover * WAD) / debtAssetBorrowIndex;
		assetData[debtAsset].totalBorrows -= actualDebtToCover;

		address collateralATokenAddress = assetConfigs[collateralAsset].aToken;
		IAToken(collateralATokenAddress).burn(user, collateralToLiquidateAmount);
		IERC20(collateralAsset).transfer(msg.sender, collateralToLiquidateAmount);

		emit LiquidationCall(collateralAsset, debtAsset, user, actualDebtToCover, collateralToLiquidateAmount, msg.sender);
	}

	function flashLoan(address receiverAddress, address asset, uint256 amount, bytes calldata params) external override {
		if (amount == 0) revert AmountMustBeGreaterThanZero();

		_updateState(asset);

		uint256 premium = (amount * FLASHLOAN_PREMIUM_TOTAL) / LTV_PRECISION; // 0.09%
		uint256 amountToReturn = amount + premium;
		uint256 availableLiquidity = IERC20(asset).balanceOf(address(this)) - assetData[asset].totalBorrows;
		if (availableLiquidity < amount) revert NotEnoughLiquidity();

		IERC20(asset).transfer(receiverAddress, amount);
		bool success = IFlashLoanRecipient(receiverAddress).executeOperation(asset, amount, premium, msg.sender, params);
		if (!success) revert FlashLoanExecutionFailed();

		IERC20(asset).transferFrom(receiverAddress, address(this), amountToReturn);
		assetData[asset].totalDeposits += premium;
		emit FlashLoan(receiverAddress, msg.sender, asset, amount, premium);
	}

	function getUserBorrowBalance(address user, address asset) public view returns (uint256) {
		uint256 scaledUserBorrow = userBorrows[user][asset];
		if (scaledUserBorrow == 0) {
			return 0;
		}
		return (scaledUserBorrow * assetData[asset].borrowIndex) / WAD;
	}

	function getAssetData(address asset) external view returns (AssetData memory) {
		return assetData[asset];
	}

	function getUserAccountData(
		address user
	) public view override returns (uint256 totalCollateralUSD, uint256 totalDebtUSD, uint256 earnedInterestUSD, uint256 healthFactor) {
		uint256 totalWeightedCollateralUSD = 0;
		uint256 totalNormalizedCollateralUSD = 0;

		for (uint256 i = 0; i < userDepositedAssets[user].length; i++) {
			address asset = userDepositedAssets[user][i];
			AssetConfiguration storage config = assetConfigs[asset];

			uint256 userUnderlyingBalance = IAToken(config.aToken).getNormalizedBalance(user);
			uint256 assetPrice = priceOracle.getAssetPrice(asset);
			uint256 collateralValueInUsd = (userUnderlyingBalance * assetPrice) / ORACLE_PRECISION;

			totalNormalizedCollateralUSD += collateralValueInUsd;
			totalCollateralUSD += collateralValueInUsd;
			totalWeightedCollateralUSD += (collateralValueInUsd * config.liquidationThreshold) / LTV_PRECISION;
		}

		for (uint256 i = 0; i < userBorrowedAssets[user].length; i++) {
			address debtAsset = userBorrowedAssets[user][i];
			uint256 borrowBalance = getUserBorrowBalance(user, debtAsset);
			if (borrowBalance > 0) {
				uint256 debtAssetPrice = priceOracle.getAssetPrice(debtAsset);
				totalDebtUSD += (borrowBalance * debtAssetPrice) / ORACLE_PRECISION;
			}
		}

		earnedInterestUSD = totalCollateralUSD - totalNormalizedCollateralUSD;

		if (totalDebtUSD == 0) {
			healthFactor = type(uint256).max;
		} else {
			healthFactor = (totalWeightedCollateralUSD * WAD) / totalDebtUSD;
		}
	}

	function _updateState(address asset) internal {
		AssetData storage data = assetData[asset];
		uint256 timeDelta = block.timestamp - uint256(data.lastUpdateTimestamp);

		if (timeDelta == 0) {
			return;
		}

		(uint256 depositRate, uint256 borrowRate) = interestRateStrategy.calculateInterestRates(data.totalDeposits, data.totalBorrows);

		data.liquidityIndex = data.liquidityIndex + (data.liquidityIndex * depositRate * timeDelta) / WAD;
		data.borrowIndex = data.borrowIndex + (data.borrowIndex * borrowRate * timeDelta) / WAD;

		data.lastUpdateTimestamp = uint64(block.timestamp);
	}

	function _calculateUserCollateralValue(address user) private view returns (uint256) {
		uint256 totalCollateralValue = 0;

		for (uint256 i = 0; i < userDepositedAssets[user].length; i++) {
			address asset = userDepositedAssets[user][i];
			AssetConfiguration storage config = assetConfigs[asset];

			uint256 userUnderlyingBalance = IAToken(config.aToken).getNormalizedBalance(user);
			if (userUnderlyingBalance == 0) {
				continue;
			}

			uint256 assetPrice = priceOracle.getAssetPrice(asset);
			uint256 collateralValueInUsd = (userUnderlyingBalance * assetPrice) / ORACLE_PRECISION;

			totalCollateralValue += (collateralValueInUsd * config.ltv) / LTV_PRECISION;
		}
		return totalCollateralValue;
	}
}
