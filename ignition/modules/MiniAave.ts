import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('MiniAaveModule', (m) => {
	const priceOracle = m.contract('PriceOracle')
	const interestRateStrategy = m.contract('InterestRateStrategy')

	const lendingPool = m.contract('LendingPool', [priceOracle, interestRateStrategy])

	const nftDescriptor = m.contract('NFTDescriptor', [lendingPool])
	const lendingNFT = m.contract('LendingNFT', [lendingPool, nftDescriptor])

	const weth = m.contract('MockERC20', ['Wrapped Ether', 'WETH'], { id: 'WETH_Token' })
	const dai = m.contract('MockERC20', ['Dai Stablecoin', 'DAI'], { id: 'DAI_Token' })

	const aWeth = m.contract('AToken', [lendingPool, weth, 'MiniAave WETH', 'aWETH'], { id: 'aWETH_Token' })
	const aDai = m.contract('AToken', [lendingPool, dai, 'MiniAave DAI', 'aDAI'], { id: 'aDAI_Token' })


	m.call(lendingPool, 'setNFTContract', [lendingNFT])

	m.call(priceOracle, 'setAssetPrice', [weth, 2000n * 10n ** 8n], { id: 'SetWETHPrice' }) // WETH = $2000
	m.call(priceOracle, 'setAssetPrice', [dai, 1n * 10n ** 8n], { id: 'SetDAIPrice' }) // DAI = $1

	m.call(lendingPool, 'addAsset', [weth, aWeth, 8000n, 8500n, 10500n], { id: 'AddWETH' })
	m.call(lendingPool, 'addAsset', [dai, aDai, 7500n, 8000n, 10500n], { id: 'AddDAI' })

	return {
		lendingPool,
		priceOracle,
		weth,
		dai,
		lendingNFT,
	}
})
