// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface INFTDescriptor {
	function constructTokenURI(address user) external view returns (string memory);
}
