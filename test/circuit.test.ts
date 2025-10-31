import { WitnessCalculatorBuilder } from "circom_runtime"
import { randomBytes } from "crypto";
import { describe, it } from "node:test";
import assert from "node:assert";
import { execSync } from "child_process";
import { readFileSync } from "node:fs";

describe("Deposit Circuit", () => {
    it("Should correctly calculate the commitment hash", async () => {
        execSync("circom circuits/deposit.circom --r1cs --wasm --sym -o circuits");

        const wasmBuffer = readFileSync("./circuits/deposit_js/deposit.wasm");

        const witnessCalculator = await WitnessCalculatorBuilder(
            wasmBuffer
        );

        const secret = BigInt(`0x${randomBytes(32).toString('hex')}`)
        const nullifier = BigInt(`0x${randomBytes(32).toString('hex')}`)

        const witness = await witnessCalculator.calculateWitness({ secret, nullifier }, true);

        assert.ok(witness, "Witness should be generated");
    })
});