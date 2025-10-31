// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ILendingNFT} from "./interfaces/ILendingNFT.sol";
import {INFTDescriptor} from "./interfaces/INFTDescriptor.sol";

contract LendingNFT is ERC721, ILendingNFT {
	uint256 private _nextTokenId;
	address public immutable lendingPool;
	INFTDescriptor public immutable descriptor;

	uint256 public constant MATURATION_PERIOD = 30 days;
	mapping(uint256 => uint256) public mintTimestamps;

	constructor(address _lendingPool, address _descriptor) ERC721("MiniAave Deposit", "MAD") {
		lendingPool = _lendingPool;
		descriptor = INFTDescriptor(_descriptor);
	}

	function mint(address to) external returns (uint256) {
		if (msg.sender != lendingPool) revert OnlyLendingPool();
		uint256 tokenId = _nextTokenId++;
		_safeMint(to, tokenId);
		mintTimestamps[tokenId] = block.timestamp;
		return tokenId;
	}

	function tokenURI(uint256 tokenId) public view override returns (string memory) {
		if (_ownerOf(tokenId) == address(0)) revert ERC721NonexistentToken(tokenId);
		address owner = ownerOf(tokenId);
		return descriptor.constructTokenURI(owner);
	}

	function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
		address from = _ownerOf(tokenId);

		bool isTransfer = from != address(0) && to != address(0);
		if (isTransfer && block.timestamp < mintTimestamps[tokenId] + MATURATION_PERIOD) {
			revert NFTNotMature();
		}

		return super._update(to, tokenId, auth);
	}

	function nextTokenId() external view returns (uint256) {
		return _nextTokenId;
	}
}
