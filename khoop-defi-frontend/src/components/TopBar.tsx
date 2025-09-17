import Header from './Header';
import StatCard from './StatCard';
import { FiClock, FiTrendingUp, FiUsers, FiDollarSign, FiShield } from 'react-icons/fi';

const TopBar = () => {
  return (
    <div className="p-6 font-['Poppins']">
      <Header />
      <main className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mt-6">
        
        {/* My Slots */}
        <StatCard title="My Slots" value="15">
          <div className="flex items-center space-x-2 mb-4">
            <span className="px-3 py-1 text-xs font-medium text-white border border-[#5CC6FF] rounded-full">8 Active</span>
            <span className="px-3 py-1 text-xs font-medium text-white bg-[#5CC6FF] rounded-full">7 Completed</span>
          </div>
          <div>
            <div className="flex justify-between text-sm text-[#A09EC0] mb-1">
              <span>Cycle Progress</span>
              <span>46.7 %</span>
            </div>
            <div className="w-full bg-black/30 rounded-full h-2">
              <div className="bg-gradient-to-r from-[#00BFFF]/80 to-[#00BFFF] h-2 rounded-full" style={{ width: '46.7%' }}></div>
            </div>
          </div>
        </StatCard>

        {/* Total Earnings */}
        <StatCard title="Total Earnings" value="$140" icon={<FiDollarSign />}>
        <div className="flex justify-between">
          <div className="text-sm text-[#A09EC0]">Referral Commissions:</div>
          <div className="text-[#F0F0FF] font-semibold">$25</div>
        </div>
        <div className="flex justify-between">
          <div className="text-sm text-[#A09EC0]">Pending Payouts:</div>
          <div className="text-[#FF4141] font-semibold">$160</div>
          </div>
        </StatCard>

        {/* Next Payout */}
        <StatCard title="Next Payout" value="2h 34m" icon={<FiClock />}>
          <p className="text-sm text-[#A09EC0]">Estimated time for next cycle completion</p>
        </StatCard>

        {/* Buyback Pool */}
        <StatCard title="Buyback Pool" value="$285,000" icon={<FiShield />}>
          <p className="text-sm text-[#A09EC0]">Available for automatic payouts</p>
        </StatCard>

        {/* System Stats */}
        <StatCard title="System Stats" value="1,247" icon={<FiUsers />}>
          <p className="text-sm text-[#A09EC0]">Total participants in the system</p>
        </StatCard>

        {/* Purchase Limits */}
        <StatCard title="Purchase Limits" value="43" icon={<FiTrendingUp />}>
          <p className="text-sm text-[#A09EC0]">Slots remaining today (max 50)</p>
          <p className="text-sm text-[#A09EC0]">Next purchase: 8m 22s</p>
        </StatCard>

      </main>
    </div>
  );
};

export default TopBar;