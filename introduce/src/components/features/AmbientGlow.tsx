interface AmbientGlowProps {
  color: 'emerald' | 'cyan' | 'purple';
  top: string;
  left: string;
}

export function AmbientGlow({ color, top, left }: AmbientGlowProps) {
  const gradient =
    color === 'emerald'
      ? 'radial-gradient(circle, rgba(34, 197, 94, 0.28) 0%, transparent 70%)'
      : color === 'cyan'
      ? 'radial-gradient(circle, rgba(56, 189, 248, 0.24) 0%, transparent 70%)'
      : 'radial-gradient(circle, rgba(168, 85, 247, 0.20) 0%, transparent 70%)';

  return (
    <div
      aria-hidden="true"
      style={{
        top,
        left,
        background: gradient,
      }}
      className="pointer-events-none select-none absolute w-[280px] h-[280px] md:w-[460px] md:h-[460px] rounded-full blur-[90px] md:blur-[140px] -translate-x-1/2 -translate-y-1/2 opacity-35 z-0"
    />
  );
}
