import { http, createConfig } from '@wagmi/vue'
import { hardhat, mainnet } from '@wagmi/vue/chains'
import { injected } from '@wagmi/vue/connectors'

export const config = createConfig({
  chains: [hardhat],
  connectors: [injected()],
  transports: {
    [hardhat.id]: http(),
  },
})
