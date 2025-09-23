"use client"

import { useWatchContractEvent } from "wagmi"
import { getPublicClient } from "@wagmi/core"
import type { Abi, AbiEvent } from "viem"
import { khoopAbi, khoopAddress } from "./abi"
import config from "../rainbowKitConfig"

type EventConfig = {
  name: string
  format: (log: any) => any
}

const eventDefinitions: EventConfig[] = [
  {
    name: "EntryPurchased",
    format: (log) => ({
      type: "EntryPurchased",
      user: log.args.user,
      referrer: log.args.refferer,
      entryId: log.args.entryId?.toString(),
      amount: log.args.amount?.toString(),
      txHash: log.transactionHash,
    }),
  },
  {
    name: "CycleCompleted",
    format: (log) => ({
      type: "CycleCompleted",
      user: log.args.user,
      entryId: log.args.entryId?.toString(),
      profitPaid: log.args.profitPaid?.toString(),
      txHash: log.transactionHash,
    }),
  },
  {
    name: "ReffererBonusPaid",
    format: (log) => ({
      type: "Referral Commission",
      referrer: log.args.refferer,
      referred: log.args.referred,
      amount: log.args.amount?.toString(),
      txHash: log.transactionHash,
    }),
  },
  {
    name: "UserRegistered",
    format: (log) => ({
      type: "UserRegistered",
      user: log.args.user,
      referrer: log.args.refferer,
      txHash: log.transactionHash,
    }),
  },
  {
    name: "BalanceWithdrawn",
    format: (log) => ({
      type: "Withdrawal",
      user: log.args.user,
      amount: log.args.amount?.toString(),
      txHash: log.transactionHash,
    }),
  },
  {
    name: "BatchEntryPurchased",
    format: (log) => ({
      type: "BatchEntryPurchased",
      user: log.args.user,
      referrer: log.args.refferer,
      startId: log.args.startId?.toString(),
      endId: log.args.endId?.toString(),
      amount: log.args.amount?.toString(),
      txHash: log.transactionHash,
    }),
  },
  {
    name: "BuybackAutoFill",
    format: (log) => ({
      type: "BuybackAutoFill",
      entryId: log.args.entryId?.toString(),
      amount: log.args.amount?.toString(),
      txHash: log.transactionHash,
    }),
  },
  {
    name: "TeamSharesDistributed",
    format: (log) => ({
      type: "TeamSharesDistributed",
      distributed: log.args.distributedTeamShares?.toString(),
      txHash: log.transactionHash,
    }),
  },
  {
    name: "MultipleAutoFillsProcessed",
    format: (log) => ({
      type: "MultipleAutoFillsProcessed",
      count: log.args.count?.toString(),
      remainingBuyback: log.args.remainingBuyback?.toString(),
      txHash: log.transactionHash,
    }),
  },
]

// 🔹 Hook: watch all events in real-time
export function useContractEvents(onEvent: (event: any) => void) {
  eventDefinitions.forEach(({ name, format }) => {
    useWatchContractEvent({
      address: khoopAddress,
      abi: khoopAbi as Abi,
      eventName: name,
      onLogs(logs) {
        logs.forEach(log => onEvent(format(log)))
      },
    })
  })
}

// 🔹 Fetch past events (chunked, supports filters)
export async function fetchPastEvents(
  eventName: string,
  fromBlock: bigint = 0n,
  toBlock: bigint | "latest" = "latest",
  chunkSize: bigint = 10000n, // larger chunks are faster but risk RPC timeout
  args?: Record<string, any> // optional indexed filter
) {
  const publicClient = getPublicClient(config)
  if (!publicClient) throw new Error("No public client found")

  const eventAbi = (khoopAbi as any).find(
    (item: any) => item.type === "event" && item.name === eventName
  ) as AbiEvent
  if (!eventAbi) throw new Error(`Event ${eventName} not found in ABI`)

  // get latest block if toBlock is "latest"
  let currentTo =
    toBlock === "latest" ? await publicClient.getBlockNumber() : toBlock

  let logsAll: any[] = []
  let start = fromBlock

  while (start <= currentTo) {
    let end = start + chunkSize - 1n
    if (end > currentTo) end = currentTo

    try {
      const logsChunk = await publicClient.getLogs({
        address: khoopAddress,
        event: eventAbi,
        fromBlock: start,
        toBlock: end,
        args, // e.g. { user: address }
      })

      logsAll.push(
        ...logsChunk.map((log) => ({
          eventName,
          args: log.args,
          txHash: log.transactionHash,
          blockNumber: log.blockNumber,
        }))
      )
    } catch (err) {
      console.error(`Error fetching logs from ${start} to ${end}`, err)
    }

    start = end + 1n
  }

  return logsAll
}
