// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ILendingNFT is IERC721 {
	error OnlyLendingPool();
	error NFTNotMature();

	function mint(address to) external returns (uint256);
}
