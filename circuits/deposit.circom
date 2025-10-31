pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/poseidon.circom";

template Deposit() {
    signal input secret;
    signal input nullifier;

    signal output commitment;

    component hasher = Poseidon(2);
    hasher.inputs[0] <== nullifier;
    hasher.inputs[1] <== secret;

    commitment <== hasher.out;
}

component main = Deposit();