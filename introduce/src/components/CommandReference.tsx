import { useState, useMemo } from 'react';
import SectionHeading from './SectionHeading';
import Reveal from './Reveal';
import { COMMANDS, type CommandCategory } from './rest/commandsData';

function CopyIconButton({ text }: { text: string }) {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(text);
    } catch {
      const ta = document.createElement('textarea');
      ta.value = text;
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      ta.remove();
    }
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1600);
  };

  return (
    <button
      type="button"
      onClick={handleCopy}
      aria-label={`Copy command: ${text}`}
      title={copied ? 'Copied!' : 'Copy command'}
      className="relative shrink-0 rounded-md border border-white/10 bg-white/5 p-1.5 text-dim transition hover:border-emerald/40 hover:bg-white/10 hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald/60"
    >
      {copied ? (
        <svg
          className="h-3.5 w-3.5 text-emerald"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2.5"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden="true"
        >
          <polyline points="20 6 9 17 4 12" />
        </svg>
      ) : (
        <svg
          className="h-3.5 w-3.5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden="true"
        >
          <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
          <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
        </svg>
      )}
      {copied && (
        <span className="absolute -top-7 right-0 rounded bg-surface px-1.5 py-0.5 text-[10px] font-medium text-emerald shadow border border-emerald/30 whitespace-nowrap">
          Copied!
        </span>
      )}
    </button>
  );
}

const CATEGORY_TABS: Array<{ id: 'all' | CommandCategory; label: string }> = [
  { id: 'all', label: 'All Commands' },
  { id: 'daily', label: 'Account Management' },
  { id: 'auto', label: 'Automation & AI' },
  { id: 'quota', label: 'Quota & Utilities' },
];

