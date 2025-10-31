// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

error DebugInvalidProof(uint256 receivedPublicInput);

import {Groth16Verifier} from "./Verifier.sol";
import "hardhat/console.sol";
import {IPrivateLendingPool} from "./interfaces/IPrivateLendingPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "./MerkleTree.sol";

contract PrivateLendingPool is IPrivateLendingPool {
    Groth16Verifier public verifier;
    IERC20 public token;
    uint256 public depositAmount;

    mapping(bytes32 => bool) public commitments;
    mapping(bytes32 => bool) public usedNullifiers;

    constructor(address _verifier, address _token, uint256 _depositAmount) {
        verifier = Groth16Verifier(_verifier);
        token = IERC20(_token);
        depositAmount = _depositAmount;
    }

    function deposit(bytes32 _commitment) external {
        require(!commitments[_commitment], "Commitment already exists");

        commitments[_commitment] = true;
        emit Deposited(_commitment);

        token.transferFrom(msg.sender, address(this), depositAmount);
    }

    function withdraw(
		uint[2] calldata a,
		uint[2][2] calldata b,
		uint[2] calldata c,
        bytes32 _commitment,
        bytes32 _nullifierHash,
        address _recipient
    ) external {
        require(commitments[_commitment], "Commitment not found");
        require(!usedNullifiers[_nullifierHash], "Nullifier already used");

        uint[1] memory publicInputs = [uint256(_commitment)];

		if (!verifier.verifyProof(a, b, c, publicInputs)) {
			revert DebugInvalidProof(publicInputs[0]);
		}

        usedNullifiers[_nullifierHash] = true;
        token.transfer(_recipient, depositAmount);
    }
}