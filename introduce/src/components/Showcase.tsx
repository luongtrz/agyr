import { useState } from 'react';
import SectionHeading from './SectionHeading';
import Reveal from './Reveal';
import { useInView } from '../hooks/useInView';
import QuotaDashboard from './showcase/QuotaDashboard';
import FailoverDemo from './showcase/FailoverDemo';
import type { ShowcaseTab } from './showcase/types';
import './showcase/showcase.css';

export default function Showcase() {
  const [activeTab, setActiveTab] = useState<ShowcaseTab>('list');
  const [sectionRef, inView] = useInView<HTMLElement>(0.15);

  return (
    <section
      id="demo"
      ref={sectionRef}
      className="relative overflow-hidden py-20 sm:py-28"
    >
      <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
        <Reveal>
          <SectionHeading
            eyebrow="Interactive Terminal"
            title="Built for Serious Antigravity Power Users"
            subtitle="Switch between the live multi-account quota monitor and autonomous 429 auto-failover engine."
          />
        </Reveal>

        {/* Showcase Navigation Tabs */}
        <div
          role="tablist"
          aria-label="Interactive Terminal Demos"
          className="mb-8 flex flex-wrap justify-center gap-3"
        >
          {/* Tab 1: Quota Dashboard */}
          <button
            type="button"
            role="tab"
            id="tab-showcase-list"
            aria-selected={activeTab === 'list'}
            aria-controls="panel-showcase-list"
            onClick={() => setActiveTab('list')}
            className={`inline-flex items-center gap-2.5 rounded-lg border px-4 py-2.5 text-xs font-semibold transition-all duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald sm:text-sm ${
              activeTab === 'list'
                ? 'border-emerald/40 bg-emerald/10 text-white shadow-lg shadow-emerald/5'
                : 'border-white/10 bg-white/[0.04] text-muted hover:border-white/20 hover:bg-white/[0.08] hover:text-white'
            }`}
          >
            <svg
              className="h-4 w-4 shrink-0"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden="true"
            >
              <rect x="3" y="3" width="18" height="18" rx="2" />
              <line x1="3" y1="9" x2="21" y2="9" />
              <line x1="9" y1="21" x2="9" y2="9" />
            </svg>
            <span>
              1. Real-time Quota Dashboard (
              <code className="rounded bg-black/40 px-1 py-0.5 font-mono text-[11px] text-emerald">
                agyr list
              </code>
              )
            </span>
          </button>

          {/* Tab 2: Autonomous 429 Failover */}
          <button
            type="button"
            role="tab"
            id="tab-showcase-rotate"
            aria-selected={activeTab === 'rotate'}
            aria-controls="panel-showcase-rotate"
            onClick={() => setActiveTab('rotate')}
            className={`inline-flex items-center gap-2.5 rounded-lg border px-4 py-2.5 text-xs font-semibold transition-all duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan sm:text-sm ${
              activeTab === 'rotate'
                ? 'border-cyan/40 bg-cyan/10 text-white shadow-lg shadow-cyan/5'
                : 'border-white/10 bg-white/[0.04] text-muted hover:border-white/20 hover:bg-white/[0.08] hover:text-white'
            }`}
          >
            <svg
              className="h-4 w-4 shrink-0"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden="true"
            >
              <polyline points="23 4 23 10 17 10" />
              <polyline points="1 20 1 14 7 14" />
              <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" />
            </svg>
            <span>
              2. Autonomous 429 Failover (
              <code className="rounded bg-black/40 px-1 py-0.5 font-mono text-[11px] text-cyan">
                agy-run
              </code>
              )
            </span>
          </button>
        </div>

        {/* Tab Panels */}
        <div className="relative">
          <div
            role="tabpanel"
            id="panel-showcase-list"
            aria-labelledby="tab-showcase-list"
            className={activeTab === 'list' ? 'block' : 'hidden'}
          >
            <QuotaDashboard isActive={inView && activeTab === 'list'} />
          </div>

          <div
            role="tabpanel"
            id="panel-showcase-rotate"
            aria-labelledby="tab-showcase-rotate"
            className={activeTab === 'rotate' ? 'block' : 'hidden'}
          >
            <FailoverDemo isActive={inView && activeTab === 'rotate'} />
          </div>
        </div>

        {/* Caption */}
        <Reveal delay={200}>
          <div className="mx-auto mt-6 max-w-3xl text-center text-xs leading-relaxed text-dim sm:text-sm">
            <p>
              <strong className="font-semibold text-slate-200">Zero Context Loss:</strong>{' '}
              When a 429 occurs,{' '}
              <code className="rounded bg-white/10 px-1.5 py-0.5 font-mono text-xs text-cyan">
                agy-run
              </code>{' '}
              extracts the reset countdown, switches slots, and passes{' '}
              <code className="rounded bg-white/10 px-1.5 py-0.5 font-mono text-xs text-cyan">
                --conversation &lt;id&gt;
              </code>{' '}
              so the replacement account continues immediately without reprocessing earlier tokens.
            </p>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
