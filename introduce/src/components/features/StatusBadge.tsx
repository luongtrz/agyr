import type { BadgeVariant } from './types';

interface StatusBadgeProps {
  variant: BadgeVariant;
  text: string;
}

export function StatusBadge({ variant, text }: StatusBadgeProps) {
  if (variant === 'green') {
    return (
      <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-md text-xs font-semibold leading-snug tracking-wide bg-emerald/15 text-emerald border border-emerald/40 shadow-[0_0_12px_rgba(34,197,94,0.14)] w-fit mb-1.5">
        <svg
          className="shrink-0"
          width="13"
          height="13"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="3"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden="true"
        >
          <polyline points="20 6 9 17 4 12" />
        </svg>
        <span>{text}</span>
      </span>
    );
  }

  if (variant === 'red') {
    return (
      <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-md text-xs font-semibold leading-snug tracking-wide bg-danger/15 text-[#f87171] border border-danger/40 shadow-[0_0_10px_rgba(239,68,68,0.12)] w-fit mb-1.5">
        <svg
          className="shrink-0"
          width="13"
          height="13"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="3"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden="true"
        >
          <line x1="18" y1="6" x2="6" y2="18" />
          <line x1="6" y1="6" x2="18" y2="18" />
        </svg>
        <span>{text}</span>
      </span>
    );
  }

  if (variant === 'amber') {
    return (
      <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-md text-xs font-semibold leading-snug tracking-wide bg-amber/15 text-[#fbbf24] border border-amber/40 shadow-[0_0_10px_rgba(245,158,11,0.12)] w-fit mb-1.5">
        <svg
          className="shrink-0"
          width="13"
          height="13"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2.5"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden="true"
        >
          <path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z" />
          <line x1="12" y1="9" x2="12" y2="13" />
          <line x1="12" y1="17" x2="12.01" y2="17" />
        </svg>
        <span>{text}</span>
      </span>
    );
  }

  return (
    <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-md text-xs font-semibold leading-snug tracking-wide bg-white/[0.07] text-[#94a3b8] border border-white/15 w-fit mb-1.5">
      <svg
        className="shrink-0"
        width="13"
        height="13"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2.5"
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden="true"
      >
        <circle cx="12" cy="12" r="10" />
        <line x1="8" y1="12" x2="16" y2="12" />
      </svg>
      <span>{text}</span>
    </span>
  );
}
