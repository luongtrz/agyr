import { useState, useEffect, useRef, useCallback } from 'react';
import TerminalChrome from './TerminalChrome';
import { FAILOVER_COMMAND, FAILOVER_TERMINAL_TEXT } from './showcaseData';
import { useTypewriter } from '../../hooks/useTypewriter';

export default function FailoverDemo({ isActive = true }: { isActive?: boolean }) {
  const [visibleStep, setVisibleStep] = useState<number>(0);
  const [isReplaying, setIsReplaying] = useState(false);
  const timersRef = useRef<number[]>([]);

  const { displayedText, isTyping } = useTypewriter(FAILOVER_COMMAND, {
    start: isActive,
    speed: 18,
  });

  const clearAllTimers = useCallback(() => {
    timersRef.current.forEach((id) => clearTimeout(id));
    timersRef.current = [];
  }, []);

  const playAnimation = useCallback(() => {
    clearAllTimers();

    const isReduced =
      typeof window !== 'undefined' &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    if (isReduced) {
      setVisibleStep(7);
      return;
    }

    setVisibleStep(0);

    const stepDelays = [
      { step: 1, delay: 300 },
      { step: 2, delay: 1000 },
      { step: 3, delay: 1800 },
      { step: 4, delay: 2600 },
      { step: 5, delay: 3400 },
      { step: 6, delay: 4200 },
      { step: 7, delay: 4800 },
    ];

    stepDelays.forEach(({ step, delay }) => {
      const id = window.setTimeout(() => {
        setVisibleStep(step);
      }, delay);
      timersRef.current.push(id);
    });
  }, [clearAllTimers]);

  useEffect(() => {
    if (isActive) {
      playAnimation();
    } else {
      clearAllTimers();
      setVisibleStep(0);
    }
    return () => {
      clearAllTimers();
    };
  }, [isActive, playAnimation, clearAllTimers]);

  const handleReplay = () => {
    setIsReplaying(true);
    window.setTimeout(() => setIsReplaying(false), 750);
    playAnimation();
  };

  let statusPillText = 'FAILOVER READY';
  let statusPillVariant: 'emerald' | 'danger' | 'amber' | 'violet' = 'emerald';
  let haloColor = 'rgba(56, 189, 248, 0.18)';

  if (visibleStep >= 6) {
    statusPillText = 'RESUME OK · 0 TOKENS LOST';
    statusPillVariant = 'emerald';
    haloColor = 'rgba(34, 197, 94, 0.32)';
  } else if (visibleStep >= 5) {
    statusPillText = 'CONTEXT RESUMED (9c4e1a80)';
    statusPillVariant = 'violet';
    haloColor = 'rgba(192, 132, 252, 0.32)';
  } else if (visibleStep >= 4) {
    statusPillText = 'FAILOVER: WORK-1 to WORK-2';
    statusPillVariant = 'amber';
    haloColor = 'rgba(245, 158, 11, 0.32)';
  } else if (visibleStep >= 3) {
    statusPillText = '429 QUOTA WALL HIT';
    statusPillVariant = 'danger';
    haloColor = 'rgba(239, 68, 68, 0.32)';
  }

  const failoverTools = (
    <button
      type="button"
      onClick={handleReplay}
      aria-label="Replay failover sequence"
      className="inline-flex items-center gap-1.5 rounded border border-white/10 bg-white/5 px-2.5 py-1 text-xs font-semibold text-slate-200 transition hover:border-emerald/40 hover:bg-white/10 hover:text-white"
    >
      <svg
        className={`h-3.5 w-3.5 ${isReplaying ? 'replaying-icon' : ''}`}
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden="true"
      >
        <polyline points="23 4 23 10 17 10" />
        <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10" />
      </svg>
      <span>Replay Flow</span>
    </button>
  );

  return (
    <TerminalChrome
      title="agy-run — Autonomous 429 Quota Failover & Session Resume"
      shell="daemon"
      statusPillText={statusPillText}
      statusPillVariant={statusPillVariant}
      haloColor={haloColor}
      tools={failoverTools}
      copyText={FAILOVER_TERMINAL_TEXT}
    >
      <div className="space-y-1.5 font-mono text-xs leading-relaxed sm:text-sm">
        {/* Command line */}
        <div className="flex flex-wrap items-center">
          <span className="font-semibold text-emerald">user@devbox</span>
          <span className="text-dim">:</span>
          <span className="font-semibold text-cyan">~/projects/auth-svc</span>
          <span className="text-dim">$ </span>
          <span className="ml-1.5 font-semibold text-ink">{displayedText}</span>
          {isTyping && (
            <span className="ml-0.5 inline-block font-bold text-emerald animate-pulse" aria-hidden="true">
              ▋
            </span>
          )}
        </div>

        {/* Step 1: Initial slot run */}
        <div
          className={`transition-all duration-300 ${
            visibleStep >= 1 ? 'translate-y-0 opacity-100' : 'translate-y-1 opacity-0'
          }`}
        >
          <span className="font-bold text-cyan">[agy-run]</span>{' '}
          <span className="text-slate-200">running on account </span>
          <span className="font-semibold text-amber">'work-1'</span>{' '}
          <span className="text-dim">(model: gemini-3.8-flash-high)</span>
        </div>

        {/* Step 2: agy running */}
        <div
          className={`transition-all duration-300 ${
            visibleStep >= 2 ? 'translate-y-0 opacity-100' : 'translate-y-1 opacity-0'
          }`}
        >
          <span className="text-dim">agy: analyzing codebase and editing middleware.go...</span>
        </div>

        {/* Step 3: 429 Hit with Red Alert Flash */}
        <div
          className={`transition-all duration-300 ${
            visibleStep >= 3
              ? 'term-line-429 translate-y-0 px-2 py-0.5 opacity-100'
              : 'translate-y-1 opacity-0'
          }`}
        >
          <span className="font-bold text-cyan">[agy-run]</span>{' '}
          <span className="font-bold text-danger">429 quota reached on 'work-1'</span>{' '}
          <span className="font-semibold text-amber">(Resets in 4h13m20s)</span>{' '}
          <span className="text-dim">— killing agy immediately</span>
        </div>

        {/* Step 4: Cooldown & Switch with Green Pulse */}
        <div
          className={`transition-all duration-300 ${
            visibleStep >= 4
              ? 'term-line-switch translate-y-0 px-2 py-0.5 opacity-100'
              : 'translate-y-1 opacity-0'
          }`}
        >
          <span className="font-bold text-cyan">[agy-run]</span>{' '}
          <span className="text-slate-200">cooldown 'work-1' set to 4h13m20s; switching to </span>
          <span className="font-bold text-emerald">'work-2'</span>{' '}
          <span className="text-dim">(weekly limit resets soonest)</span>
        </div>

        {/* Step 5: Resume session */}
        <div
          className={`transition-all duration-300 ${
            visibleStep >= 5 ? 'translate-y-0 opacity-100' : 'translate-y-1 opacity-0'
          }`}
        >
          <span className="font-bold text-cyan">[agy-run]</span>{' '}
          <span className="text-slate-200">resuming conversation </span>
          <span className="font-semibold text-violet">9c4e1a80-bf82-49da-8b29-9e8c45e69e41</span>{' '}
          <span className="text-slate-200">on account </span>
          <span className="font-bold text-emerald">'work-2'</span>
        </div>

        {/* Step 6: Victory OK */}
        <div
          className={`transition-all duration-300 ${
            visibleStep >= 6
              ? 'term-line-ok translate-y-0 px-2 py-0.5 opacity-100'
              : 'translate-y-1 opacity-0'
          }`}
        >
          <span className="font-bold text-cyan">[agy-run]</span>{' '}
          <span className="text-slate-200">done (account </span>
          <span className="font-bold text-emerald">'work-2'</span>
          <span className="text-slate-200">) — </span>
          <span className="font-bold text-emerald">RESULT=OK</span>
        </div>

        {/* Step 7: Completed Prompt */}
        <div
          className={`pt-1 transition-all duration-300 ${
            visibleStep >= 7 ? 'translate-y-0 opacity-100' : 'translate-y-1 opacity-0'
          }`}
        >
          <span className="font-semibold text-emerald">user@devbox</span>
          <span className="text-dim">:</span>
          <span className="font-semibold text-cyan">~/projects/auth-svc</span>
          <span className="text-dim">$ </span>
          <span className="ml-1 inline-block font-bold text-emerald animate-pulse" aria-hidden="true">
            ▋
          </span>
        </div>
      </div>
    </TerminalChrome>
  );
}
