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

  return (
    <div className="flex flex-col items-start gap-0.5 min-w-0">
      <span
        className={`quota-pct-badge font-bold ${colorClass}`}
        style={{ '--q-w': `${entry.percentage}%` } as React.CSSProperties}
      >
        <span>{entry.percentage}%</span>
      </span>
      {entry.resetTime && (
        <span className="text-[10px] leading-tight text-dim break-words lg:text-[11px]">
          {entry.resetTime}
        </span>
      )}
    </div>
  );
}

function MobileQuotaRow({ label, entry }: { label: string; entry: QuotaEntry }) {
  if (entry.percentage === null) {
    return (
      <div className="flex items-center justify-between gap-2 py-1 text-xs">
        <span className="text-dim shrink-0">{label}</span>
        <span className="text-dim font-bold">-</span>
      </div>
    );
  }

  const level = getQuotaLevel(entry.percentage);
  const colorClass =
    level === 'green'
      ? 'text-emerald'
      : level === 'yellow'
        ? 'text-amber'
        : 'text-danger';

  return (
    <div className="flex flex-wrap items-baseline justify-between gap-x-2 gap-y-0.5 py-1 text-xs">
      <span className="text-dim shrink-0">{label}</span>
      <div className="flex flex-wrap items-baseline justify-end gap-x-2 gap-y-0.5 text-right min-w-0">
        <span
          className={`quota-pct-badge font-bold ${colorClass}`}
          style={{ '--q-w': `${entry.percentage}%` } as React.CSSProperties}
        >
          <span>{entry.percentage}%</span>
        </span>
        {entry.resetTime && (
          <span className="text-[11px] text-dim break-words">
            {entry.resetTime}
          </span>
        )}
      </div>
    </div>
  );
}

