import { useState } from 'react';
import CopyButton from '../CopyButton';
import { INSTALL_CMD } from '../../lib/site';

const CLONE_CMD =
  'git clone https://github.com/luongtrz/rotate-agy.git ~/tools/agy-acct && bash ~/tools/agy-acct/install.sh';

export default function InstallBox() {
  const [activeTab, setActiveTab] = useState<'curl' | 'clone'>('curl');

  const currentCmd = activeTab === 'curl' ? INSTALL_CMD : CLONE_CMD;

  return (
    <div className="relative mx-auto w-full max-w-2xl text-left">
      {/* Install Tabs */}
      <div className="mb-2 flex items-center gap-1.5" role="tablist" aria-label="Installation method">
        <button
          type="button"
          role="tab"
          id="tab-curl"
          aria-selected={activeTab === 'curl'}
          aria-controls="panel-install"
          onClick={() => setActiveTab('curl')}
          className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald ${
            activeTab === 'curl'
              ? 'border border-white/10 bg-white/10 text-ink shadow-sm'
              : 'text-dim hover:text-ink'
          }`}
        >
          One-Line Install (Recommended)
        </button>
        <button
          type="button"
          role="tab"
          id="tab-clone"
          aria-selected={activeTab === 'clone'}
          aria-controls="panel-install"
          onClick={() => setActiveTab('clone')}
          className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald ${
            activeTab === 'clone'
              ? 'border border-white/10 bg-white/10 text-ink shadow-sm'
              : 'text-dim hover:text-ink'
          }`}
        >
          Manual Git Clone
        </button>
      </div>

      {/* Terminal Window with Ambient Glow */}
      <div className="group relative">
        <div
          className="pointer-events-none absolute -inset-1 rounded-2xl bg-gradient-to-r from-emerald/15 via-cyan/10 to-transparent blur-xl opacity-70 transition-opacity duration-300 group-hover:opacity-100"
          aria-hidden="true"
        />

        <div
          id="panel-install"
          role="tabpanel"
          aria-labelledby={activeTab === 'curl' ? 'tab-curl' : 'tab-clone'}
          className="relative overflow-hidden rounded-xl border border-white/10 bg-terminal shadow-2xl shadow-black/80"
        >
          {/* Terminal Title Bar */}
          <div className="flex items-center gap-2 border-b border-white/5 bg-terminal-header px-4 py-2.5">
            <span className="h-2.5 w-2.5 rounded-full bg-danger" aria-hidden="true" />
            <span className="h-2.5 w-2.5 rounded-full bg-amber" aria-hidden="true" />
            <span className="h-2.5 w-2.5 rounded-full bg-emerald" aria-hidden="true" />
            <span className="ml-2 font-mono text-[11px] text-dim">bash — install.sh</span>
          </div>

          {/* Terminal Command Line with Defect (b) Fix: horizontal scroll container */}
          <div className="flex items-center justify-between gap-3 p-3.5 sm:p-4">
            <div className="flex min-w-0 flex-1 items-center gap-2 overflow-x-auto py-1">
              <span className="font-mono font-bold text-emerald select-none">$</span>
              <code className="font-mono text-xs sm:text-sm text-ink whitespace-nowrap">
                {currentCmd}
              </code>
              <span className="cmd-cursor" aria-hidden="true" />
            </div>

            <div className="shrink-0 pl-1">
              <CopyButton text={currentCmd} />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
