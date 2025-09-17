"use client"

import { getDefaultConfig } from "@rainbow-me/rainbowkit"
import { bscTestnet } from "viem/chains"
import { lightTheme } from '@rainbow-me/rainbowkit'

const projectId = import.meta.env.VITE_WALLET_CONNECT_ID || "YOUR_WALLET_CONNECT_PROJECT_ID"


export default getDefaultConfig({
    appName: "Swap-Chain",
    projectId: projectId,
    chains: [bscTestnet],
    ssr: false
})

// Custom theme for RainbowKit
export const rainbowKitTheme = lightTheme({
    accentColor: '#5C4B99',
    accentColorForeground: 'white',
    borderRadius: 'large',
    fontStack: 'system',
    overlayBlur: 'small',
})