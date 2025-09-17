import type { ReactNode } from 'react';


interface StatCardProps {
  title: string;
  value: string;
  children?: ReactNode;
  icon?: ReactNode;
}

const StatCard = ({ title, value, children, icon }: StatCardProps) => {
  return (
    <div className="bg-[#3D3B63]/50 border border-[#A09EC0]/20 p-6 rounded-2xl backdrop-blur-sm">
      <div className="flex justify-between items-start mb-4">
        <h3 className="text-[#A09EC0] text-base font-medium">{title}</h3>
        <div className="text-[#A09EC0]">{icon}</div>
      </div>
      <p className="text-[#F0F0FF] text-5xl font-bold mb-4">{value}</p>
      <div>{children}</div>
    </div>
  );
};

export default StatCard;