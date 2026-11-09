import { useEffect, useRef, useState } from 'react';

const SIMULATION_MESSAGES = [
  'Slot #1 hit HTTP 429 - Auto-swapped to Slot #2 in 0.84s',
  'Context preserved - Session resumed with zero token loss',
  'Slot #4 cooling down - Auto-re-queued for rotation in 12m',
  'Official Google TLS fingerprint - 0 proxies · 0 ban risk',
  '5/5 Google slots active - Continuous Antigravity coding',
];

export default function HeroTicker() {
  const [index, setIndex] = useState(0);
  const [fadeState, setFadeState] = useState<'in' | 'out'>('in');
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (
      typeof window !== 'undefined' &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches
    ) {
      return;
    }

    let intervalId: ReturnType<typeof setInterval> | null = null;
    let fadeTimeoutId: ReturnType<typeof setTimeout> | null = null;

    const tick = () => {
      setFadeState('out');
      fadeTimeoutId = setTimeout(() => {
        setIndex((prev) => (prev + 1) % SIMULATION_MESSAGES.length);
        setFadeState('in');
      }, 250);
    };

    const startTimer = () => {
      if (!intervalId) {
        intervalId = setInterval(tick, 4200);
      }
    };

    const stopTimer = () => {
      if (intervalId) {
        clearInterval(intervalId);
        intervalId = null;
      }
    };

    startTimer();

    let observer: IntersectionObserver | null = null;
    if (typeof IntersectionObserver !== 'undefined' && containerRef.current) {
      observer = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (entry.isIntersecting) {
              startTimer();
            } else {
              stopTimer();
            }
          });
        },
        { threshold: 0.1 }
      );
      observer.observe(containerRef.current);
    }

    return () => {
      stopTimer();
      if (fadeTimeoutId) clearTimeout(fadeTimeoutId);
      if (observer) observer.disconnect();
    };
  }, []);

  return (
    <div
      ref={containerRef}
      aria-label="agyr auto-failover simulation"
      className="relative z-10 mx-auto mb-6 inline-flex max-w-[95%] items-center gap-2.5 rounded-full border border-cyan/25 bg-surface/85 px-3.5 py-1.5 font-mono text-xs text-muted shadow-lg shadow-black/40 backdrop-blur-md transition-all duration-300 hover:border-cyan/45 hover:shadow-cyan/10"
    >
      <span className="ticker-pulse" aria-hidden="true" />
      <span className="shrink-0 rounded border border-cyan/30 bg-cyan/15 px-1.5 py-0.5 text-[10px] font-bold tracking-wide text-cyan uppercase">
        Live Engine
      </span>
      <span
        className={`truncate text-slate-200 transition-all duration-250 ${
          fadeState === 'out'
            ? '-translate-y-1 opacity-0'
            : 'translate-y-0 opacity-100'
        }`}
      >
        {SIMULATION_MESSAGES[index]}
      </span>
    </div>
  );
}