function StatusBadge({ status }: { status: AccountStatus }) {
  const isReady = status.type === 'ready';
  const colorClass = isReady ? 'text-emerald' : 'text-danger';

  return (
    <span className={`inline-flex items-center gap-1.5 font-semibold ${colorClass}`}>
      <span
        className={`h-1.5 w-1.5 shrink-0 rounded-full ${
          isReady
            ? 'bg-emerald shadow-[0_0_6px_var(--color-emerald)]'
            : 'bg-danger shadow-[0_0_6px_var(--color-danger)]'
        }`}
      />
      <span className="break-words">{status.label}</span>
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
    <div className="view-toggle-group inline-flex max-w-full flex-wrap items-center gap-1 rounded-md border border-white/10 bg-black/40 p-0.5">
      <button
        type="button"
        onClick={() => setViewMode('standard')}
        className={`max-w-full rounded px-2 sm:px-2.5 py-1 text-xs font-semibold transition break-words text-left sm:text-center ${
          viewMode === 'standard'
            ? 'bg-white/10 text-white shadow-sm'
            : 'text-dim hover:text-white'
        }`}
        aria-pressed={viewMode === 'standard'}
      >
        Standard View (<code className="text-[11px] break-all sm:break-normal">agyr list</code>)
      </button>
      <button
        type="button"
        onClick={() => setViewMode('claude')}
        className={`max-w-full rounded px-2 sm:px-2.5 py-1 text-xs font-semibold transition break-words text-left sm:text-center ${
          viewMode === 'claude'
            ? 'bg-white/10 text-white shadow-sm'
            : 'text-dim hover:text-white'
        }`}
        aria-pressed={viewMode === 'claude'}
      >
        Extended View (<code className="text-[11px] break-all sm:break-normal">agyr list --claude</code>)
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
        <span className="ml-1.5 font-semibold text-ink whitespace-pre-wrap break-words">{displayedText}</span>
        {isTyping && (
          <span className="ml-0.5 inline-block font-bold text-emerald animate-pulse" aria-hidden="true">
            ▋
          </span>
        )}
      </div>

      {/* Mobile Stacked Row-Cards (< 768px) */}
      <div
        className="my-2 space-y-2.5 md:hidden"
        role="region"
        aria-label="Accounts Quota Summary"
      >
        {ACCOUNTS_DATA.map((row, index) => {
          const isRevealed = index < revealedCount;
          return (
            <div
              key={row.id}
              className={`rounded-lg border p-3 font-mono text-xs transition-all duration-300 ${
                isRevealed ? 'translate-y-0 opacity-100' : 'translate-y-1 opacity-0'
              } ${
                row.isActive
                  ? 'border-cyan/50 bg-cyan/[0.08] shadow-[0_0_12px_rgba(56,189,248,0.1)]'
                  : 'border-slate-800/80 bg-[#070b13]/90'
              }`}
            >
              {/* First line: Account name + Status */}
              <div className="flex items-center justify-between gap-2 border-b border-slate-800/60 pb-2">
                <div className="flex items-center gap-1.5 font-bold min-w-0">
                  {row.isActive ? (
                    <span className="active-account-marker text-cyan shrink-0" aria-hidden="true">
                      *
                    </span>
                  ) : (
                    <span className="w-2 shrink-0" aria-hidden="true" />
                  )}
                  <span className={`break-words ${row.isActive ? 'text-ink' : 'text-slate-200'}`}>
                    {row.name}
                  </span>
                </div>
                <StatusBadge status={row.status} />
              </div>

              {/* Labeled lines */}
              <div className="mt-2 space-y-1 divide-y divide-slate-800/40">
                <MobileQuotaRow label="Gemini 5h" entry={row.gemini5h} />
                <MobileQuotaRow label="Gemini Week" entry={row.geminiWeek} />
                {viewMode === 'standard' ? (
                  <MobileQuotaRow label="Argon Week" entry={row.argonWeek} />
                ) : (
                  <>
                    <MobileQuotaRow label="Claude 5h" entry={row.claude5h} />
                    <MobileQuotaRow label="Claude Week" entry={row.claudeWeek} />
                  </>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Semantic Table with responsive layout (>= 768px) */}
      <div className="my-2 hidden md:block overflow-hidden rounded border border-slate-800/80 bg-[#070b13] shadow-inner">
        <table
          className="w-full table-fixed border-collapse font-mono text-[11px] leading-relaxed text-left md:text-xs lg:text-[13px]"
        >
          <thead>
            <tr className="border-b border-slate-700/80 bg-white/[0.03] text-slate-300">
              <th
                scope="col"
                className={`${
                  viewMode === 'claude' ? 'w-[16%]' : 'w-[18%]'
                } border-r border-slate-800/80 px-2 py-2 md:px-2 md:py-2 lg:px-3.5 lg:py-2.5 font-bold tracking-wider break-words text-[11px] md:text-xs`}
              >
                ACCOUNT
              </th>
              <th
                scope="col"
                className={`${
                  viewMode === 'claude' ? 'w-[17%]' : 'w-[23%]'
                } border-r border-slate-800/80 px-2 py-2 md:px-2 md:py-2 lg:px-3.5 lg:py-2.5 font-bold tracking-wider break-words text-[11px] md:text-xs`}
              >
                GEMINI 5H
              </th>
              <th
                scope="col"
                className={`${
                  viewMode === 'claude' ? 'w-[17%]' : 'w-[23%]'
                } border-r border-slate-800/80 px-2 py-2 md:px-2 md:py-2 lg:px-3.5 lg:py-2.5 font-bold tracking-wider break-words text-[11px] md:text-xs`}
              >
                GEMINI WEEK
              </th>
              {viewMode === 'standard' ? (
                <th
                  scope="col"
                  className="w-[22%] border-r border-slate-800/80 px-2 py-2 md:px-2 md:py-2 lg:px-3.5 lg:py-2.5 font-bold tracking-wider break-words text-[11px] md:text-xs"
                >
                  ARGON WEEK
                </th>
              ) : (
                <>
                  <th
                    scope="col"
                    className="w-[17%] border-r border-slate-800/80 px-2 py-2 md:px-2 md:py-2 lg:px-3.5 lg:py-2.5 font-bold tracking-wider break-words text-[11px] md:text-xs"
                  >
                    CLAUDE 5H
                  </th>
                  <th
                    scope="col"
                    className="w-[17%] border-r border-slate-800/80 px-2 py-2 md:px-2 md:py-2 lg:px-3.5 lg:py-2.5 font-bold tracking-wider break-words text-[11px] md:text-xs"
                  >
                    CLAUDE WEEK
                  </th>
                </>
              )}
              <th
                scope="col"
                className={`${
                  viewMode === 'claude' ? 'w-[16%]' : 'w-[14%]'
                } px-2 py-2 md:px-2 md:py-2 lg:px-3.5 lg:py-2.5 font-bold tracking-wider break-words text-[11px] md:text-xs`}
              >
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
                  <td className="border-r border-slate-800/60 px-2 py-1.5 md:px-2 md:py-1.5 lg:px-3.5 lg:py-2 break-words">
                    <div className="flex items-center min-w-0">
                      {row.isActive ? (
                        <span className="active-account-marker mr-1.5 inline-block font-extrabold text-cyan shrink-0">
                          *
                        </span>
                      ) : (
                        <span className="mr-1.5 inline-block w-2.5 shrink-0" />
                      )}
                      <span className={`break-words ${row.isActive ? 'font-bold text-ink' : 'text-slate-300'}`}>
                        {row.name}
                      </span>
                    </div>
                  </td>

                  {/* Gemini 5H */}
                  <td className="border-r border-slate-800/60 px-2 py-1.5 md:px-2 md:py-1.5 lg:px-3.5 lg:py-2 break-words">
                    <QuotaCell entry={row.gemini5h} />
                  </td>

                  {/* Gemini Week */}
                  <td className="border-r border-slate-800/60 px-2 py-1.5 md:px-2 md:py-1.5 lg:px-3.5 lg:py-2 break-words">
                    <QuotaCell entry={row.geminiWeek} />
                  </td>

                  {/* Argon Week or Claude Quotas */}
                  {viewMode === 'standard' ? (
                    <td className="border-r border-slate-800/60 px-2 py-1.5 md:px-2 md:py-1.5 lg:px-3.5 lg:py-2 break-words">
                      <QuotaCell entry={row.argonWeek} />
                    </td>
                  ) : (
                    <>
                      <td className="border-r border-slate-800/60 px-2 py-1.5 md:px-2 md:py-1.5 lg:px-3.5 lg:py-2 break-words">
                        <QuotaCell entry={row.claude5h} />
                      </td>
                      <td className="border-r border-slate-800/60 px-2 py-1.5 md:px-2 md:py-1.5 lg:px-3.5 lg:py-2 break-words">
                        <QuotaCell entry={row.claudeWeek} />
                      </td>
                    </>
                  )}

                  {/* Status */}
                  <td className="px-2 py-1.5 md:px-2 md:py-1.5 lg:px-3.5 lg:py-2 break-words">
                    <StatusBadge status={row.status} />
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <div className="mt-2.5 text-xs text-dim break-words">
        Measured in parallel across 5 accounts in 12s · (* = selected account)
      </div>
    </TerminalChrome>
  );
}
