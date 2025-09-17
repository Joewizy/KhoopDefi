import React from 'react';
import { FaDollarSign, FaClock } from 'react-icons/fa';
import { FiTrendingUp, FiInfo } from 'react-icons/fi';

// Mock data for cycle progress
const cycleProgress = [
  {
    id: 1,
    slot: '#1245',
    expected: 20,
    progress: 75,
    eta: '3h 15m',
  },
  {
    id: 2,
    slot: '#1245',
    expected: 20,
    progress: 75,
    eta: '3h 15m',
  },
  {
    id: 3,
    slot: '#1245',
    expected: 20,
    progress: 75,
    eta: '3h 15m',
  },
];

const Earnings: React.FC = () => {
  return (
    <div className="space-y-6 text-white">
      {/* Top Stat Cards */}
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 md:gap-6">
        <div className="rounded-2xl border border-white/15 bg-white/5 p-5 shadow-[inset_0_1px_0_rgba(255,255,255,0.18)] backdrop-blur-md">
          <div>
            <p className="text-sm text-blue-200/80">Available Balance</p>
            <div className="mt-1 flex items-center justify-between">
              <p className="text-3xl font-bold text-green-400">$140</p>
              <FaDollarSign className="text-3xl text-gray-400" />
            </div>
            <p className="mt-1 text-xs text-gray-400">Ready to withdraw or reinvest</p>
          </div>
        </div>
        <div className="rounded-2xl border border-white/15 bg-white/5 p-5 shadow-[inset_0_1px_0_rgba(255,255,255,0.18)] backdrop-blur-md">
          <div>
            <p className="text-sm text-blue-200/80">Pending Earnings</p>
            <div className="mt-1 flex items-center justify-between">
              <p className="text-3xl font-bold text-red-400">$160</p>
              <FaClock className="text-3xl text-gray-400" />
            </div>
            <p className="mt-1 text-xs text-gray-400">From active cycles</p>
          </div>
        </div>
      </div>

      {/* Withdraw / Reinvest Pills */}
      <div className="rounded-2xl border border-white/15 bg-white/5 p-2 backdrop-blur-md">
        <div className="grid grid-cols-2 gap-2">
          <button className="rounded-xl bg-white/20 py-2 text-center text-sm text-white hover:bg-white/25">Withdraw</button>
          <button className="rounded-xl bg-transparent py-2 text-center text-sm text-white/70 hover:bg-white/10">Reinvest</button>
        </div>
      </div>

      {/* Withdraw Section */}
      <div className="rounded-2xl border border-white/15 bg-white/5 p-6 shadow-[inset_0_1px_0_rgba(255,255,255,0.18)] backdrop-blur-md">
        <h3 className="mb-4 flex items-center text-xl font-bold"><FiTrendingUp className="mr-3" /> Withdraw Earnings</h3>
        <div className="mb-6 rounded-xl bg-[#4E47B5]/30 p-6">
          <h4 className="mb-3 font-bold">Withdrawal Info</h4>
          <ul className="list-inside list-disc space-y-1 text-sm text-blue-100/90">
            <li>Instant withdrawal to your wallet</li>
            <li>No withdrawal fees</li>
            <li>Minimum withdrawal: $1 USDT</li>
            <li>Processed via smart contract</li>
          </ul>
        </div>
        <div>
          <label className="mb-2 block text-sm">Withdrawal Amount (USDT)</label>
          <div className="flex items-center rounded-lg border border-white/15 bg-[#100E28]/60 pr-2">
            <input type="text" placeholder="0.00" className="w-full bg-transparent p-3 focus:outline-none" />
            <button className="rounded-md bg-white/10 px-4 py-1 text-sm hover:bg-white/15">Max</button>
          </div>
          <p className="mt-1 text-xs text-gray-400">Available: $140 USDT</p>
        </div>
        <button className="mt-6 w-full rounded-full bg-gradient-to-r from-[#2D22D2] to-[#0CC3B5] py-3 text-lg font-semibold text-white">Withdraw $0 USDT</button>
      </div>

      {/* Active Cycle Progress Section */}
      <div className="rounded-2xl border border-white/15 bg-white/5 p-6 shadow-[inset_0_1px_0_rgba(255,255,255,0.18)] backdrop-blur-md">
        <h3 className="mb-4 flex items-center text-xl font-bold"><FiTrendingUp className="mr-3" /> Active Cycle Progress</h3>
        <div className="space-y-6">
          {cycleProgress.map((item) => (
            <div key={item.id} className="pb-6">
              <div className="flex items-center justify-between text-sm">
                <p>
                  <span className="mr-2 rounded-md border border-white/20 bg-white/10 px-2 py-0.5">Slot {item.slot}</span>
                  <span className="text-gray-400">Expected: </span>
                  <span className="font-bold">${item.expected}</span>
                </p>
                <div className="text-right">
                  <p>{item.progress}%</p>
                  <p className="text-xs text-gray-400">ETA: {item.eta}</p>
                </div>
              </div>
              <p className="mt-2 flex items-center text-xs text-yellow-400/90"><FiInfo className="mr-2" />In progress</p>
              <div className="mt-4 h-[2px] w-full rounded bg-[#FFD0F2]" />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default Earnings;
