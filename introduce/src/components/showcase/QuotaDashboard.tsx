import { useState, useEffect } from 'react';
import TerminalChrome from './TerminalChrome';
import {
  ACCOUNTS_DATA,
  getQuotaLevel,
  generateDashboardText,
} from './showcaseData';
import type { DashboardViewMode, QuotaEntry, AccountStatus } from './types';
import { useTypewriter } from '../../hooks/useTypewriter';

function QuotaCell({ entry }: { entry: QuotaEntry }) {
  if (entry.percentage === null) {
    return <span className="text-dim">-</span>;
  }

  const level = getQuotaLevel(entry.percentage);
  const colorClass =
    level === 'green'
      ? 'text-emerald'
      : level === 'yellow'
        ? 'text-amber'
        : 'text-danger';

  const pctStr = `${entry.percentage}%`.padStart(4, ' ');

  return (
    <div className="inline-flex items-baseline gap-2">
      <span
        className={`quota-pct-badge font-bold ${colorClass}`}
        style={{ '--q-w': `${entry.percentage}%` } as React.CSSProperties}
      >
        <span className="whitespace-pre">{pctStr}</span>
      </span>
      {entry.resetTime && (
        <span className="text-[11px] whitespace-nowrap text-dim">
          {entry.resetTime}
        </span>
      )}
    </div>
  );
}

function StatusBadge({ status }: { status: AccountStatus }) {
  const isReady = status.type === 'ready';
  const colorClass = isReady ? 'text-emerald' : 'text-danger';

  return (
    <span className={`inline-flex items-center gap-1.5 font-semibold ${colorClass}`}>
      <span
        className={`h-1.5 w-1.5 rounded-full ${
          isReady
            ? 'bg-emerald shadow-[0_0_6px_var(--color-emerald)]'
            : 'bg-danger shadow-[0_0_6px_var(--color-danger)]'
        }`}
      />
      <span className="whitespace-nowrap">{status.label}</span>
    </span>
  );
}

