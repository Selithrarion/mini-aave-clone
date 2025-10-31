// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IPrivateLendingPool {
	event Deposited(bytes32 commitment);

	function deposit(bytes32 _commitment) external;

	function withdraw(
		uint[2] calldata a,
		uint[2][2] calldata b,
		uint[2] calldata c,
		bytes32 _commitment,
		bytes32 _nullifierHash,
		address _recipient
	) external;
}