export default function CommandReference() {
  const [activeCategory, setActiveCategory] = useState<'all' | CommandCategory>('all');
  const [searchQuery, setSearchQuery] = useState('');

  const filteredCommands = useMemo(() => {
    const query = searchQuery.trim().toLowerCase();
    return COMMANDS.filter((cmd) => {
      const matchesCat = activeCategory === 'all' || cmd.categories.includes(activeCategory);
      if (!matchesCat) return false;
      if (!query) return true;

      const inSyntax = cmd.syntax.toLowerCase().includes(query);
      const inLabel = cmd.categoryLabel.toLowerCase().includes(query);
      const inCopy = cmd.copyText.toLowerCase().includes(query);
      return inSyntax || inLabel || inCopy;
    });
  }, [activeCategory, searchQuery]);

  return (
    <section id="cli-reference" className="relative py-20 sm:py-24">
      {/* Ambient background glow */}
      <div
        className="pointer-events-none absolute left-0 top-1/3 -z-10 h-72 w-72 rounded-full bg-emerald/10 blur-[100px]"
        aria-hidden="true"
      />

      <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
        <SectionHeading
          eyebrow="Documentation"
          title="Complete Command Reference"
          subtitle={
            <>
              All commands and switches supported by{' '}
              <code className="rounded border border-white/10 bg-white/5 px-1.5 py-0.5 font-mono text-xs text-cyan">
                agyr
              </code>
              ,{' '}
              <code className="rounded border border-white/10 bg-white/5 px-1.5 py-0.5 font-mono text-xs text-cyan">
                agy-run
              </code>
              , and{' '}
              <code className="rounded border border-white/10 bg-white/5 px-1.5 py-0.5 font-mono text-xs text-cyan">
                agy-task
              </code>
              .
            </>
          }
        />

        {/* Filter & Search Bar */}
        <Reveal>
          <div className="mb-10 flex flex-col items-stretch justify-between gap-4 md:flex-row md:items-center">
            {/* Category tabs */}
            <div
              className="flex flex-wrap items-center gap-2"
              role="tablist"
              aria-label="Filter command categories"
            >
              {CATEGORY_TABS.map((tab) => {
                const isActive = activeCategory === tab.id;
                return (
                  <button
                    key={tab.id}
                    type="button"
                    role="tab"
                    aria-selected={isActive}
                    onClick={() => setActiveCategory(tab.id)}
                    className={`rounded-md px-3.5 py-1.5 text-xs font-semibold transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald/60 sm:text-sm ${
                      isActive
                        ? 'border border-emerald/50 bg-emerald/15 text-emerald shadow-[0_0_12px_rgba(34,197,94,0.15)]'
                        : 'border border-white/10 bg-white/5 text-muted hover:border-white/20 hover:bg-white/10 hover:text-ink'
                    }`}
                  >
                    {tab.label}
                  </button>
                );
              })}
            </div>

            {/* Search Input */}
            <div className="relative w-full md:max-w-xs">
              <div className="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3 text-dim">
                <svg
                  className="h-4 w-4"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  aria-hidden="true"
                >
                  <circle cx="11" cy="11" r="8" />
                  <line x1="21" y1="21" x2="16.65" y2="16.65" />
                </svg>
              </div>
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Filter commands (e.g. claude, swapui, rotate)..."
                aria-label="Filter commands"
                className="w-full rounded-md border border-white/10 bg-terminal py-2 pl-9 pr-8 text-xs text-ink placeholder:text-dim focus:border-cyan/50 focus:outline-none focus:ring-1 focus:ring-cyan/50 sm:text-sm"
              />
              {searchQuery && (
                <button
                  type="button"
                  onClick={() => setSearchQuery('')}
                  aria-label="Clear search query"
                  className="absolute inset-y-0 right-0 flex items-center pr-2.5 text-dim hover:text-ink"
                >
                  <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <line x1="18" y1="6" x2="6" y2="18" />
                    <line x1="6" y1="6" x2="18" y2="18" />
                  </svg>
                </button>
              )}
            </div>
          </div>
        </Reveal>

        {/* Commands Grid */}
        {filteredCommands.length > 0 ? (
          <div className="grid grid-cols-1 gap-5 md:grid-cols-2 lg:grid-cols-3">
            {filteredCommands.map((cmd, idx) => (
              <Reveal key={cmd.id} delay={Math.min(idx * 30, 240)}>
                <div className="group flex h-full flex-col justify-between rounded-xl border border-white/10 bg-card p-5 backdrop-blur-sm transition duration-200 hover:-translate-y-0.5 hover:border-white/20 hover:bg-[#121a2c]/80 hover:shadow-lg">
                  <div>
                    {/* Header: Syntax + Copy Icon (defect d: copy icon in own corner, never overlapping text) */}
                    <div className="mb-3 flex items-start justify-between gap-3">
                      <code className="min-w-0 flex-1 break-all rounded border border-cyan/25 bg-cyan/10 px-2 py-1 font-mono text-xs font-bold leading-relaxed text-cyan sm:text-sm">
                        {cmd.syntax}
                      </code>
                      <CopyIconButton text={cmd.copyText} />
                    </div>

                    {/* Description */}
                    <div className="text-xs leading-relaxed text-muted sm:text-sm">
                      {cmd.description}
                    </div>
                  </div>

                  {/* Meta / Category Badge */}
                  <div className="mt-4 pt-2 border-t border-white/5">
                    <span className="inline-block rounded border border-white/10 bg-white/5 px-2 py-0.5 text-[11px] font-medium text-dim">
                      {cmd.categoryLabel}
                    </span>
                  </div>
                </div>
              </Reveal>
            ))}
          </div>
        ) : (
          /* Empty state */
          <Reveal>
            <div className="rounded-xl border border-white/10 bg-card py-16 px-4 text-center">
              <svg
                className="mx-auto mb-3 h-8 w-8 text-dim"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
                aria-hidden="true"
              >
                <circle cx="11" cy="11" r="8" />
                <line x1="21" y1="21" x2="16.65" y2="16.65" />
              </svg>
              <p className="text-base font-medium text-ink">No commands match your query.</p>
              <p className="mt-1 text-xs text-dim sm:text-sm">
                Try searching for &quot;claude&quot;, &quot;rotate&quot;, or &quot;swapui&quot;.
              </p>
              <button
                type="button"
                onClick={() => {
                  setActiveCategory('all');
                  setSearchQuery('');
                }}
                className="mt-4 rounded-md border border-emerald/40 bg-emerald/10 px-3.5 py-1.5 text-xs font-semibold text-emerald hover:bg-emerald/20 transition"
              >
                Reset Filters
              </button>
            </div>
          </Reveal>
        )}
      </div>
    </section>
  );
}
