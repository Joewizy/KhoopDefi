// User struct as TypeScript interface
export interface UserStruct {
  refferer: `0x${string}`;
  entriesPurchased: bigint;
  entriesFilled: bigint;
  reffererBonusEarned: bigint;
  slotFillEarnings: bigint;
  totalReferrals: bigint;
  lastEntryAt: bigint;
  dailyEntries: bigint;
  lastDailyReset: bigint;
  isRegistered: boolean;
}
  // Entry struct as TypeScript interface
  export interface EntryStruct {
    entryId: bigint;
    user: `0x${string}`;
    timestamp: bigint;
    isCompleted: boolean;
    completionTime: bigint;
  }
  
  // GlobalStats struct as TypeScript interface
  export interface GlobalStatsStruct {
    totalUsers: bigint;
    totalEntriesPurchased: bigint;
    totalReffererBonusPaid: bigint;
    totalSlotFillPaid: bigint;
    totalEntriesCompleted: bigint;
  }
  