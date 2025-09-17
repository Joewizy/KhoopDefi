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

  console.log("raw userStats", data)

  const user: UserStruct | undefined = data
    ? {
        refferer: data[0],
        entriesPurchased: BigInt(data[1]),
        entriesFilled: BigInt(data[2]),
        reffererBonusEarned: BigInt(data[3]),
        slotFillEarnings: BigInt(data[4]),
        totalReferrals: BigInt(data[5]),
        lastEntryAt: BigInt(data[6]),
        dailyEntries: BigInt(data[7]),
        lastDailyReset: BigInt(data[8]),
        isRegistered: data[9],
      }
    : undefined;

  return { user, isLoading, isError };
}

export function useGlobalStats() {
    const { data, isLoading, isError } = useReadContract({
      address: khoopAddress as `0x${string}`,
      abi: khoopAbi,
      functionName: 'globalStats', // or 'getGlobalStats'
    });
  
    console.log("raw globalStats", data);
  
    const stats: GlobalStatsStruct | undefined = data
      ? {
          totalUsers: BigInt(data[0]),
          totalEntriesPurchased: BigInt(data[1]),
          totalReffererBonusPaid: BigInt(data[2]),
          totalSlotFillPaid: BigInt(data[3]),
          totalEntriesCompleted: BigInt(data[4]),
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
  
    const entry: EntryStruct | undefined = data
      ? {
          entryId: BigInt(data[0]),
          user: data[1],
          timestamp: BigInt(data[2]),
          isCompleted: data[3],
          completionTime: BigInt(data[4]),
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
  
    // Convert array of BigInts for consistency
    const pendingEntries: bigint[] | undefined = data
      ? (data as Array<any>).map((id) => BigInt(id))
      : undefined;
  
    return { pendingEntries, isLoading, isError };
  }