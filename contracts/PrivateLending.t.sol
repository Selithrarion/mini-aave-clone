// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {PrivateLendingPool} from "./PrivateLendingPool.sol";
import {IPrivateLendingPool} from "./interfaces/IPrivateLendingPool.sol";
import {Groth16Verifier} from "./Verifier.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

abstract contract PrivateLendingTest is Test, IPrivateLendingPool {
    using stdJson for string;

    PrivateLendingPool internal privatePool;
    Groth16Verifier internal verifier;
    MockERC20 internal token;

    uint256 constant COMMITMENT_DEC = 18408546291162903352980960740361656607192922946056016208256932944581138225340;
    bytes32 constant COMMITMENT = bytes32(COMMITMENT_DEC);

    function setUp() public {
        token = new MockERC20("Test Token", "TTK");
        verifier = new Groth16Verifier();
        privatePool = new PrivateLendingPool(address(verifier), address(token), 1 ether);
        token.mint(address(privatePool), 100 ether);
    }

    function test_Positive_WithdrawWithValidProof() public {
        token.mint(address(this), 1 ether);
        token.approve(address(privatePool), 1 ether);

		vm.expectEmit(true, false, false, true);
		emit Deposited(COMMITMENT);
		privatePool.deposit(COMMITMENT);

		string memory proofJson = '{"pi_a": ["10808481378255224661082986664204594007053625685093780815584303626892663072786", "9790307405559303173543821713070168616461359277659500486850689270352617960612", "1"],"pi_b": [["543865502264369495756364700075145153744180182332643475705215745636884954782", "14791294319704366679705325742576122978155638797790061121965290374060586895397"], ["11234839622107773310234337864817413700159919405161730430782179344142486925304", "14276843409130345023064736525631580391364454203338163796935398261196624678717"], ["1", "0"]], "pi_c": ["18315170927867870646771656355014126636622283199775040375019391526633303649218", "13387766570150924273505147998617189909993542594993301645448297465507699943901", "1"], "protocol": "groth16", "curve": "bn128"}';
		string memory publicJson = '["18408546291162903352980960740361656607192922946056016208256932944581138225340"]';

		(uint256[2] memory a, uint256[2][2] memory b, uint256[2] memory c) = _parseProof(proofJson);

        uint256[1] memory publicInputs = [publicJson.readUintArray("$")[0]];

        address recipient = makeAddr("recipient");
        uint256 initialBalance = token.balanceOf(recipient);

        uint256 nullifier = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        bytes32 calculatedNullifierHash = keccak256(
            abi.encodePacked(nullifier)
        );

		privatePool.withdraw(a, b, c, COMMITMENT, calculatedNullifierHash, recipient);

        assertEq(
            token.balanceOf(recipient),
            initialBalance + 1 ether,
            "Recipient should have received the deposit amount"
        );
		assertTrue(privatePool.usedNullifiers(calculatedNullifierHash), "Nullifier should be marked as used");

        vm.expectRevert("Nullifier already used");
		privatePool.withdraw(a, b, c, COMMITMENT, calculatedNullifierHash, recipient);
    }

	function test_Negative_Withdraw_WithInvalidProof() public {
		test_Positive_WithdrawWithValidProof();

		string memory proofJson = '{"pi_a": ["10808481378255224661082986664204594007053625685093780815584303626892663072786", "9790307405559303173543821713070168616461359277659500486850689270352617960612", "1"],"pi_b": [["543865502264369495756364700075145153744180182332643475705215745636884954782", "14791294319704366679705325742576122978155638797790061121965290374060586895397"], ["11234839622107773310234337864817413700159919405161730430782179344142486925304", "14276843409130345023064736525631580391364454203338163796935398261196624678717"], ["1, "0"]], "pi_c": ["18315170927867870646771656355014126636622283199775040375019391526633303649218", "13387766570150924273505147998617189909993542594993301645448297465507699943901", "1"], "protocol": "groth16", "curve": "bn128"}';
		(uint256[2] memory a, uint256[2][2] memory b, uint256[2] memory c) = _parseProof(proofJson);

		a[0] = a[0] + 1;

		address recipient = makeAddr("recipient");
		uint256 nullifier = 123;
		bytes32 calculatedNullifierHash = keccak256(abi.encodePacked(nullifier));

		vm.expectRevert("Invalid proof");
		privatePool.withdraw(a, b, c, COMMITMENT, calculatedNullifierHash, recipient);
	}

	function test_Negative_Withdraw_WithWrongCommitment() public {
		test_Positive_WithdrawWithValidProof();

		string memory proofJson = '{"pi_a": ["10808481378255224661082986664204594007053625685093780815584303626892663072786", "9790307405559303173543821713070168616461359277659500486850689270352617960612", "1"],"pi_b": [["543865502264369495756364700075145153744180182332643475705215745636884954782", "14791294319704366679705325742576122978155638797790061121965290374060586895397"], ["11234839622107773310234337864817413700159919405161730430782179344142486925304", "14276843409130345023064736525631580391364454203338163796935398261196624678717"], ["1, "0"]], "pi_c": ["18315170927867870646771656355014126636622283199775040375019391526633303649218", "13387766570150924273505147998617189909993542594993301645448297465507699943901", "1"], "protocol": "groth16", "curve": "bn128"}';
		(uint256[2] memory a, uint256[2][2] memory b, uint256[2] memory c) = _parseProof(proofJson);

		bytes32 wrongCommitment = bytes32(uint256(12345));
		bytes32 calculatedNullifierHash = keccak256(abi.encodePacked(uint256(123)));

		vm.expectRevert("Commitment not found");
		privatePool.withdraw(a, b, c, wrongCommitment, calculatedNullifierHash, makeAddr("recipient"));
	}

	function _parseProof(
		string memory proofJson
	) internal pure returns (uint256[2] memory a, uint256[2][2] memory b, uint256[2] memory c) {
		uint256[] memory a_dynamic = proofJson.readUintArray(".pi_a");
		a[0] = a_dynamic[0];
		a[1] = a_dynamic[1];

		b[0][0] = proofJson.readUint(".pi_b[0][0]");
		b[0][1] = proofJson.readUint(".pi_b[0][1]");
		b[1][0] = proofJson.readUint(".pi_b[1][0]");
		b[1][1] = proofJson.readUint(".pi_b[1][1]");

		uint256[] memory c_dynamic = proofJson.readUintArray(".pi_c");
		c[0] = c_dynamic[0];
		c[1] = c_dynamic[1];

		return (a, b, c);
	}
}