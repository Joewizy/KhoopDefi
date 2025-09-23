import React, { useState, useEffect } from 'react';
import { useAccount } from 'wagmi';
import { formatUnits } from 'viem';
import { getPublicClient } from '@wagmi/core';
import {
  FaHistory,
  FaInfinity,
  FaShoppingCart,
  FaUsers,
} from 'react-icons/fa';
import { FiExternalLink } from 'react-icons/fi';
import { useContractEvents, fetchPastEvents } from '../constants/event';
import config from '../rainbowKitConfig';

// Define the transaction interface
interface Transaction {
  id: string;
  type: string;
  icon: React.ComponentType<any>;
  iconBg: string;
  iconColor: string;
  timestamp: string; // Formatted for display (e.g., "4 minutes ago")
  rawTimestamp: number; // Raw timestamp for sorting
  details: string;
  amount: number;
  txHash?: string;
  status: 'Completed' | 'Pending' | 'Failed';
}

// Helper function to format timestamp
const formatTimestamp = (timestamp: number): string => {
  const now = Date.now();
  const diff = now - timestamp * 1000; // Convert seconds to milliseconds
  const minutes = Math.floor(diff / 60000);
  const hours = Math.floor(diff / 3600000);
  const days = Math.floor(diff / 86400000);
  if (days > 0) return `${days} day${days > 1 ? 's' : ''} ago`;
  if (hours > 0) return `${hours} hour${hours > 1 ? 's' : ''} ago`;
  if (minutes > 0) return `${minutes} minute${minutes > 1 ? 's' : ''} ago`;
  return 'Just now';
};

// Helper function to format address
const formatAddress = (address: string): string => {
  if (!address || typeof address !== 'string') return 'Unknown';
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
};

// Helper function to convert wei to USDT (assuming 18 decimals)
const formatAmount = (amountWei: string): number => {
  try {
    if (!amountWei) return 0;
    return parseFloat(formatUnits(BigInt(amountWei), 18));
  } catch (error) {
    console.warn('Error formatting amount:', amountWei, error);
    return 0;
  }
};

// Helper function to fetch block timestamp with caching
const blockTimestamps = new Map<bigint, number>();
const fetchBlockTimestamp = async (blockNumber: bigint): Promise<number> => {
  if (blockTimestamps.has(blockNumber)) {
    return blockTimestamps.get(blockNumber)!;
  }
  const publicClient = getPublicClient(config);
  if (!publicClient) throw new Error('No public client found');
  const block = await publicClient.getBlock({ blockNumber });
  const timestamp = Number(block.timestamp);
  blockTimestamps.set(blockNumber, timestamp);
  return timestamp;
};

