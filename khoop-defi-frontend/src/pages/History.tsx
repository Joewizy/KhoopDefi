import React from 'react';
import {
  FaHistory,
  FaInfinity,
  FaShoppingCart,
  FaUsers,
} from 'react-icons/fa';
import { FiExternalLink } from 'react-icons/fi';

const transactions = [
  {
    id: 1,
    type: 'Cycle Completion',
    icon: FaInfinity,
    iconBg: 'bg-green-500/20',
    iconColor: 'text-green-400',
    timestamp: '2 hours ago',
    details: 'Slot #1247 completed',
    amount: 20,
  },
  {
    id: 2,
    type: 'Slot Purchase',
    icon: FaShoppingCart,
    iconBg: 'bg-orange-500/20',
    iconColor: 'text-orange-400',
    timestamp: '1 day ago',
    details: '3 slots purchased',
    amount: -45,
  },
  {
    id: 3,
    type: 'Referral Commission',
    icon: FaUsers,
    iconBg: 'bg-purple-500/20',
    iconColor: 'text-purple-400',
    timestamp: '2 days ago',
    details: 'From user Ox9876...4321',
    amount: 3,
  },
  {
    id: 4,
    type: 'Withdrawal',
    icon: FaUsers, // Using FaUsers as per image, FaArrowRight could be an alternative
    iconBg: 'bg-blue-500/20',
    iconColor: 'text-blue-400',
    timestamp: '3 days ago',
    details: 'Withdrawn to wallet',
    amount: -50,
  },
];

const History: React.FC = () => {
  return (
    <div className="rounded-2xl border border-white/15 bg-white/5 p-4 text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.18)] backdrop-blur-md md:p-6">
      <h2 className="mb-4 flex items-center text-xl font-bold text-teal-300 md:mb-6 md:text-2xl">
        <FaHistory className="mr-3" />
        Transaction History
      </h2>
      <div className="space-y-2">
        {transactions.map((tx, index) => (
          <div
            key={tx.id}
            className={`flex flex-col gap-3 py-4 sm:flex-row sm:items-center sm:justify-between ${
              index < transactions.length - 1 ? 'border-b border-[#0CC3B5]/30' : ''
            }`}
          >
            <div className="flex min-w-0 items-start gap-3 sm:items-center sm:gap-4">
              <div className={`flex h-9 w-9 flex-none items-center justify-center rounded-full ${tx.iconBg} md:h-10 md:w-10`}>
                <tx.icon className={`text-base ${tx.iconColor} md:text-lg`} />
              </div>
              <div className="min-w-0">
                <div className="flex flex-wrap items-center gap-2 md:gap-3">
                  <h3 className="truncate text-base font-bold md:text-lg">{tx.type}</h3>
                  <span className="rounded-full bg-[#0CC3B5]/20 px-2 py-0.5 text-[10px] font-semibold text-[#0CC3B5] md:text-xs">
                    Completed
                  </span>
                </div>
                <p className="whitespace-normal break-words text-xs text-gray-400 md:text-sm">
                  {tx.timestamp} · {tx.details}
                </p>
              </div>
            </div>
            <div className="flex shrink-0 items-center justify-between gap-4 sm:gap-6">
              <div className="text-right">
                <p
                  className={`text-base font-bold md:text-lg ${
                    tx.amount > 0
                      ? 'text-green-400'
                      : tx.type === 'Withdrawal'
                      ? 'text-amber-400'
                      : 'text-red-400'
                  }`}
                >
                  {tx.amount > 0 ? `+${tx.amount}` : `-${Math.abs(tx.amount)}`}
                </p>
                <p className="text-xs text-gray-500 md:text-sm">USDT</p>
              </div>
              <FiExternalLink className="cursor-pointer text-lg text-gray-500 hover:text-white md:text-xl" />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default History;
