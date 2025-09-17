import { useState } from 'react';
import TopBar from './components/TopBar';
import Footer from './components/Footer';
import PageNav from './components/PageNav';
import BuySlots from './pages/BuySlots';
import Dashboard from './pages/Dashboard';
import Earnings from './pages/Earnings';
import Referrals from './pages/Referrals';
import History from './pages/History';

const App = () => {
  const [activePage, setActivePage] = useState('Buy Slots');

  const renderPage = () => {
    switch (activePage) {
      case 'Buy Slots':
        return <BuySlots />;
      case 'Dashboard':
        return <Dashboard />;
      case 'Earnings':
        return <Earnings />;
      case 'Referrals':
        return <Referrals />;
      case 'History':
        return <History />;
      default:
        return <BuySlots />;
    }
  };

  return (
    <div className="relative min-h-screen bg-gradient-to-b from-[#6247CD] to-[#030029] font-['Poppins'] text-white">
      <div
        aria-hidden
        className="pointer-events-none fixed inset-0 z-0 bg-[url('/bgHand.png')] bg-bottom bg-no-repeat bg-contain bg-fixed"
      />
      <div className="relative z-10">
        <TopBar />
        <main className="max-w-8xl mx-auto px-4 md:px-6">
        <section className="rounded-3xl border border-white/15 bg-gradient-to-b from-[#6B63D8]/15 to-[#1B1840]/15 bg-clip-padding backdrop-blur-xl shadow-[inset_0_1px_0_rgba(255,255,255,0.18),0_10px_30px_rgba(0,0,0,0.35)] p-2 md:p-4">
          <PageNav activePage={activePage} setActivePage={setActivePage} />
          <div className="px-2 pb-3 md:px-4 md:pb-6">
            {renderPage()}
          </div>
        </section>
        </main>
        <Footer />
      </div>
    </div>
  );
};

export default App;
