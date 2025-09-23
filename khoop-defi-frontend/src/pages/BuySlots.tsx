import React, { useState } from 'react';
import { FaShoppingCart } from 'react-icons/fa';
import { BsExclamationCircle } from 'react-icons/bs';
import { waitForTransactionReceipt } from "@wagmi/core";
import { useAccount, useConfig, useReadContract, useWriteContract } from 'wagmi';
import { useUserDetails, useGlobalStats, useEntry, useUserPendingEntries } from '../constants/function';
import { khoopAddress, khoopAbi, usdtAbi, usdtAddress } from '../constants/abi';

const Divider: React.FC = () => (
  <div className="h-px w-full bg-white/10" />
);

const Row: React.FC<{ left: React.ReactNode; right: React.ReactNode }> = ({ left, right }) => (
  <div className="flex items-center justify-between text-sm">
    <span className="text-gray-300">{left}</span>
    <span className="text-gray-200">{right}</span>
  </div>
);

const Dot: React.FC<{ color: string }> = ({ color }) => (
  <span className={`mr-2 inline-block h-2 w-2 rounded-full ${color}`} />
);

const BuySlots: React.FC = () => {
  const config = useConfig();
  const {isConnected, address} = useAccount();
  const { writeContractAsync, isPending } = useWriteContract();
  const [numSlots, setNumSlots] = useState(1);

  const { user, isLoading: userloading } = useUserDetails(address as  `0x${string}`);
  const { stats } = useGlobalStats();
  const { entry } = useEntry(1);
  const { pendingEntries } = useUserPendingEntries(address as  `0x${string}`);
  
  // console.log("formattedUserStat", user)
  // console.log("Stats", stats)
  // console.log("Entry", entry)
  // console.log("Pending entries", pendingEntries)

  // Fetch USDT balance
  const { data: balance } = useReadContract({
    abi: usdtAbi,
    address: usdtAddress as `0x${string}`,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  console.log("Usdt Balance", balance)
  const usdtBalance = balance ? Number(balance) / 1e18 : 0;
  console.log("Formatted Balance", usdtBalance) // 9965,000000000000000000n

    // Fetch User Stats
    const { data: userStats } = useReadContract({
      abi: khoopAbi,
      address: khoopAddress as `0x${string}`,
      functionName: 'getUserStats',
      args: address ? [address] : undefined, 
    });
  
    async function purchaseSlot(numOfEntries: number, refferrer: string) {
      try {
        const response = await writeContractAsync({
          address: khoopAddress as `0x${string}`,
          abi: khoopAbi,
          functionName: "purchaseEntries",
          args: [BigInt(numOfEntries), refferrer],
        });

        const receipt = await waitForTransactionReceipt(config, { hash: response });
      if (receipt.status === "success") {
        alert("Succesfully purchased Slot")
      }
      } catch (error) {
        console.log("Error purchasing slot:", purchaseSlot)
        alert("Error purchasing slot try again")
      }
    }

    const handlePurchase = async () => {
      if (!isConnected || !address) {
        alert("Please connect your wallet first");
        return;
      }
  
      if (numSlots < 1 || numSlots > 10) {
        alert("Please select between 1-10 slots");
        return;
      }
  
      try {
        // Using a dummy referral address for now
        const dummyReferrer = "0x0000000000000000000000000000000000000000";
        await purchaseSlot(numSlots, dummyReferrer);
      } catch (error) {
        console.error("Purchase error:", error);
      }
    };


  return (
    <div className="rounded-2xl border border-white/15 bg-gradient-to-b from-[#6B63D8]/10 to-[#1B1840]/10 p-4 text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.18)] backdrop-blur-xl md:p-6">
      <h2 className="mb-6 flex items-center text-xl font-semibold md:text-2xl"><FaShoppingCart className="mr-3" />Buy Slots</h2>

      {!isConnected && ( 
      <div className="mb-6 flex items-center rounded-xl border border-yellow-300/40 bg-yellow-300/5 p-3 text-[#818182] md:p-4">
        <BsExclamationCircle className="mr-3 text-white" />
        <p className="text-sm md:text-base">Please connect your wallet to purchase slots.</p>
      </div>
      )}

      <div className="mb-6">
        <div className="mb-2 flex items-center justify-between">
          <label htmlFor="slots-input" className="text-sm text-gray-200">Number of Slots</label>
          <span className="rounded-md bg-white/10 px-2 py-0.5 text-xs text-gray-200">$15 each</span>
        </div>
        <div className="relative mb-4">
          <div className="h-1 rounded-full bg-[#FFD0F2]" />
          <div className="mt-1 flex justify-between text-xs text-gray-400">
            <span>1 slot</span>
            <span>10 max</span>
          </div>
        </div>
        <div className="flex items-center gap-4">
          <input
            id="slots-input"
            type="number"
            value={numSlots}
            min={1}
            max={10}
            onChange={(e) => setNumSlots(Number(e.target.value))}
            className="w-full rounded-lg border border-white/15 bg-[#1B1840]/40 p-3 text-center outline-none placeholder:text-gray-500"
          />
          <button onClick={() => setNumSlots(10)}
           className="w-full rounded-lg border border-white/15 bg-[#1B1840]/40 p-3 text-gray-200">Max (10)</button>
        </div>
      </div>

      <Divider />

      <div className="mb-6 mt-6 space-y-2">
        <Row left={<span className="text-gray-300">Total Cost:</span>} right={<span className="text-lg font-semibold">$15 USDT</span>} />
        <Row left={<span className="text-gray-300">Your USDT Balance:</span>} right={<span className="text-lg font-semibold text-green-400">${usdtBalance ?? 0} USDT</span>} />
      </div>

      <Divider />

      <div className="mb-8 mt-6 text-sm text-gray-300">
        <p className="mb-3 font-semibold text-gray-200">Distribution Breakdown</p>
        <div className="space-y-2">
          <Row left={<span className="flex items-center"><Dot color="bg-blue-400" />Next ID in Matrix</span>} right={<span>$3</span>} />
          <Row left={<span className="flex items-center"><Dot color="bg-green-400" />Buyback Pool</span>} right={<span>$1</span>} />
          <Row left={<span className="flex items-center"><Dot color="bg-purple-400" />Referral Commission</span>} right={<span>$1</span>} />
          <Row left={<span className="flex items-center"><Dot color="bg-orange-400" />System Wallets</span>} right={<span>$1</span>} />
        </div>
      </div>

      <Divider />

      <div className="mb-8 mt-6 space-y-2 text-sm text-gray-400">
        <Row left={<span>Daily limit remaining:</span>} right={<span>43/50 slots</span>} />
        <Row left={<span>Per purchase limit:</span>} right={<span>1-10 slots</span>} />
        <Row left={<span>Minimum wait time:</span>} right={<span>10 minutes</span>} />
      </div>

      <div className="pt-2">
        <button 
          onClick={handlePurchase}
          disabled={isPending}
          className={`w-full rounded-full bg-gradient-to-r from-[#2D22D2] to-[#0CC3B5] px-6 py-3 text-lg font-semibold text-white shadow-[0_10px_30px_rgba(12,195,181,0.25)] transition-all hover:scale-[1.01] active:scale-[0.99] ${
            isPending ? 'opacity-70 cursor-not-allowed' : ''
          }`}
        >
          {isPending ? (
            'Processing...'
          ) : (
            <>
              <span className="mr-2 align-middle">$</span> 
              Purchase {numSlots} {numSlots === 1 ? 'Slot' : 'Slots'} for ${numSlots * 15} USDT
            </>
          )}
        </button>
      </div>
    </div>
  );
};

export default BuySlots;
