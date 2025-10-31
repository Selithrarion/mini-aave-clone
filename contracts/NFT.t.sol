// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LendingPoolSetup} from "./LendingPoolSetup.t.sol";
import {LendingNFT} from "./LendingNFT.sol";
import {ILendingNFT} from "./interfaces/ILendingNFT.sol";
import {NFTDescriptor} from "./NFTDescriptor.sol";

abstract contract NFTTest is LendingPoolSetup, ILendingNFT {
	LendingNFT internal lendingNFT;
	NFTDescriptor internal nftDescriptor;

	function setUp() public virtual override {
		super.setUp();

		nftDescriptor = new NFTDescriptor(address(lendingPool));
		lendingNFT = new LendingNFT(address(lendingPool), address(nftDescriptor));
		lendingPool.setNFTContract(address(lendingNFT));
	}

	function test_Positive_MintOnFirstDeposit() public {
		uint256 depositAmount = 100 * lendingPool.WAD();
		vm.startPrank(alice);
		dai.mint(alice, depositAmount);
		dai.approve(address(lendingPool), depositAmount);
		lendingPool.deposit(address(dai), depositAmount);
		vm.stopPrank();

		assertEq(lendingNFT.balanceOf(alice), 1, "Alice should own 1 NFT");
		assertEq(lendingNFT.ownerOf(0), alice, "Token ID 0 should belong to Alice");
		assertTrue(lendingPool.hasNFT(alice), "hasNFT flag should be true for Alice");
	}

	function test_Negative_NoMintOnSecondDeposit() public {
		test_Positive_MintOnFirstDeposit();

		uint256 initialNextTokenId = lendingNFT.nextTokenId();

		uint256 secondDepositAmount = 50 * lendingPool.WAD();
		vm.startPrank(alice);
		dai.mint(alice, secondDepositAmount);
		dai.approve(address(lendingPool), secondDepositAmount);
		lendingPool.deposit(address(dai), secondDepositAmount);
		vm.stopPrank();

		assertEq(lendingNFT.nextTokenId(), initialNextTokenId, "Next token ID should not increase on second deposit");
		assertEq(lendingNFT.balanceOf(alice), 1, "Alice should still own only 1 NFT");
	}

	function test_Negative_OnlyPoolCanMint() public {
		vm.expectRevert(OnlyLendingPool.selector);
		lendingNFT.mint(alice);
	}

	function test_Negative_TransferBeforeMaturation() public {
		test_Positive_MintOnFirstDeposit();

		address bob = makeAddr("bob");
		vm.startPrank(alice);

		vm.expectRevert(NFTNotMature.selector);
		lendingNFT.transferFrom(alice, bob, 0);

		vm.stopPrank();
	}

	function test_Positive_TransferAfterMaturation() public {
		test_Positive_MintOnFirstDeposit();

		vm.warp(block.timestamp + lendingNFT.MATURATION_PERIOD() + 1 days);

		address bob = makeAddr("bob");
		vm.startPrank(alice);
		lendingNFT.transferFrom(alice, bob, 0);
		vm.stopPrank();

		assertEq(lendingNFT.ownerOf(0), bob, "Bob should be the new owner");
	}
}
