import { useEffect, useState } from 'react';
import { useInView } from '../../hooks/useInView';
import Reveal from '../Reveal';

export default function HeroMetrics() {
  const [containerRef, inView] = useInView<HTMLDivElement>(0.15);

  const [val1, setVal1] = useState('0 MB');
  const [val2, setVal2] = useState('0%');
  const [val3, setVal3] = useState('100%');
  const [val4, setVal4] = useState('< 1s');

  useEffect(() => {
    if (!inView) return;

    const prefersReducedMotion =
      typeof window !== 'undefined' &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    if (prefersReducedMotion) {
      setVal1('0 MB');
      setVal2('0%');
      setVal3('100%');
      setVal4('< 1s');
      return;
    }

    let animId: number | null = null;
    const startTime = performance.now();

    const update = (now: number) => {
      const elapsed = now - startTime;

      // Card 1: 12 down to 0 MB (duration 800ms)
      const p1 = Math.min(elapsed / 800, 1);
      const ease1 = 1 - Math.pow(1 - p1, 3);
      const cur1 = Math.round(12 - 12 * ease1);
      setVal1(`${cur1} MB`);

      // Card 2: 6 down to 0% (duration 800ms)
      const p2 = Math.min(elapsed / 800, 1);
      const ease2 = 1 - Math.pow(1 - p2, 3);
      const cur2 = Math.round(6 - 6 * ease2);
      setVal2(`${cur2}%`);

      // Card 3: 0 up to 100% (duration 1100ms)
      const p3 = Math.min(elapsed / 1100, 1);
      const ease3 = 1 - Math.pow(1 - p3, 3);
      const cur3 = Math.round(100 * ease3);
      setVal3(`${cur3}%`);

      // Card 4: 2.8s down to 0.8s, then "< 1s" (duration 850ms)
      const p4 = Math.min(elapsed / 850, 1);
      if (p4 < 1) {
        const cur4 = (2.8 - p4 * 2.0).toFixed(1);
        setVal4(`${cur4}s`);
      } else {
        setVal4('< 1s');
      }

      if (elapsed < 1200) {
        animId = requestAnimationFrame(update);
      } else {
        setVal1('0 MB');
        setVal2('0%');
        setVal3('100%');
        setVal4('< 1s');
      }
    };

    animId = requestAnimationFrame(update);

    return () => {
      if (animId) cancelAnimationFrame(animId);
    };
  }, [inView]);

  return (
    <div
      ref={containerRef}
      className="metrics-grid mt-14 grid w-full grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4 sm:gap-6"
    >
      {/* Metric 1 */}
      <Reveal delay={0}>
        <div className="metric-card group relative h-full overflow-hidden rounded-xl border border-white/10 bg-card p-5 sm:p-6 text-left backdrop-blur-md transition-all duration-300 hover:-translate-y-1 hover:border-emerald/30 hover:shadow-xl hover:shadow-black/50">
          <div className="metric-value text-gradient-emerald font-mono text-3xl sm:text-4xl font-extrabold tracking-tight">
            {val1}
          </div>
          <div className="mt-2 text-sm sm:text-base font-bold text-ink">Background RAM</div>
          <p className="mt-1 text-xs text-dim leading-relaxed">
            Pure Bash CLI script. No persistent background daemons or Node/Go containers.
          </p>
        </div>
      </Reveal>

      {/* Metric 2 */}
      <Reveal delay={70}>
        <div className="metric-card group relative h-full overflow-hidden rounded-xl border border-white/10 bg-card p-5 sm:p-6 text-left backdrop-blur-md transition-all duration-300 hover:-translate-y-1 hover:border-cyan/30 hover:shadow-xl hover:shadow-black/50">
          <div className="metric-value text-gradient-blue font-mono text-3xl sm:text-4xl font-extrabold tracking-tight">
            {val2}
          </div>
          <div className="mt-2 text-sm sm:text-base font-bold text-ink">Account Ban Risk</div>
          <p className="mt-1 text-xs text-dim leading-relaxed">
            Runs official binary with genuine Google CLI TLS/HTTP2 fingerprints.
          </p>
        </div>
      </Reveal>

      {/* Metric 3 */}
      <Reveal delay={140}>
        <div className="metric-card group relative h-full overflow-hidden rounded-xl border border-white/10 bg-card p-5 sm:p-6 text-left backdrop-blur-md transition-all duration-300 hover:-translate-y-1 hover:border-violet/30 hover:shadow-xl hover:shadow-black/50">
          <div className="metric-value text-gradient-purple font-mono text-3xl sm:text-4xl font-extrabold tracking-tight">
            {val3}
          </div>
          <div className="mt-2 text-sm sm:text-base font-bold text-ink">Local &amp; Private</div>
          <p className="mt-1 text-xs text-dim leading-relaxed">
            Tokens stay{' '}
            <code className="rounded border border-white/10 bg-white/10 px-1 py-0.5 font-mono text-[11px] text-ink">
              chmod 600
            </code>{' '}
            on disk or OS Credential Manager.
          </p>
        </div>
      </Reveal>

      {/* Metric 4 */}
      <Reveal delay={210}>
        <div className="metric-card group relative h-full overflow-hidden rounded-xl border border-white/10 bg-card p-5 sm:p-6 text-left backdrop-blur-md transition-all duration-300 hover:-translate-y-1 hover:border-amber/30 hover:shadow-xl hover:shadow-black/50">
          <div className="metric-value text-gradient-amber font-mono text-3xl sm:text-4xl font-extrabold tracking-tight">
            {val4}
          </div>
          <div className="mt-2 text-sm sm:text-base font-bold text-ink">429 Failover</div>
          <p className="mt-1 text-xs text-dim leading-relaxed">
            Automated slot switch and instant{' '}
            <code className="rounded border border-white/10 bg-white/10 px-1 py-0.5 font-mono text-[11px] text-ink">
              --conversation
            </code>{' '}
            context recovery.
          </p>
        </div>
      </Reveal>
    </div>
  );
}
