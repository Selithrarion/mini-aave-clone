// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFlashLoanRecipient} from "../interfaces/IFlashLoanRecipient.sol";

contract FlashLoanRecipient is IFlashLoanRecipient {
	address public immutable owner;
	address public immutable pool;
	bool public returnStatus = true;

	constructor(address _pool) {
		owner = msg.sender;
		pool = _pool;
	}

	function executeOperation(
		address asset,
		uint256 amount,
		uint256 premium,
		address /* initiator */,
		bytes calldata params
	) external override returns (bool) {
		require(msg.sender == pool, "FlashLoanRecipient: Untrusted caller");

		if (params.length > 0) {
			uint256 expectedValue = abi.decode(params, (uint256));
			require(expectedValue == 12345, "FlashLoanRecipient: Invalid params");
		}

		// some logic

		uint256 amountToReturn = amount + premium;
		IERC20(asset).approve(pool, amountToReturn);

		return returnStatus;
	}

	function setReturnStatus(bool status) external {
		require(msg.sender == owner, "FlashLoanRecipient: Not owner");
		returnStatus = status;
	}
}