const History: React.FC = () => {
  const { address } = useAccount();
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadHistory = async () => {
      if (!address) return;
      setIsLoading(true);
      setError(null);
      try {
        const publicClient = getPublicClient(config);
        if (!publicClient) throw new Error('No public client found');

        // Estimate block range for the last 3 days (~86400 blocks assuming 3s block time for BSC Testnet)
        const latestBlock = await publicClient.getBlockNumber();
        const blocksPerDay = 28800; // 86,400 seconds / 3 seconds per block
        const fromBlock = latestBlock - BigInt(3 * blocksPerDay); // 3 days
        const maxBlockRange = 10000n; // Alchemy's max block range for eth_getLogs

        // Split the block range into smaller chunks
        const allEvents: any[] = [];
        let currentFromBlock = fromBlock;
        while (currentFromBlock < latestBlock) {
          const toBlock = currentFromBlock + maxBlockRange - 1n > latestBlock ? latestBlock : currentFromBlock + maxBlockRange - 1n;

          // Fetch events for the current block range
          const batchEntries = await fetchPastEvents('BatchEntryPurchased', currentFromBlock, toBlock, maxBlockRange, { user: address });
          const cycles = await fetchPastEvents('CycleCompleted', currentFromBlock, toBlock, maxBlockRange, { user: address });
          const referrals = await fetchPastEvents('ReffererBonusPaid', currentFromBlock, toBlock, maxBlockRange, { referrer: address });

          allEvents.push(...batchEntries, ...cycles, ...referrals);
          currentFromBlock = toBlock + 1n;
        }

        console.log('allEvents', allEvents);

        // Map events to transactions
        const mappedTransactions: Transaction[] = [];
        for (const event of allEvents) {
          let transaction: Transaction | null = null;
          const blockTimestamp = await fetchBlockTimestamp(event.blockNumber);

          switch (event.eventName) {
            case 'BatchEntryPurchased':
              const startId = parseInt(event.args.startId || '0');
              const endId = parseInt(event.args.endId || '0');
              const numEntries = endId >= startId ? endId - startId + 1 : 1;
              transaction = {
                id: `${event.txHash}-batch`,
                type: 'Slot Purchase',
                icon: FaShoppingCart,
                iconBg: 'bg-orange-500/20',
                iconColor: 'text-orange-400',
                timestamp: formatTimestamp(blockTimestamp),
                rawTimestamp: blockTimestamp,
                details: `${numEntries} slots purchased`,
                amount: -formatAmount(event.args.amount || '0'),
                txHash: event.txHash,
                status: 'Completed',
              };
              break;

            case 'CycleCompleted':
              transaction = {
                id: `${event.txHash}-${event.args.entryId || 'cycle'}`,
                type: 'Cycle Completed',
                icon: FaInfinity,
                iconBg: 'bg-green-500/20',
                iconColor: 'text-green-400',
                timestamp: formatTimestamp(blockTimestamp),
                rawTimestamp: blockTimestamp,
                details: `Slot #${event.args.entryId || 'N/A'} completed`,
                amount: formatAmount(event.args.profitPaid || '0'),
                txHash: event.txHash,
                status: 'Completed',
              };
              break;

            case 'ReffererBonusPaid':
              transaction = {
                id: `${event.txHash}-referral`,
                type: 'Referral Bonus Paid',
                icon: FaUsers,
                iconBg: 'bg-purple-500/20',
                iconColor: 'text-purple-400',
                timestamp: formatTimestamp(blockTimestamp),
                rawTimestamp: blockTimestamp,
                details: `From user ${formatAddress(event.args.referred || '')}`,
                amount: formatAmount(event.args.amount || '0'),
                txHash: event.txHash,
                status: 'Completed',
              };
              break;

            default:
              break;
          }

          if (transaction) {
            // Avoid duplicates
            if (!mappedTransactions.some((tx) => tx.id === transaction!.id)) {
              mappedTransactions.push(transaction);
            }
          }
        }

        // Sort transactions by rawTimestamp (newest first)
        mappedTransactions.sort((a, b) => b.rawTimestamp - a.rawTimestamp);

        setTransactions(mappedTransactions);
      } catch (error) {
        console.error('Error loading transaction history:', error);
        setError('Failed to load recent transactions. Please try again.');
      } finally {
        setIsLoading(false);
      }
    };

    loadHistory();
  }, [address]);

  // Event handler for contract events
  const handleContractEvent = (event: any) => {
    try {
      if (!address || !event) return;
      console.log('Events:', event);
      const timestamp = Math.floor(Date.now() / 1000); // Current time in seconds
      let transaction: Transaction | null = null;

      switch (event.eventName) {
        case 'BatchEntryPurchased':
          if (event.args.user?.toLowerCase() === address.toLowerCase()) {
            const startId = parseInt(event.args.startId || '0');
            const endId = parseInt(event.args.endId || '0');
            const numEntries = endId >= startId ? endId - startId + 1 : 1;
            transaction = {
              id: `${event.txHash || Date.now()}-batch`,
              type: 'Slot Purchase',
              icon: FaShoppingCart,
              iconBg: 'bg-orange-500/20',
              iconColor: 'text-orange-400',
              timestamp: formatTimestamp(timestamp),
              rawTimestamp: timestamp,
              details: `${numEntries} slots purchased`,
              amount: -formatAmount(event.args.amount || '0'),
              txHash: event.txHash,
              status: 'Completed',
            };
          }
          break;

        case 'CycleCompleted':
          if (event.args.user?.toLowerCase() === address.toLowerCase()) {
            transaction = {
              id: `${event.txHash || Date.now()}-${event.args.entryId || 'cycle'}`,
              type: 'Cycle Completed',
              icon: FaInfinity,
              iconBg: 'bg-green-500/20',
              iconColor: 'text-green-400',
              timestamp: formatTimestamp(timestamp),
              rawTimestamp: timestamp,
              details: `Slot #${event.args.entryId || 'N/A'} completed`,
              amount: formatAmount(event.args.profitPaid || '0'),
              txHash: event.txHash,
              status: 'Completed',
            };
          }
          break;

        case 'ReffererBonusPaid':
          if (event.args.referrer?.toLowerCase() === address.toLowerCase()) {
            transaction = {
              id: `${event.txHash || Date.now()}-referral`,
              type: 'Referral Bonus Paid',
              icon: FaUsers,
              iconBg: 'bg-purple-500/20',
              iconColor: 'text-purple-400',
              timestamp: formatTimestamp(timestamp),
              rawTimestamp: timestamp,
              details: `From user ${formatAddress(event.args.referred || '')}`,
              amount: formatAmount(event.args.amount || '0'),
              txHash: event.txHash,
              status: 'Completed',
            };
          }
          break;

        default:
          break;
      }

      if (transaction) {
        setTransactions((prev) => {
          // Avoid duplicates
          const exists = prev.some((tx) => tx.id === transaction!.id);
          if (exists) return prev;
          // Sort after adding new transaction
          return [transaction!, ...prev].sort((a, b) => b.rawTimestamp - a.rawTimestamp);
        });
      }
    } catch (error) {
      console.error('Error handling contract event:', error);
    }
  };

  // Use the contract events hook
  useContractEvents(handleContractEvent);

  // Open transaction in block explorer
  const openTransaction = (txHash: string) => {
    try {
      if (txHash) {
        window.open(`https://testnet.bscscan.com/tx/${txHash}`, '_blank');
      }
    } catch (error) {
      console.error('Error opening transaction:', error);
    }
  };

  return (
    <div className="rounded-2xl border border-white/15 bg-white/5 p-4 text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.18)] backdrop-blur-md md:p-6">
      <h2 className="mb-4 flex items-center text-xl font-bold text-teal-300 md:mb-6 md:text-2xl">
        <FaHistory className="mr-3" />
        Transaction History
      </h2>
      {error ? (
        <div className="py-8 text-center">
          <p className="text-red-400">{error}</p>
        </div>
      ) : isLoading ? (
        <div className="space-y-4">
          {[...Array(3)].map((_, i) => (
            <div key={i} className="animate-pulse">
              <div className="flex items-center gap-4">
                <div className="h-10 w-10 rounded-full bg-white/10"></div>
                <div className="flex-1 space-y-2">
                  <div className="h-4 w-1/3 rounded bg-white/10"></div>
                  <div className="h-3 w-1/2 rounded bg-white/10"></div>
                </div>
                <div className="h-4 w-16 rounded bg-white/10"></div>
              </div>
            </div>
          ))}
        </div>
      ) : transactions.length === 0 ? (
        <div className="py-8 text-center">
          <FaHistory className="mx-auto mb-4 text-4xl text-gray-500" />
          <p className="text-gray-400">No transactions in the last 3 days</p>
          <p className="text-sm text-gray-500">Your recent transaction history will appear here when you interact with the contract</p>
        </div>
      ) : (
        <div className="space-y-2">
          {transactions.slice(0, 10).map((tx, index) => (
            <div
              key={tx.id}
              className={`flex flex-col gap-3 py-4 sm:flex-row sm:items-center sm:justify-between ${
                index < Math.min(transactions.length, 10) - 1 ? 'border-b border-[#0CC3B5]/30' : ''
              }`}
            >
              <div className="flex min-w-0 items-start gap-3 sm:items-center sm:gap-4">
                <div className={`flex h-9 w-9 flex-none items-center justify-center rounded-full ${tx.iconBg} md:h-10 md:w-10`}>
                  <tx.icon className={`text-base ${tx.iconColor} md:text-lg`} />
                </div>
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-2 md:gap-3">
                    <h3 className="truncate text-base font-bold md:text-lg">{tx.type}</h3>
                    <span
                      className={`rounded-full px-2 py-0.5 text-[10px] font-semibold md:text-xs ${
                        tx.status === 'Completed'
                          ? 'bg-[#0CC3B5]/20 text-[#0CC3B5]'
                          : tx.status === 'Pending'
                          ? 'bg-yellow-500/20 text-yellow-400'
                          : 'bg-red-500/20 text-red-400'
                      }`}
                    >
                      {tx.status}
                    </span>
                  </div>
                  <p className="whitespace-normal break-words text-xs text-gray-400 md:text-sm">
                    {tx.timestamp} · {tx.details}
                  </p>
                </div>
              </div>
              <div className="flex shrink-0 items-center justify-between gap-4 sm:gap-6">
                <div className="text-right">
                  {tx.amount !== 0 && (
                    <>
                      <p
                        className={`text-base font-bold md:text-lg ${
                          tx.amount > 0
                            ? 'text-green-400'
                            : tx.type === 'Withdrawal'
                            ? 'text-amber-400'
                            : 'text-red-400'
                        }`}
                      >
                        {tx.amount > 0 ? `+${tx.amount.toFixed(2)}` : tx.amount.toFixed(2)}
                      </p>
                      <p className="text-xs text-gray-500 md:text-sm">USDT</p>
                    </>
                  )}
                </div>
                {tx.txHash && (
                  <FiExternalLink
                    className="cursor-pointer text-lg text-gray-500 hover:text-white md:text-xl"
                    onClick={() => openTransaction(tx.txHash!)}
                    title="View on block explorer"
                  />
                )}
              </div>
            </div>
          ))}
        </div>
      )}
      {transactions.length > 10 && (
        <div className="mt-6 text-center">
          <button className="rounded-lg bg-[#0CC3B5]/20 px-4 py-2 text-sm font-semibold text-[#0CC3B5] hover:bg-[#0CC3B5]/30 transition-colors">
            View All Transactions
          </button>
        </div>
      )}
    </div>
  );
};

export default History;