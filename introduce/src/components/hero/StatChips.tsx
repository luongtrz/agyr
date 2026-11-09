interface StatChipsProps {
  /** If 'gutters', renders floating chips in wide side gutters (min-[1360px]).
   * If 'inline', renders a responsive horizontal row for smaller screens. */
  variant: 'gutters' | 'inline';
}

export default function StatChips({ variant }: StatChipsProps) {
  if (variant === 'gutters') {
    return (
      <div
        className="pointer-events-none absolute inset-0 z-20 hidden min-[1360px]:block"
        aria-hidden="true"
      >
        {/* Chip 1 — Upper Left Gutter */}
        <div
          title="Real-time 429 detection & automatic account rotation"
          className="hero-chip-float-1 pointer-events-auto absolute top-[22%] left-4 xl:left-8 flex cursor-default select-none items-center gap-3 rounded-xl border border-white/10 bg-surface/85 px-3.5 py-2.5 shadow-xl shadow-black/40 backdrop-blur-md transition-all duration-200 hover:-translate-y-1 hover:border-white/25 hover:shadow-cyan/10"
        >
          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg border border-emerald/25 bg-emerald/10 text-emerald">
            <svg
              width="17"
              height="17"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.5"
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden="true"
            >
              <polyline points="23 4 23 10 17 10" />
              <polyline points="1 20 1 14 7 14" />
              <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" />
            </svg>
          </div>
          <div className="flex flex-col text-left">
            <span className="text-xs font-bold leading-tight text-white">429 Auto-Failover</span>
            <span className="font-mono text-[11px] leading-tight text-dim">&lt; 1s slot switch · no restart</span>
          </div>
          <span className="rounded-full border border-emerald/30 bg-emerald/15 px-2 py-0.5 text-[10px] font-semibold text-emerald">
            Active
          </span>
        </div>

        {/* Chip 2 — Upper Right Gutter */}
        <div
          title="100% Genuine Google CLI TLS stack"
          className="hero-chip-float-2 pointer-events-auto absolute top-[28%] right-4 xl:right-8 flex cursor-default select-none items-center gap-3 rounded-xl border border-white/10 bg-surface/85 px-3.5 py-2.5 shadow-xl shadow-black/40 backdrop-blur-md transition-all duration-200 hover:-translate-y-1 hover:border-white/25 hover:shadow-cyan/10"
        >
          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg border border-cyan/25 bg-cyan/10 text-cyan">
            <svg
              width="17"
              height="17"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.5"
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden="true"
            >
              <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
            </svg>
          </div>
          <div className="flex flex-col text-left">
            <span className="text-xs font-bold leading-tight text-white">Zero Ban Risk</span>
            <span className="font-mono text-[11px] leading-tight text-dim">Official TLS fingerprints</span>
          </div>
          <span className="rounded-full border border-cyan/30 bg-cyan/15 px-2 py-0.5 text-[10px] font-semibold text-cyan">
            100% Local
          </span>
        </div>

        {/* Chip 3 — Lower Left Gutter */}
        <div
          title="Pure Bash script with zero background memory"
          className="hero-chip-float-3 pointer-events-auto absolute top-[68%] left-6 xl:left-12 flex cursor-default select-none items-center gap-3 rounded-xl border border-white/10 bg-surface/85 px-3.5 py-2.5 shadow-xl shadow-black/40 backdrop-blur-md transition-all duration-200 hover:-translate-y-1 hover:border-white/25 hover:shadow-cyan/10"
        >
          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg border border-violet/25 bg-violet/10 text-violet">
            <svg
              width="17"
              height="17"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.5"
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden="true"
            >
              <rect x="2" y="2" width="20" height="8" rx="2" ry="2" />
              <rect x="2" y="14" width="20" height="8" rx="2" ry="2" />
              <line x1="6" y1="6" x2="6.01" y2="6" />
              <line x1="6" y1="18" x2="6.01" y2="18" />
            </svg>
          </div>
          <div className="flex flex-col text-left">
            <span className="text-xs font-bold leading-tight text-white">0 MB Background RAM</span>
            <span className="font-mono text-[11px] leading-tight text-dim">Pure Bash · zero daemons</span>
          </div>
          <span className="rounded-full border border-violet/30 bg-violet/15 px-2 py-0.5 text-[10px] font-semibold text-violet">
            Ultra-light
          </span>
        </div>
      </div>
    );
  }

  // Inline row for smaller screens (under 1360px) below CTAs
  return (
    <div className="my-8 flex min-[1360px]:hidden flex-wrap items-center justify-center gap-3">
      {/* Chip 1 */}
      <div
        title="Real-time 429 detection & automatic account rotation"
        className="flex cursor-default select-none items-center gap-2.5 rounded-xl border border-white/10 bg-surface/80 px-3 py-2 shadow-md shadow-black/30 backdrop-blur-md"
      >
        <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg border border-emerald/25 bg-emerald/10 text-emerald">
          <svg
            width="15"
            height="15"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.5"
            strokeLinecap="round"
            strokeLinejoin="round"
            aria-hidden="true"
          >
            <polyline points="23 4 23 10 17 10" />
            <polyline points="1 20 1 14 7 14" />
            <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" />
          </svg>
        </div>
        <div className="flex flex-col text-left">
          <span className="text-xs font-bold leading-tight text-white">429 Auto-Failover</span>
          <span className="font-mono text-[10px] leading-tight text-dim">&lt; 1s slot switch</span>
        </div>
        <span className="rounded-full border border-emerald/30 bg-emerald/15 px-1.5 py-0.5 text-[9px] font-semibold text-emerald">
          Active
        </span>
      </div>

      {/* Chip 2 */}
      <div
        title="100% Genuine Google CLI TLS stack"
        className="flex cursor-default select-none items-center gap-2.5 rounded-xl border border-white/10 bg-surface/80 px-3 py-2 shadow-md shadow-black/30 backdrop-blur-md"
      >
        <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg border border-cyan/25 bg-cyan/10 text-cyan">
          <svg
            width="15"
            height="15"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.5"
            strokeLinecap="round"
            strokeLinejoin="round"
            aria-hidden="true"
          >
            <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
          </svg>
        </div>
        <div className="flex flex-col text-left">
          <span className="text-xs font-bold leading-tight text-white">Zero Ban Risk</span>
          <span className="font-mono text-[10px] leading-tight text-dim">Official TLS</span>
        </div>
        <span className="rounded-full border border-cyan/30 bg-cyan/15 px-1.5 py-0.5 text-[9px] font-semibold text-cyan">
          100% Local
        </span>
      </div>

      {/* Chip 3 */}
      <div
        title="Pure Bash script with zero background memory"
        className="flex cursor-default select-none items-center gap-2.5 rounded-xl border border-white/10 bg-surface/80 px-3 py-2 shadow-md shadow-black/30 backdrop-blur-md"
      >
        <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg border border-violet/25 bg-violet/10 text-violet">
          <svg
            width="15"
            height="15"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.5"
            strokeLinecap="round"
            strokeLinejoin="round"
            aria-hidden="true"
          >
            <rect x="2" y="2" width="20" height="8" rx="2" ry="2" />
            <rect x="2" y="14" width="20" height="8" rx="2" ry="2" />
            <line x1="6" y1="6" x2="6.01" y2="6" />
            <line x1="6" y1="18" x2="6.01" y2="18" />
          </svg>
        </div>
        <div className="flex flex-col text-left">
          <span className="text-xs font-bold leading-tight text-white">0 MB Background RAM</span>
          <span className="font-mono text-[10px] leading-tight text-dim">Pure Bash</span>
        </div>
        <span className="rounded-full border border-violet/30 bg-violet/15 px-1.5 py-0.5 text-[9px] font-semibold text-violet">
          Ultra-light
        </span>
      </div>
    </div>
  );
}
