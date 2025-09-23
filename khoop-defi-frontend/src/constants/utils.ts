// utils.ts
import { formatUnits } from 'viem';

// Helper function to format timestamp
export function formatTimestamp(timestamp: number): string {
  const now = Date.now();
  const diff = now - timestamp;
  
  const minutes = Math.floor(diff / 60000);
  const hours = Math.floor(diff / 3600000);
  const days = Math.floor(diff / 86400000);
  
  if (days > 0) return `${days} day${days > 1 ? 's' : ''} ago`;
  if (hours > 0) return `${hours} hour${hours > 1 ? 's' : ''} ago`;
  if (minutes > 0) return `${minutes} minute${minutes > 1 ? 's' : ''} ago`;
  return 'Just now';
};

/**
 * Formats a USDT value (BigInt) to a human-readable string with decimals.
 * @param value The USDT amount as BigInt or string (18 decimals)
 * @param decimals Number of decimals (default 18 for USDT/ERC20)
 * @returns Formatted string
 */
export function formatUSDT(value: bigint | string | number, decimals = 18): string {
  const valueToFormat = typeof value === 'string' || typeof value === 'number' 
    ? BigInt(Math.floor(Number(value))) 
    : value;
    
  return Number(formatUnits(valueToFormat, decimals)).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

/**
 * Converts a UNIX timestamp (seconds) to a human-readable date/time string
 * @param timestamp Timestamp in seconds (BigInt or number)
 * @returns Formatted date/time string
//  */
// export function formatTimestamp(timestamp: bigint | number): string {
//   const date = new Date(
//     typeof timestamp === 'bigint' ? Number(timestamp) * 1000 : timestamp * 1000
//   );
//   return date.toLocaleString(undefined, {
//     year: 'numeric',
//     month: 'short',
//     day: '2-digit',
//     hour: '2-digit',
//     minute: '2-digit',
//     second: '2-digit',
//   });
// }

/**
 * Format bigint or number into a plain integer string.
 * No decimals, no trailing .00
 */
export function formatNumber(value: bigint | number | undefined): string {
  if (value === undefined) return "0";
  return value.toString();
}

