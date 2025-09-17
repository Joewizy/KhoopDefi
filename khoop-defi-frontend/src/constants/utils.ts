// utils.ts
import { formatUnits } from 'viem';

/**
 * Formats a USDT value (BigInt) to a human-readable string with decimals.
 * @param value The USDT amount as BigInt or string (18 decimals)
 * @param decimals Number of decimals (default 18 for USDT/ERC20)
 * @returns Formatted string
 */
export function formatUSDT(value: bigint | string, decimals = 18): string {
  return Number(formatUnits(value, decimals)).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

/**
 * Converts a UNIX timestamp (seconds) to a human-readable date/time string
 * @param timestamp Timestamp in seconds (BigInt or number)
 * @returns Formatted date/time string
 */
export function formatTimestamp(timestamp: bigint | number): string {
  const date = new Date(
    typeof timestamp === 'bigint' ? Number(timestamp) * 1000 : timestamp * 1000
  );
  return date.toLocaleString(undefined, {
    year: 'numeric',
    month: 'short',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
}
