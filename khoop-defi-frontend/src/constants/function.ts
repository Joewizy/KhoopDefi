import { useReadContract } from 'wagmi';
import { khoopAbi, khoopAddress } from '../constants/abi';
import type { UserStruct, GlobalStatsStruct, EntryStruct } from './interface';

export function useUserDetails(userAddress: `0x${string}`) {
  const { data, isLoading, isError } = useReadContract({
    address: khoopAddress as `0x${string}`,
    abi: khoopAbi,
    functionName: 'users',
    args: [userAddress],
  });

  console.log("raw userStats", data);

  const user: UserStruct | undefined = data && Array.isArray(data) && data.length >= 10
    ? {
        refferer: data[0] as `0x${string}`,
        entriesPurchased: BigInt(data[1]?.toString() || '0'),
        entriesFilled: BigInt(data[2]?.toString() || '0'),
        reffererBonusEarned: BigInt(data[3]?.toString() || '0'),
        slotFillEarnings: BigInt(data[4]?.toString() || '0'),
        totalReferrals: BigInt(data[5]?.toString() || '0'),
        lastEntryAt: BigInt(data[6]?.toString() || '0'),
        dailyEntries: BigInt(data[7]?.toString() || '0'),
        lastDailyReset: BigInt(data[8]?.toString() || '0'),
        isRegistered: Boolean(data[9]),
      }
    : undefined;

  return { user, isLoading, isError };
}

export function useGlobalStats() {
  const { data, isLoading, isError } = useReadContract({
    address: khoopAddress as `0x${string}`,
    abi: khoopAbi,
    functionName: 'globalStats',
  });

  console.log("raw globalStats", data);

  const stats: GlobalStatsStruct | undefined = data && Array.isArray(data) && data.length >= 5
    ? {
        totalUsers: BigInt(data[0]?.toString() || '0'),
        totalEntriesPurchased: BigInt(data[1]?.toString() || '0'),
        totalReffererBonusPaid: BigInt(data[2]?.toString() || '0'),
        totalSlotFillPaid: BigInt(data[3]?.toString() || '0'),
        totalEntriesCompleted: BigInt(data[4]?.toString() || '0'),
      }
    : undefined;
  
  return { stats, isLoading, isError };
}

export function useEntry(entryId: bigint | number) {
  const { data, isLoading, isError } = useReadContract({
    address: khoopAddress as `0x${string}`,
    abi: khoopAbi,
    functionName: 'entries',
    args: [entryId],
  });

  console.log("raw entry", data);

  const entry: EntryStruct | undefined = data && Array.isArray(data) && data.length >= 5
    ? {
        entryId: BigInt(data[0]?.toString() || '0'),
        user: (data[1] as string) as `0x${string}`,
        timestamp: BigInt(data[2]?.toString() || '0'),
        isCompleted: Boolean(data[3]),
        completionTime: BigInt(data[4]?.toString() || '0'),
      }
    : undefined;
  
    return { entry, isLoading, isError };
  }
  
export function useUserPendingEntries(userAddress: `0x${string}`) {
  const { data, isLoading, isError } = useReadContract({
    address: khoopAddress as `0x${string}`,
    abi: khoopAbi,
    functionName: 'getUserPendingEntries',
    args: [userAddress],
  });

  console.log("raw pending entries", data);
  
  // Handle the response data safely
  const pendingEntries: bigint[] = [];
  
  if (Array.isArray(data)) {
    for (const item of data) {
      try {
        if (item !== null && item !== undefined) {
          pendingEntries.push(BigInt(item.toString()));
        }
      } catch (error) {
        console.error('Error converting entry ID to BigInt:', error);
      }
    }
  }

  return { pendingEntries, isLoading, isError };
}

  