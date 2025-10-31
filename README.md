# mini-aave-clone

a lending protocol study, kinda like aave  

## features

*   core defi logic: deposit, borrow, withdraw, repay, liquidations and flash loans.
*   dynamic nfts: you get an nft when you deposit and it changes based on your position.
*   zk-proof: a private pool using circom and snarkjs (wip).
*   tests: covered with hardhat 3.
*   frontend: a basic vue + wagmi interface to interact with the protocol.

## todo

*   finalize the zk-proof system with merkle trees for the private pool.
*   polish the frontend and add merkle tree support
* study https://github.com/tornadocash/tornado-core/blob/1ef6a263ac6a0e476d063fcb269a9df65a1bd56a/circuits/withdraw.circom
* study https://github.com/mjerkov/membership/blob/main/scripts/proof.sh

## how to run

1.  start a local node in one terminal:
    ```sh
    npx hardhat node
    ```

2.  deploy the contracts in another terminal:

    ```sh
    npx hardhat ignition deploy --network localhost ./ignition/modules/MiniAave.ts
    ```

3.  mint some test tokens to your wallet (the first account from the node):

    ```sh
    npx hardhat run scripts/mintTokens.ts --network localhost
    ```

4.  run the frontend:
    ```sh
    cd frontend
    pnpm install
    pnpm dev
    ```