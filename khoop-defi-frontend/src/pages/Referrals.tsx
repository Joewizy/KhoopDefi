
import { useState } from 'react';
import { FiGift, FiCopy, FiArrowUpRight, FiCheck } from 'react-icons/fi';
import { IoTrendingUp } from 'react-icons/io5';
import { BsPeople, BsExclamationCircle } from 'react-icons/bs';
import { IoIosPeople } from 'react-icons/io';
import { useUserDetails } from '../constants/function';
import { useAccount } from 'wagmi';
import { formatNumber } from '../constants/utils';

const recentReferrals = [
  { user: '0x1234...abcd', date: '2024-07-21', commission: '$1.00' },
  { user: '0x5678...efgh', date: '2024-07-20', commission: '$1.00' },
  { user: '0x9abc...ijkl', date: '2024-07-19', commission: '$1.00' },
  { user: '0xdef0...mnop', date: '2024-07-18', commission: '$1.00' },
];

const Referrals = () => {
  const { address } = useAccount();
 // const { stats, isLoading: globalLoading, isError: globalError } = useGlobalStats();
  const { user } = useUserDetails(address as `0x${string}`);
  const [copied, setCopied] = useState(false);
  const handleCopy = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 5000);
    } catch (_) {
      // no-op
    }
  };
  const referralUrl = address

  const totalReferees = user?.totalReferrals ?? 0n;
  const totalCommissions = totalReferees; // $1 per referee
  const activeReferrals = totalReferees; // if you want same logic for now
  const refferedBy = user?.refferer

  return (
    <div className="p-8 text-white">
      {/* Stats Cards with diagonal pink gradient borders */}
      <div className="mb-8 grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-4">
        {[{
          title: 'Pending', value: '$12', icon: <BsExclamationCircle size={22} className="text-red-400" />
        }, {
          title: 'Total Commissions', value: formatNumber(totalCommissions), icon: <FiGift size={22} />
        }, {
          title: 'Active Referrals', value: formatNumber(activeReferrals), icon: <IoTrendingUp size={22} />
        }, {
          title: 'Total Referrals', value: formatNumber(totalReferees), icon: <IoIosPeople size={22} />
        }].map((card, idx) => (
          <div key={idx} className="rounded-2xl bg-gradient-to-br from-transparent to-[#FFD0F2] p-[1px]">
            <div className="rounded-2xl bg-[#2C2A52]/90 p-4 backdrop-blur-sm">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-blue-200/80">{card.title}</p>
                  <p className="mt-2 text-xl font-semibold">{card.value}</p>
                </div>
                <div className="text-blue-200">{card.icon}</div>
              </div>
            </div>
          </div>
        ))}
      </div>

      <div className="space-y-8">
        {/* Your Referral Link */}
        <div className="bg-[#2C2A52]/60 border border-[#A09EC0]/20 p-6 rounded-2xl backdrop-blur-sm">
          <h2 className="flex items-center text-xl font-semibold mb-4 text-[#F0F0FF]">
            <BsPeople className="mr-3" size={24}/> Your Referral Link
          </h2>
          <div className="mb-4 text-sm text-blue-300">
            You were referred by:{' '}
            <span className="inline-block rounded-full bg-gradient-to-br from-[#FE72EC00] to-[#FFD0F2] p-[1px] align-middle">
              <span className="rounded-full bg-[#4E47B5]/50 px-3 py-1 text-[#A098F5]">{refferedBy}</span>
            </span>
          </div>
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex-grow rounded-lg bg-[#211F46] p-3 text-gray-300 overflow-x-auto whitespace-nowrap">{referralUrl}</div>
            <div className="flex shrink-0 items-center gap-3">
              <button
                onClick={() => handleCopy(referralUrl as `0x${string}`)}
                className="rounded-md border border-white/10 bg-white/5 p-2 text-gray-300 hover:bg-white/10"
                aria-label="Copy link"
              >
                {copied ? <FiCheck size={20} className="text-emerald-400" /> : <FiCopy size={20} />}
              </button>
              <button className="rounded-md border border-white/10 bg-white/5 p-2 text-gray-300 hover:bg-white/10" aria-label="Open link">
                <FiArrowUpRight size={20} />
              </button>
            </div>
          </div>
        </div>

        {/* Custom Short Code */}
        <div className="bg-[#2C2A52]/60 border border-[#A09EC0]/20 p-6 rounded-2xl backdrop-blur-sm">
          <h3 className="text-lg font-semibold mb-2 text-[#F0F0FF]">Custom Short Code (Optional)</h3>
          <input
            type="text"
            placeholder="Enter custom code (e.g., mycode123)"
            className="w-full bg-[#211F46] p-3 rounded-lg border border-transparent focus:ring-2 focus:ring-purple-500 focus:border-purple-500 outline-none"
          />
          <p className="text-sm text-gray-400 mt-2">
            Create a custom short link for easier sharing
          </p>
        </div>

        {/* Referral Benefits */}
        <div className="bg-[#2C2A52]/60 border border-[#A09EC0]/20 p-6 rounded-2xl backdrop-blur-sm">
          <h3 className="text-lg font-semibold mb-4 text-[#F0F0FF]">Referral Benefits</h3>
          <ul className="space-y-2 text-gray-300 list-disc list-inside">
            <li>Earn $1 commission for every slot your referrals buy</li>
            <li>Permanent connection - lifetime earnings</li>
            <li>Instant payouts via smart contract</li>
            <li>No limits on referral count</li>
          </ul>
        </div>

        {/* Recent Referrals - card list */}
        <div className="rounded-2xl border border-white/15 bg-white/5 p-4 backdrop-blur-md">
          <h3 className="mb-4 text-lg font-semibold text-[#F0F0FF]">Recent Referrals</h3>
          <div className="space-y-4">
            {recentReferrals.map((referral, index) => (
              <div
                key={index}
                className="rounded-2xl border border-white/10 bg-black/20 p-4 shadow-sm"
              >
                <div className="flex items-center justify-between gap-4">
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-4">
                      <span className="inline-block rounded-full border border-[#FFD0F2] bg-white/5 px-4 py-2 text-sm text-gray-200">
                        {referral.user}
                      </span>
                      <span className="text-gray-300">Joined {referral.date}</span>
                    </div>
                    <p className="mt-2 text-sm text-indigo-200">5 slots contributed</p>
                  </div>
                  <div className="text-right">
                    <p className="font-semibold text-emerald-400">+$5</p>
                    <p className="text-sm text-gray-300">Commission</p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};

export default Referrals;
