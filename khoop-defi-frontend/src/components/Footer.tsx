import React from 'react';

const Footer: React.FC = () => {
  return (
    <footer className="p-6 flex justify-center items-center">
      <div className="bg-[#1a1a3d] border border-[#ff00ff]/40 rounded-[15px] p-8 max-w-8xl w-full shadow-2xl">
        <div className="flex items-center mb-5">
          <div className="w-6 h-6 bg-[#00f5a0] rounded-full mr-4 flex items-center justify-center">
            <div className="w-3 h-3 bg-white rounded-full"></div>
          </div>
          <h3 className="text-white text-xl m-0">Decentralized & Secure</h3>
        </div>
        <ul className="list-none p-0 m-0 text-[#dcdcdc]">
          <li className="mb-4 flex items-start">
            <span className="mr-4 text-xl">•</span>
            <span>All transactions processed via immutable smart contracts</span>
          </li>
          <li className="mb-4 flex items-start">
            <span className="mr-4 text-xl">•</span>
            <span>No admin access to user funds - 100% decentralized</span>
          </li>
          <li className="mb-4 flex items-start">
            <span className="mr-4 text-xl">•</span>
            <span>Transparent buyback pool for system stability</span>
          </li>
          <li className="flex items-start">
            <span className="mr-4 text-xl">•</span>
            <span>Multi-layered anti-fraud protection</span>
          </li>
        </ul>
      </div>
    </footer>
  );
};

export default Footer;
