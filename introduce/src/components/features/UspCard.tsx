import { useEffect, useRef } from 'react';
import type { UspItem } from './types';
import './features.css';

interface UspCardProps {
  item: UspItem;
}

export function UspCard({ item }: UspCardProps) {
  const cardRef = useRef<HTMLDivElement>(null);
  const rafRef = useRef<number | null>(null);
  const targetX = useRef(0);
  const targetY = useRef(0);
  const currentX = useRef(0);
  const currentY = useRef(0);
  const isHovering = useRef(false);
  const isTabVisible = useRef(true);
  const isInViewport = useRef(true);

  useEffect(() => {
    const card = cardRef.current;
    if (!card) return;

    const onVisibilityChange = () => {
      isTabVisible.current = document.visibilityState === 'visible';
      if (!isTabVisible.current && isHovering.current) {
        if (rafRef.current !== null) {
          cancelAnimationFrame(rafRef.current);
          rafRef.current = null;
        }
        card.style.transform = '';
      }
    };
    document.addEventListener('visibilitychange', onVisibilityChange);

    let observer: IntersectionObserver | null = null;
    if (typeof IntersectionObserver !== 'undefined') {
      observer = new IntersectionObserver(
        ([entry]) => {
          isInViewport.current = entry.isIntersecting;
          if (!entry.isIntersecting && isHovering.current) {
            if (rafRef.current !== null) {
              cancelAnimationFrame(rafRef.current);
              rafRef.current = null;
            }
            card.style.transform = '';
          }
        },
        { threshold: 0.1 },
      );
      observer.observe(card);
    }

    return () => {
      document.removeEventListener('visibilitychange', onVisibilityChange);
      if (observer) {
        observer.disconnect();
      }
      if (rafRef.current !== null) {
        cancelAnimationFrame(rafRef.current);
        rafRef.current = null;
      }
    };
  }, []);

  const updateTilt = () => {
    const card = cardRef.current;
    if (!card || !isHovering.current || !isTabVisible.current || !isInViewport.current) {
      return;
    }

    // Smooth linear interpolation (lerp) identical to legacy/fx/motion.js
    currentX.current += (targetX.current - currentX.current) * 0.16;
    currentY.current += (targetY.current - currentY.current) * 0.16;

    card.style.transform = `perspective(1000px) rotateX(${currentX.current.toFixed(
      2,
    )}deg) rotateY(${currentY.current.toFixed(2)}deg) translateY(-4px)`;

    rafRef.current = requestAnimationFrame(updateTilt);
  };

  const handlePointerMove = (e: React.PointerEvent<HTMLDivElement>) => {
    const card = cardRef.current;
    if (!card) return;

    const rect = card.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;

    // Update mouse coordinates for CSS spotlight border
    card.style.setProperty('--mx', `${x.toFixed(1)}px`);
    card.style.setProperty('--my', `${y.toFixed(1)}px`);

    const hasFinePointer = window.matchMedia('(hover: hover) and (pointer: fine)').matches;
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    if (!hasFinePointer || prefersReducedMotion) {
      return;
    }

    const centerX = rect.width / 2;
    const centerY = rect.height / 2;

    // Clamp tilt angle to subtle [-4.5deg, +4.5deg]
    targetX.current = ((y - centerY) / centerY) * -4.5;
    targetY.current = ((x - centerX) / centerX) * 4.5;

    if (!isHovering.current) {
      isHovering.current = true;
      card.classList.add('is-tilting');
      rafRef.current = requestAnimationFrame(updateTilt);
    }
  };

  const handlePointerLeave = () => {
    const card = cardRef.current;
    if (!card) return;

    isHovering.current = false;
    if (rafRef.current !== null) {
      cancelAnimationFrame(rafRef.current);
      rafRef.current = null;
    }

    card.classList.remove('is-tilting');
    card.style.setProperty('--mx', '-9999px');
    card.style.setProperty('--my', '-9999px');
    card.style.transform = '';
    currentX.current = 0;
    currentY.current = 0;
    targetX.current = 0;
    targetY.current = 0;
  };

  // Accent styling mappings
  const badgeClasses =
    item.accentColor === 'emerald'
      ? 'bg-emerald/15 text-emerald border-emerald/35'
      : item.accentColor === 'cyan'
      ? 'bg-cyan/15 text-cyan border-cyan/35'
      : 'bg-violet/15 text-violet border-violet/35';

  const iconClasses =
    item.accentColor === 'emerald'
      ? 'bg-emerald/12 border-emerald/30 text-emerald shadow-[0_0_15px_rgba(34,197,94,0.12)]'
      : item.accentColor === 'cyan'
      ? 'bg-cyan/12 border-cyan/30 text-cyan shadow-[0_0_15px_rgba(56,189,248,0.12)]'
      : 'bg-violet/12 border-violet/30 text-violet shadow-[0_0_15px_rgba(168,85,247,0.12)]';

  const checkColor =
    item.accentColor === 'emerald'
      ? 'text-emerald'
      : item.accentColor === 'cyan'
      ? 'text-cyan'
      : 'text-violet';

  const watermarkColor =
    item.accentColor === 'emerald'
      ? 'text-emerald'
      : item.accentColor === 'cyan'
      ? 'text-cyan'
      : 'text-violet';

  return (
    <div
      ref={cardRef}
      onPointerMove={handlePointerMove}
      onPointerLeave={handlePointerLeave}
      className="feature-card-tilt feature-spotlight group relative flex flex-col rounded-2xl bg-surface/80 border border-white/10 p-7 sm:p-8 backdrop-blur-md overflow-hidden shadow-lg transition-all duration-300 hover:border-white/20 hover:shadow-2xl"
    >
      {/* Top Badge */}
      <div
        className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold border mb-5 w-fit ${badgeClasses}`}
      >
        {item.badge.icon}
        <span>{item.badge.label}</span>
      </div>

      {/* Main Feature Icon */}
      <div
        className={`w-14 h-14 rounded-xl flex items-center justify-center border mb-6 transition-transform duration-300 group-hover:scale-105 ${iconClasses}`}
      >
        {item.icon}
      </div>

      {/* Title */}
      <h3 className="text-xl sm:text-[1.35rem] font-bold tracking-tight text-white mb-3">
        {item.title}
      </h3>

      {/* Description */}
      <p className="text-sm sm:text-[0.95rem] text-muted leading-relaxed mb-6">
        {item.description}
      </p>

      {/* Bulleted Points with Custom Accent Checkmarks */}
      <ul className="mt-auto space-y-3 pt-2">
        {item.points.map((point, index) => (
          <li key={index} className="flex items-start gap-2.5 text-xs sm:text-[0.88rem] text-slate-300">
            <svg
              className={`shrink-0 mt-0.5 ${checkColor}`}
              width="16"
              height="16"
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
            <span className="leading-snug">{point}</span>
          </li>
        ))}
      </ul>

      {/* Ambient Watermark Icon (positioned bottom-right) */}
      <div
        aria-hidden="true"
        className={`feature-watermark pointer-events-none select-none absolute -right-4 -bottom-4 opacity-5 z-0 ${watermarkColor}`}
      >
        {item.watermark}
      </div>
    </div>
  );
}
