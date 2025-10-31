// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {INFTDescriptor} from "./interfaces/INFTDescriptor.sol";

contract NFTDescriptor is INFTDescriptor {
	ILendingPool public immutable lendingPool;

	constructor(address _lendingPool) {
		lendingPool = ILendingPool(_lendingPool);
	}

	function constructTokenURI(address user) public view returns (string memory) {
		(uint256 totalCollateralUSD, , uint256 earnedInterestUSD, ) = lendingPool.getUserAccountData(user);

		string memory image = generateSVG(totalCollateralUSD, earnedInterestUSD);
		string memory name = "MiniAave Position";
		string memory description = "Represents deposit position in the MiniAave protocol.";

		string memory json = Base64.encode(
			bytes(
				string.concat(
					'{"name":"',
					name,
					'",',
					'"description":"',
					description,
					'",',
					'"image":"data:image/svg+xml;base64,',
					Base64.encode(bytes(image)),
					'"}'
				)
			)
		);

		return string.concat("data:application/json;base64,", json);
	}

	function generateSVG(uint256 collateralUSD, uint256 earnedInterestUSD) internal pure returns (string memory) {
		string memory circleColor;
		if (collateralUSD < 100 * 1e18) {
			circleColor = "green";
		} else if (collateralUSD < 10000 * 1e18) {
			circleColor = "orange";
		} else {
			circleColor = "red";
		}

		string memory glowEffect;
		if (earnedInterestUSD > 10 * 1e18) {
			glowEffect = '<filter id="glow"><feGaussianBlur stdDeviation="3.5" result="coloredBlur"/><feMerge><feMergeNode in="coloredBlur"/><feMergeNode in="SourceGraphic"/></feMerge></filter>';
		}

		return
			string.concat(
				'<svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">',
				glowEffect,
				'<circle cx="50" cy="50" r="40" stroke="black" stroke-width="3" fill="',
				circleColor,
				'" ',
				(bytes(glowEffect).length > 0 ? 'filter="url(#glow)"' : ""),
				" /></svg>"
			);
	}
}
