
import React from 'react';
import {
  FaShoppingCart,
  FaDollarSign,
  FaUsers,
  FaHistory,
} from 'react-icons/fa';
import { BsGridFill } from 'react-icons/bs';

interface PageNavProps {
  activePage: string;
  setActivePage: (page: string) => void;
}

const navItems = [
  { name: 'Buy Slots', icon: FaShoppingCart },
  { name: 'Earnings', icon: FaDollarSign },
  { name: 'Referrals', icon: FaUsers },
  { name: 'History', icon: FaHistory },
];

const PageNav: React.FC<PageNavProps> = ({ activePage, setActivePage }) => {
  return (
    <nav
      className="my-4 w-full rounded-full border border-white/20 bg-gradient-to-r from-[#6B63D8]/20 to-[#2C2A52]/20 px-2 py-1.5 bg-clip-padding shadow-[inset_0_1px_0_0_rgba(255,255,255,0.18),0_8px_24px_rgba(0,0,0,0.35)] backdrop-blur-xl md:my-6 md:px-3 md:py-2"
    >
      <div className="flex w-full items-center gap-2 overflow-x-auto scroll-px-2 snap-x snap-mandatory md:gap-3">
        {navItems.map((item) => {
          const isActive = activePage === item.name;
          return (
            <button
              key={item.name}
              onClick={() => setActivePage(item.name)}
              className={`group flex flex-none items-center justify-center gap-2 rounded-full border px-3 py-1.5 text-[15px] transition-all duration-300 whitespace-nowrap snap-center md:flex-1 md:gap-3 md:px-4 md:py-2 md:text-[16.5px] ${
                isActive
                  ? 'border-cyan-300/80 text-cyan-200 shadow-[0_0_12px_0_rgba(34,211,238,0.28)]'
                  : 'border-white/20 text-white/70 hover:text-white'
              }`}
              aria-current={isActive ? 'page' : undefined}
            >
              <item.icon
                className={`${isActive ? 'text-cyan-200' : 'text-white/70 group-hover:text-white'} text-[16px] md:text-[18px]`}
              />
              <span className="tracking-wide">{item.name}</span>
            </button>
          );
        })}
        <button
        onClick={() => setActivePage('Dashboard')}
        className={`flex flex-none items-center justify-center gap-2 rounded-full border px-3 py-1.5 text-[15px] transition-all duration-300 whitespace-nowrap snap-center md:flex-1 md:gap-3 md:px-4 md:py-2 md:text-[16.5px] ${
          activePage === 'Dashboard'
            ? 'border-cyan-300/80 text-cyan-200 shadow-[0_0_12px_0_rgba(34,211,238,0.28)]'
            : 'border-white/20 text-white/70 hover:text-white'
        }`}
        aria-current={activePage === 'Dashboard' ? 'page' : undefined}
      >
          <BsGridFill className="text-[16px] md:text-[18px]" />
          <span className="tracking-wide">Dashboard</span>
        </button>
      </div>
    </nav>
  );
};

export default PageNav;
