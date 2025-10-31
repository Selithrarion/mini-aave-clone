<script setup lang="ts">
import { ref, computed } from 'vue'
import {
  useAccount,
  useConnect,
  useDisconnect,
  useReadContract,
  useWriteContract,
  useSwitchChain,
  useBalance,
} from '@wagmi/vue'
import { injected } from '@wagmi/vue/connectors'
import { parseEther } from 'viem'
import { hardhat } from '@wagmi/vue/chains'

import { lendingPoolAbi, wethAbi, lendingNftAbi } from './contracts/lendingPool'

const { address, isConnected, chainId } = useAccount()
const { connect } = useConnect()
const { disconnect } = useDisconnect()
const { writeContract } = useWriteContract()
const { switchChain } = useSwitchChain()

const lendingPoolAddress = '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9'
const wethAddress = '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9'
const daiAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3'
const lendingNftAddress = '0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0'

const depositAmount = ref('0.01')
const withdrawAmount = ref('0.005')
const borrowAmount = ref('10')
const repayAmount = ref('5')

const { data: accountData, refetch: refetchAccountData } = useReadContract({
  abi: lendingPoolAbi,
  address: lendingPoolAddress,
  functionName: 'getUserAccountData',
  args: [address],
  query: {
    enabled: isConnected,
  },
})

const { data: wethBalance, refetch: refetchWethBalance } = useBalance({
  address,
  token: wethAddress,
  query: {
    enabled: isConnected,
  },
})

const { data: daiBalance, refetch: refetchDaiBalance } = useBalance({
  address,
  token: daiAddress,
  query: {
    enabled: isConnected,
  },
})

const { data: nftBalance } = useReadContract({
  abi: lendingNftAbi,
  address: lendingNftAddress,
  functionName: 'balanceOf',
  args: [address],
  query: { enabled: isConnected },
})

const { data: tokenURI } = useReadContract({
  abi: lendingNftAbi,
  address: lendingNftAddress,
  functionName: 'tokenURI',
  args: [0n], // temp
  query: {
    enabled: computed(() => (nftBalance.value ?? 0) > 0),
  },
})

const nftImage = computed(() => {
  if (!tokenURI.value) return ''
  // tokenURI: "data:application/json;base64,..."
  const jsonBase64 = tokenURI.value.substring(29)
  const jsonString = atob(jsonBase64)
  const metadata = JSON.parse(jsonString)
  // metadata.image: "data:image/svg+xml;base64,..."
  return metadata.image
})

function approve() {
  writeContract(
    {
      abi: wethAbi,
      address: wethAddress,
      functionName: 'approve',
      args: [lendingPoolAddress, parseEther(depositAmount.value)],
    },
    {
      onSuccess: () => alert('Approve successful!'),
    },
  )
}

function approveDai() {
  writeContract(
    {
      abi: wethAbi,
      address: daiAddress,
      functionName: 'approve',
      args: [lendingPoolAddress, parseEther(repayAmount.value)],
    },
    {
      onSuccess: () => alert('DAI Approve successful!'),
    },
  )
}

function deposit() {
  writeContract(
    {
      abi: lendingPoolAbi,
      address: lendingPoolAddress,
      functionName: 'deposit',
      args: [wethAddress, parseEther(depositAmount.value)],
    },
    {
      onSuccess: () => {
        refetchAccountData()
        refetchWethBalance()
        refetchDaiBalance()
      },
    },
  )
}

function withdraw() {
  writeContract(
    {
      abi: lendingPoolAbi,
      address: lendingPoolAddress,
      functionName: 'withdraw',
      args: [wethAddress, parseEther(withdrawAmount.value)],
    },
    {
      onSuccess: () => {
        refetchAccountData()
        refetchWethBalance()
        refetchDaiBalance()
      },
    },
  )
}

function borrow() {
  writeContract(
    {
      abi: lendingPoolAbi,
      address: lendingPoolAddress,
      functionName: 'borrow',
      args: [daiAddress, parseEther(borrowAmount.value)],
    },
    {
      onSuccess: () => {
        refetchAccountData()
        refetchDaiBalance()
      },
    },
  )
}

function repay() {
  writeContract(
    {
      abi: lendingPoolAbi,
      address: lendingPoolAddress,
      functionName: 'repay',
      args: [daiAddress, parseEther(repayAmount.value)],
    },
    {
      onSuccess: () => {
        refetchAccountData()
        refetchDaiBalance()
      },
    },
  )
}
</script>

<template>
  <div>
    <h1>MiniAave</h1>

    <button v-if="!isConnected" @click="() => connect({ connector: injected() })">
      Connect Wallet
    </button>
    <div v-if="isConnected">
      <span>Connected: {{ address }}</span>
      <button @click="() => disconnect()">Disconnect</button>
    </div>

    <hr />

    <div v-if="isConnected && chainId !== hardhat.id">
      <p style="color: red">Wrong Network!</p>
      <button @click="() => switchChain({ chainId: hardhat.id })">Switch to Hardhat Network</button>
      <hr />
    </div>

    <div v-if="isConnected && chainId === hardhat.id">
      <h2>Your Account Data</h2>
      <p v-if="wethBalance">Your WETH Balance: {{ wethBalance.formatted }}</p>
      <p v-if="daiBalance">Your DAI Balance: {{ daiBalance.formatted }}</p>
      <div v-if="accountData">
        <p>Total Collateral (USD): {{ accountData[0] / 10n ** 18n }}</p>
        <p>Total Debt (USD): {{ accountData[1] / 10n ** 18n }}</p>
        <p>Earned Interest (USD): {{ Number(accountData[2]) / 1e18 }}</p>
        <p>Health Factor: {{ Number(accountData[3]) / 1e18 }}</p>
      </div>

      <div v-if="nftBalance && nftBalance > 0 && nftImage">
        <h3>Your Deposit NFT</h3>
        <img :src="nftImage" alt="Your Deposit NFT" width="200" />
      </div>

      <div
        style="margin-top: 20px; display: flex; flex-direction: column; gap: 10px; max-width: 300px"
      >
        <div>
          <input v-model="depositAmount" type="text" />
          <button @click="approve">1. Approve WETH</button>
          <button @click="deposit">2. Deposit WETH</button>
        </div>
        <div>
          <input v-model="withdrawAmount" type="text" />
          <button @click="withdraw">Withdraw WETH</button>
        </div>
        <div>
          <input v-model="borrowAmount" type="text" />
          <button @click="borrow">Borrow DAI</button>
        </div>
        <div>
          <input v-model="repayAmount" type="text" />
          <button @click="approveDai">1. Approve DAI</button>
          <button @click="repay">2. Repay DAI</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped></style>
