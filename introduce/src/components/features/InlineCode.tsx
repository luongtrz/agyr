import type { ReactNode } from 'react';

export function InlineCode({ children }: { children: ReactNode }) {
  return (
    <code className="font-mono text-[0.82em] px-1.5 py-0.5 rounded bg-white/[0.08] text-slate-200 border border-white/10 break-words">
      {children}
    </code>
  );
}
