import { network } from 'hardhat'
import { parseEther } from 'viem'

async function main() {
	const { viem } = await network.connect()

	const [owner] = await viem.getWalletClients()
	const userAddress = owner.account.address

	const wethAddress = '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9'
	const daiAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3'

	const weth = await viem.getContractAt('MockERC20', wethAddress)
	const dai = await viem.getContractAt('MockERC20', daiAddress)

	console.log(`Minting 100 WETH to ${userAddress}...`)
	const txWeth = await weth.write.mint([userAddress, parseEther('100')])
	const publuc = await viem.getPublicClient()
	await publuc.waitForTransactionReceipt({ hash: txWeth })
	console.log('WETH Minted successfully!')

	console.log(`Minting 10000 DAI to ${userAddress}...`)
	const txDai = await dai.write.mint([userAddress, parseEther('10000')])
	await publuc.waitForTransactionReceipt({ hash: txDai })
	console.log('DAI Minted successfully!')
}

main().catch((error) => {
	console.error(error)
	process.exitCode = 1
})
