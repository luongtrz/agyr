import { useState } from 'react';

/** Copies `text` to the clipboard and shows "Copied!" for 1.6s. */
export default function CopyButton({ text, className = '' }: { text: string; className?: string }) {
  const [done, setDone] = useState(false);
  const onClick = async () => {
    try {
      await navigator.clipboard.writeText(text);
    } catch {
      const ta = document.createElement('textarea');
      ta.value = text;
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      ta.remove();
    }
    setDone(true);
    window.setTimeout(() => setDone(false), 1600);
  };
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label="Copy to clipboard"
      className={`rounded-md border border-white/10 bg-white/5 px-2.5 py-1 text-xs font-medium text-muted transition hover:border-emerald/40 hover:text-ink ${className}`}
    >
      {done ? 'Copied!' : 'Copy'}
    </button>
  );
}
