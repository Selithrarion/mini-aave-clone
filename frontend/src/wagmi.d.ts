import { type config } from './wagmi'

declare module '@wagmi/vue' {
  interface Register {
    config: typeof config
  }
}
