import type { ReactNode } from 'react';
import CopyButton from '../CopyButton';

export interface TerminalChromeProps {
  title: string;
  shell: string;
  statusPillText: string;
  statusPillVariant?: 'emerald' | 'danger' | 'amber' | 'violet';
  haloColor?: string;
  tools?: ReactNode;
  children: ReactNode;
  copyText?: string;
}

export default function TerminalChrome({
  title,
  shell,
  statusPillText,
  statusPillVariant = 'emerald',
  haloColor = 'rgba(34, 197, 94, 0.18)',
  tools,
  children,
  copyText,
}: TerminalChromeProps) {
  const variantStyles = {
    emerald: {
      pill: 'bg-emerald/10 border-emerald/30 text-emerald',
      dot: 'bg-emerald shadow-[0_0_8px_var(--color-emerald)]',
    },
    danger: {
      pill: 'bg-danger/10 border-danger/40 text-danger',
      dot: 'bg-danger shadow-[0_0_8px_var(--color-danger)]',
    },
    amber: {
      pill: 'bg-amber/10 border-amber/40 text-amber',
      dot: 'bg-amber shadow-[0_0_8px_var(--color-amber)]',
    },
    violet: {
      pill: 'bg-violet/10 border-violet/40 text-violet',
      dot: 'bg-violet shadow-[0_0_8px_var(--color-violet)]',
    },
  }[statusPillVariant];

  return (
    <div className="relative">
      {/* Ambient background glow halo */}
      <div
        className="terminal-ambient-halo"
        style={{ '--terminal-halo-color': haloColor } as React.CSSProperties}
        aria-hidden="true"
      />

      {/* Terminal container frame */}
      <div className="terminal-wrapper relative z-10 overflow-hidden rounded-xl border border-white/10 bg-gradient-to-b from-[#0b111e] to-[#080c15] shadow-2xl transition-all duration-300 hover:border-white/20">
        {/* CRT Scanline & Glass Sheen Overlay */}
        <div className="terminal-crt-scanlines" aria-hidden="true" />
        <div className="terminal-glass-shine" aria-hidden="true" />

        {/* Terminal Header */}
        <div className="terminal-header flex flex-wrap items-center justify-between gap-3 border-b border-white/10 bg-gradient-to-b from-[#151d2c] to-[#101623] px-3.5 py-2.5 sm:px-5 sm:py-3">
          <div className="flex items-center gap-3">
            {/* Traffic Light Dots */}
            <div className="terminal-dots flex items-center gap-1.5" aria-hidden="true">
              <span className="dot dot-red" />
              <span className="dot dot-yellow" />
              <span className="dot dot-green" />
            </div>

            {/* Title Bar */}
            <div className="terminal-title flex flex-wrap items-center gap-2 font-mono text-xs text-slate-300">
              <span className="font-medium text-slate-200">{title}</span>
              <span className="terminal-shell-badge rounded border border-white/10 bg-white/5 px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wider text-dim">
                {shell}
              </span>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2.5">
            {/* Live Status Pill */}
            <div
              className={`term-status-pill inline-flex items-center gap-1.5 rounded-full border px-2.5 py-0.5 font-mono text-[11px] font-semibold tracking-wide transition-colors duration-300 ${variantStyles.pill}`}
            >
              <span className={`term-status-dot h-1.5 w-1.5 rounded-full ${variantStyles.dot}`} />
              <span className="whitespace-nowrap">{statusPillText}</span>
            </div>

            {/* Tools slot & Copy button */}
            <div className="terminal-tools flex items-center gap-2">
              {tools}
              {copyText && (
                <CopyButton
                  text={copyText}
                  className="font-mono text-xs tracking-tight"
                />
              )}
            </div>
          </div>
        </div>

        {/* Terminal Screen Surface */}
        <div className="terminal-screen overflow-x-auto bg-[#070b13] p-4 font-mono text-xs leading-relaxed text-slate-200 sm:p-6 sm:text-sm">
          {children}
        </div>
      </div>
    </div>
  );
}
