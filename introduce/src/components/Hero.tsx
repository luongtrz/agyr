import './hero/hero.css';
import ConstellationCanvas from './hero/ConstellationCanvas';
import HeroTicker from './hero/HeroTicker';
import StatChips from './hero/StatChips';
import InstallBox from './hero/InstallBox';
import HeroMetrics from './hero/HeroMetrics';
import { REPO_URL } from '../lib/site';

export default function Hero() {
  return (
    <section id="hero" className="relative overflow-hidden pt-20 pb-16 sm:pt-28 sm:pb-24">
      {/* Background Layer: Aurora Blobs & Perspective Grid */}
      <div className="pointer-events-none absolute inset-0 z-0 overflow-hidden" aria-hidden="true">
        {/* Ambient Aurora Blobs */}
        <div
          className="hero-aurora-1 absolute -top-[120px] left-[15%] h-[550px] w-[550px] rounded-full opacity-35 blur-[90px]"
          style={{
            background:
              'radial-gradient(circle, rgba(34, 197, 94, 0.28) 0%, rgba(34, 197, 94, 0.05) 55%, transparent 75%)',
          }}
        />
        <div
          className="hero-aurora-2 absolute top-[60px] right-[12%] h-[620px] w-[620px] rounded-full opacity-30 blur-[90px]"
          style={{
            background:
              'radial-gradient(circle, rgba(56, 189, 248, 0.22) 0%, rgba(56, 189, 248, 0.04) 55%, transparent 75%)',
          }}
        />
        <div
          className="hero-aurora-3 absolute -bottom-[150px] left-[35%] h-[480px] w-[480px] rounded-full opacity-25 blur-[90px]"
          style={{
            background:
              'radial-gradient(circle, rgba(192, 132, 252, 0.18) 0%, rgba(192, 132, 252, 0.03) 60%, transparent 80%)',
          }}
        />

        {/* 3D Perspective Grid */}
        <div className="hero-grid-perspective" />
      </div>

      {/* Interactive Constellation Canvas of 5 Google Account Nodes */}
      <ConstellationCanvas />

      {/* Floating Stat Chips in Side Gutters (on screens >= 1360px) */}
      <StatChips variant="gutters" />

      {/* Main Hero Content Container */}
      <div className="relative z-10 mx-auto flex max-w-5xl flex-col items-center px-4 text-center sm:px-6 lg:px-8">
        {/* Eyebrow Badge */}
        <div className="mb-4 inline-flex items-center gap-2.5 rounded-full border border-emerald/30 bg-emerald/10 px-3.5 py-1 text-xs font-semibold text-slate-200 shadow-[0_0_20px_rgba(34,197,94,0.12)] backdrop-blur-md transition-all duration-200 hover:-translate-y-0.5 hover:shadow-[0_0_25px_rgba(34,197,94,0.24)]">
          <span className="badge-dot" aria-hidden="true" />
          <span>Open Source · Pure Bash · Linux &amp; Windows</span>
        </div>

        {/* Live Simulation Ticker (Safe Document Flow to Avoid Headline Overlap) */}
        <HeroTicker />

        {/* Main Headline */}
        <h1 className="max-w-4xl text-3xl font-extrabold tracking-tight text-ink sm:text-5xl lg:text-6xl leading-[1.15]">
          Never Hit a <span className="text-gradient-red-orange">429 Quota Wall</span> on{' '}
          <br className="hidden sm:inline" />
          <span className="text-gradient-cyan-emerald">Antigravity CLI</span> Again.
        </h1>

        {/* Subtitle */}
        <p className="mt-6 max-w-2xl text-base text-muted sm:text-lg lg:text-xl leading-relaxed">
          <strong className="text-white">agyr</strong> rotates multiple Google accounts for official{' '}
          <code className="rounded border border-white/10 bg-white/10 px-1.5 py-0.5 font-mono text-xs sm:text-sm text-slate-200">
            agy
          </code>{' '}
          automatically. Pure Bash swapper with <strong>zero proxy servers</strong>,{' '}
          <strong>zero ban risk</strong>, real-time quota inspection, and{' '}
          <strong>seamless conversation resume</strong>.
        </p>

        {/* Quick Install Box */}
        <div className="mt-8 w-full">
          <InstallBox />
        </div>

        {/* Call to Action Buttons */}
        <div className="mt-8 flex flex-wrap items-center justify-center gap-4">
          <a
            href="#quick-start"
            className="btn-shimmer-sweep group inline-flex items-center gap-2 rounded-xl border border-white/20 bg-gradient-to-r from-emerald-500 to-emerald-600 px-6 py-3 text-sm font-bold text-slate-950 shadow-[0_4px_20px_rgba(34,197,94,0.35)] transition-all duration-200 hover:-translate-y-0.5 hover:shadow-[0_8px_30px_rgba(34,197,94,0.55)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald"
          >
            <span>Get Started in 2 Minutes</span>
            <svg
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.5"
              strokeLinecap="round"
              strokeLinejoin="round"
              className="transition-transform duration-200 group-hover:translate-x-1"
              aria-hidden="true"
            >
              <line x1="5" y1="12" x2="19" y2="12" />
              <polyline points="12 5 19 12 12 19" />
            </svg>
          </a>

          <a
            href={REPO_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-6 py-3 text-sm font-semibold text-ink backdrop-blur-md transition-all duration-200 hover:-translate-y-0.5 hover:border-white/25 hover:bg-white/10 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald"
          >
            <svg
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="currentColor"
              aria-hidden="true"
            >
              <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z" />
            </svg>
            <span>View on GitHub</span>
          </a>
        </div>

        {/* Responsive Stat Chips for Medium/Small Viewports (< 1360px) */}
        <StatChips variant="inline" />

        {/* 4 Metric Cards Strip Under Hero */}
        <HeroMetrics />
      </div>
    </section>
  );
}
