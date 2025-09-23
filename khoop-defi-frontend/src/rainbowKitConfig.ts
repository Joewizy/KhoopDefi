"use client"

import { getDefaultConfig } from "@rainbow-me/rainbowkit"
import { bscTestnet } from "viem/chains"
import { lightTheme } from '@rainbow-me/rainbowkit'
import { http } from "viem"

const projectId = import.meta.env.VITE_WALLET_CONNECT_ID || "YOUR_WALLET_CONNECT_PROJECT_ID"

if (!import.meta.env.VITE_BNB_KEY) {
    throw new Error("VITE_BNB_KEY is not defined")
}

const transports = {
  [bscTestnet.id]: http(import.meta.env.VITE_BNB_KEY),
}



export default getDefaultConfig({
    appName: "Khoop-defi",
    projectId: projectId,
    chains: [bscTestnet],
    ssr: false,
    transports: transports
})

// Custom theme for RainbowKit
export const rainbowKitTheme = lightTheme({
    accentColor: '#5C4B99',
    accentColorForeground: 'white',
    borderRadius: 'large',
    fontStack: 'system',
    overlayBlur: 'small',
})