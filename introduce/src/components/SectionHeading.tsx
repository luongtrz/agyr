import type { ReactNode } from 'react';

export default function SectionHeading({
  eyebrow,
  title,
  subtitle,
}: {
  eyebrow: string;
  title: ReactNode;
  subtitle?: ReactNode;
}) {
  return (
    <div className="mx-auto mb-14 max-w-3xl text-center">
      <p className="mb-3 text-xs font-bold uppercase tracking-[0.2em] text-emerald">{eyebrow}</p>
      <h2 className="text-3xl font-bold tracking-tight text-ink sm:text-4xl">{title}</h2>
      <div className="mx-auto mt-4 h-0.5 w-12 rounded bg-gradient-to-r from-emerald to-cyan" />
      {subtitle && <p className="mt-5 text-base text-muted sm:text-lg">{subtitle}</p>}
    </div>
  );
}
