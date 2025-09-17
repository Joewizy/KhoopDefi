import { FiSettings } from 'react-icons/fi';
import { FaWallet } from 'react-icons/fa';
import { ConnectButton } from '@rainbow-me/rainbowkit';

const Header = () => {
  return (
    <header className="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-5 sm:gap-0 p-4 bg-[#3D3B63]/30 backdrop-blur-sm rounded-2xl shadow-2xl text-center sm:text-left">
      <div className="flex items-center justify-center sm:justify-start w-full">
        <div>
          <img src="/khoop-logo.svg" alt="Khoop Logo" className="h-9 w-36 sm:h-8 sm:w-32 mx-auto sm:mx-0" />
          <p className="pt-3 sm:pt-2 text-base sm:text-xs text-[#CFE7F1]/90 max-w-[28rem]">
            Decentralized slot community platform with automated payouts
          </p>
        </div>
      </div>

      <div className="flex items-center w-full sm:w-auto">
        {/* Settings button hidden on mobile to match card design */}
        <button className="hidden sm:inline-flex p-2.5 rounded-lg bg-black/10 hover:bg-black/50 border border-[#A09EC0]/20 shadow-inner cursor-pointer mr-4">
          <FiSettings className="text-[#7A7A7A] h-5 w-5" />
        </button>

        {/* RainbowKit ConnectButton with custom rendering to keep original styles */}
        <ConnectButton.Custom>
          {({ account, openAccountModal, openConnectModal, mounted }) => {
            const connected = mounted && account;

            if (!connected) {
              return (
                <button
                  onClick={openConnectModal}
                  className="flex w-full sm:w-64 items-center justify-center space-x-3 bg-gradient-to-r from-[#2D3BFE] to-[#11D7C8] sm:from-[#F863CD] sm:to-[#FE72E9] hover:opacity-95 text-white font-semibold py-4 sm:py-2 px-6 rounded-xl sm:rounded-lg shadow-[0_12px_24px_rgba(17,215,200,0.25)] sm:shadow-[0_0_15px_rgba(230,57,155,0.4)] cursor-pointer"
                >
                  <FaWallet className="text-white text-lg sm:text-base" />
                  <span className="text-lg sm:text-sm">Connect Wallet</span>
                </button>
              );
            }

            const displayName = account.displayName || account.address || '';
            return (
              <button
                onClick={openAccountModal}
                className="flex w-full sm:w-64 items-center justify-center space-x-3 bg-gradient-to-r from-[#2D3BFE] to-[#11D7C8] sm:from-[#F863CD] sm:to-[#FE72E9] hover:opacity-95 text-white font-semibold py-4 sm:py-2 px-6 rounded-xl sm:rounded-lg shadow-[0_12px_24px_rgba(17,215,200,0.25)] sm:shadow-[0_0_15px_rgba(230,57,155,0.4)] cursor-pointer"
              >
                <FaWallet className="text-white text-lg sm:text-base" />
                <span className="text-lg sm:text-sm">{displayName}</span>
              </button>
            );
          }}
        </ConnectButton.Custom>
      </div>
    </header>
  );
};

export default Header;