import Navbar from './components/Navbar';
import Hero from './components/Hero';
import Showcase from './components/Showcase';
import Features from './components/Features';
import Comparison from './components/Comparison';
import QuickStart from './components/QuickStart';
import Orchestration from './components/Orchestration';
import CommandReference from './components/CommandReference';
import Platforms from './components/Platforms';
import Faq from './components/Faq';
import CtaBanner from './components/CtaBanner';
import SupportStrip from './components/SupportStrip';
import Footer from './components/Footer';
import BackToTop from './components/BackToTop';

export default function App() {
  return (
    <>
      <Navbar />
      <main>
        <Hero />
        <Showcase />
        <Features />
        <Comparison />
        <QuickStart />
        <Orchestration />
        <CommandReference />
        <Platforms />
        <Faq />
        <CtaBanner />
        <SupportStrip />
      </main>
      <Footer />
      <BackToTop />
    </>
  );
}