export default function QuotaDashboard({ isActive = true }: { isActive?: boolean }) {
  const [viewMode, setViewMode] = useState<DashboardViewMode>('standard');
  const targetCmd = viewMode === 'claude' ? 'agyr list --claude' : 'agyr list';

  const { displayedText, isComplete, isTyping } = useTypewriter(targetCmd, {
    start: isActive,
    speed: 20,
  });

  const [revealedCount, setRevealedCount] = useState<number>(0);

  useEffect(() => {
    const isReduced =
      typeof window !== 'undefined' &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    if (isReduced) {
      setRevealedCount(ACCOUNTS_DATA.length);
      return;
    }

    if (isComplete) {
      let current = 0;
      const interval = setInterval(() => {
        current += 1;
        setRevealedCount(current);
        if (current >= ACCOUNTS_DATA.length) {
          clearInterval(interval);
        }
      }, 40);

      return () => clearInterval(interval);
    } else {
      setRevealedCount(0);
    }
  }, [isComplete, viewMode]);

  const viewTools = (
    <div className="view-toggle-group flex items-center rounded-md border border-white/10 bg-black/40 p-0.5">
      <button
        type="button"
        onClick={() => setViewMode('standard')}
        className={`rounded px-2.5 py-1 text-xs font-semibold transition ${
          viewMode === 'standard'
            ? 'bg-white/10 text-white shadow-sm'
            : 'text-dim hover:text-white'
        }`}
        aria-pressed={viewMode === 'standard'}
      >
        Standard View (<code className="text-[11px]">agyr list</code>)
      </button>
      <button
        type="button"
        onClick={() => setViewMode('claude')}
        className={`rounded px-2.5 py-1 text-xs font-semibold transition ${
          viewMode === 'claude'
            ? 'bg-white/10 text-white shadow-sm'
            : 'text-dim hover:text-white'
        }`}
        aria-pressed={viewMode === 'claude'}
      >
        Extended View (<code className="text-[11px]">agyr list --claude</code>)
      </button>
    </div>
  );

  return (
    <TerminalChrome
      title="agyr list — Google Account Quota Monitor"
      shell="bash"
      statusPillText="LIVE · 5 ACCOUNTS"
      statusPillVariant="emerald"
      haloColor="rgba(34, 197, 94, 0.18)"
      tools={viewTools}
      copyText={generateDashboardText(viewMode)}
    >
      {/* Command Prompt */}
      <div className="mb-3 flex flex-wrap items-center font-mono text-xs sm:text-sm">
        <span className="font-semibold text-emerald">user@devbox</span>
        <span className="text-dim">:</span>
        <span className="font-semibold text-cyan">~/projects</span>
        <span className="text-dim">$ </span>
        <span className="ml-1.5 font-semibold text-ink">{displayedText}</span>
        {isTyping && (
          <span className="ml-0.5 inline-block font-bold text-emerald animate-pulse" aria-hidden="true">
            ▋
          </span>
        )}
      </div>

      {/* Semantic Table with responsive scroll and fixed column alignment */}
      <div className="my-2 overflow-x-auto rounded border border-slate-800/80 bg-[#070b13] shadow-inner">
        <table
          className={`w-full ${
            viewMode === 'claude' ? 'min-w-[880px]' : 'min-w-[720px]'
          } border-collapse font-mono text-xs leading-relaxed text-left sm:text-[13px]`}
        >
          <thead>
            <tr className="border-b border-slate-700/80 bg-white/[0.03] text-slate-300">
              <th scope="col" className="w-[18%] border-r border-slate-800/80 px-3.5 py-2.5 font-bold tracking-wider">
                ACCOUNT
              </th>
              <th scope="col" className="w-[24%] border-r border-slate-800/80 px-3.5 py-2.5 font-bold tracking-wider">
                GEMINI 5H
              </th>
              <th scope="col" className="w-[24%] border-r border-slate-800/80 px-3.5 py-2.5 font-bold tracking-wider">
                GEMINI WEEK
              </th>
              {viewMode === 'standard' ? (
                <th scope="col" className="w-[20%] border-r border-slate-800/80 px-3.5 py-2.5 font-bold tracking-wider">
                  ARGON WEEK
                </th>
              ) : (
                <>
                  <th scope="col" className="w-[16%] border-r border-slate-800/80 px-3.5 py-2.5 font-bold tracking-wider">
                    CLAUDE 5H
                  </th>
                  <th scope="col" className="w-[16%] border-r border-slate-800/80 px-3.5 py-2.5 font-bold tracking-wider">
                    CLAUDE WEEK
                  </th>
                </>
              )}
              <th scope="col" className="w-[14%] px-3.5 py-2.5 font-bold tracking-wider">
                STATUS
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-800/60">
            {ACCOUNTS_DATA.map((row, index) => {
              const isRevealed = index < revealedCount;
              return (
                <tr
                  key={row.id}
                  className={`transition-all duration-300 ${
                    isRevealed ? 'translate-y-0 opacity-100' : 'translate-y-1 opacity-0'
                  } ${
                    row.isActive
                      ? 'active-account-line border-l-2 border-cyan bg-cyan/10'
                      : index % 2 === 1
                        ? 'bg-white/[0.02]'
                        : 'bg-transparent'
                  } hover:bg-white/[0.04]`}
                >
                  {/* Account Name & Marker */}
                  <td className="whitespace-nowrap border-r border-slate-800/60 px-3.5 py-2">
                    {row.isActive ? (
                      <span className="active-account-marker mr-1.5 inline-block font-extrabold text-cyan">
                        *
                      </span>
                    ) : (
                      <span className="mr-1.5 inline-block w-2.5" />
                    )}
                    <span className={row.isActive ? 'font-bold text-ink' : 'text-slate-300'}>
                      {row.name}
                    </span>
                  </td>

                  {/* Gemini 5H */}
                  <td className="whitespace-nowrap border-r border-slate-800/60 px-3.5 py-2">
                    <QuotaCell entry={row.gemini5h} />
                  </td>

                  {/* Gemini Week */}
                  <td className="whitespace-nowrap border-r border-slate-800/60 px-3.5 py-2">
                    <QuotaCell entry={row.geminiWeek} />
                  </td>

                  {/* Argon Week or Claude Quotas */}
                  {viewMode === 'standard' ? (
                    <td className="whitespace-nowrap border-r border-slate-800/60 px-3.5 py-2">
                      <QuotaCell entry={row.argonWeek} />
                    </td>
                  ) : (
                    <>
                      <td className="whitespace-nowrap border-r border-slate-800/60 px-3.5 py-2">
                        <QuotaCell entry={row.claude5h} />
                      </td>
                      <td className="whitespace-nowrap border-r border-slate-800/60 px-3.5 py-2">
                        <QuotaCell entry={row.claudeWeek} />
                      </td>
                    </>
                  )}

                  {/* Status */}
                  <td className="whitespace-nowrap px-3.5 py-2">
                    <StatusBadge status={row.status} />
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <div className="mt-2.5 text-xs text-dim">
        Measured in parallel across 5 accounts in 12s · (* = selected account)
      </div>
    </TerminalChrome>
  );
}
