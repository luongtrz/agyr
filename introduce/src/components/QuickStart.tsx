import type { ReactNode } from 'react';
import SectionHeading from './SectionHeading';
import Reveal from './Reveal';
import CodeBlock from './quickstart/CodeBlock';

interface StepItem {
  number: string;
  title: string;
  description: ReactNode;
  code: string;
  copyText: string;
}

const STEPS: StepItem[] = [
  {
    number: '01',
    title: 'Sign in and save Account #1',
    description: (
      <>
        Launch{' '}
        <code className="rounded bg-white/10 px-1 py-0.5 font-mono text-xs text-cyan">agyr</code>{' '}
        to trigger Google&apos;s browser OAuth login, then save the active session into slot{' '}
        <code className="rounded bg-white/10 px-1 py-0.5 font-mono text-xs text-cyan">acc1</code>.
      </>
    ),
    code: '# Opens browser for account 1\nagyr\n\n# Save credentials into slot \'acc1\'\nagyr save acc1',
    copyText: 'agyr\nagyr save acc1',
  },
  {
    number: '02',
    title: 'Add Account #2 (and more)',
    description: (
      <>
        Use{' '}
        <code className="rounded bg-white/10 px-1 py-0.5 font-mono text-xs text-cyan">
          agyr forget
        </code>{' '}
        to clear local active tokens safely (without revoking stored slots), then sign in with your next
        Google account.
      </>
    ),
    code: '# Safely clears active login (acc1 is safe)\nagyr forget\n\n# Sign in to account 2 in browser\nagyr\nagyr save acc2',
    copyText: 'agyr forget\nagyr\nagyr save acc2',
  },
  {
    number: '03',
    title: 'Inspect Live Quota Status',
    description: (
      <>
        Query all your accounts in parallel. View 5-hour and weekly percentages with color-coded
        health indicators.
      </>
    ),
    code: '# Real-time multi-account dashboard\nagyr list\n\n# Or check fast cached values\nagyr list -c',
    copyText: 'agyr list',
  },
  {
    number: '04',
    title: 'Run Automated Tasks with 429 Failover',
    description: (
      <>
        Use{' '}
        <code className="rounded bg-white/10 px-1 py-0.5 font-mono text-xs text-cyan">
          agy-run
        </code>{' '}
        for automated coding tasks. If an account runs dry, it switches slots and keeps coding.
      </>
    ),
    code: '# Automated execution with 429 failover\nagy-run --add-dir . \\\n  --prompt "Refactor database queries and add indexes"',
    copyText: 'agy-run --add-dir . --prompt "Refactor database queries and add indexes"',
  },
];

export default function QuickStart() {
  return (
    <section id="quick-start" className="relative py-20 sm:py-24">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <Reveal>
          <SectionHeading
            eyebrow="Step-by-Step Setup"
            title="Get Started in 4 Easy Steps"
            subtitle={
              <>
                Add multiple accounts once in your browser.{' '}
                <code className="rounded bg-white/10 px-1.5 py-0.5 font-mono text-xs sm:text-sm text-cyan">
                  agyr
                </code>{' '}
                manages the credentials forever.
              </>
            }
          />
        </Reveal>

        <div className="relative mt-12 sm:mt-16">
          {/* Subtle horizontal connecting line across steps on desktop (defect e) */}
          <div
            className="pointer-events-none absolute top-11 left-[10%] right-[10%] hidden h-[2px] bg-gradient-to-r from-emerald/0 via-white/15 to-emerald/0 lg:block"
            aria-hidden="true"
          />

          <div className="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-4">
            {STEPS.map((step, idx) => (
              <Reveal key={step.number} delay={idx * 100} className="h-full">
                <div className="relative z-10 flex h-full flex-col rounded-2xl border border-white/10 bg-card p-5 sm:p-6 backdrop-blur-md transition duration-300 hover:-translate-y-1 hover:border-emerald/40 hover:shadow-[0_12px_30px_rgba(0,0,0,0.4)]">
                  {/* Step header with compact badge */}
                  <div className="mb-4 flex items-center justify-between">
                    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border border-emerald/40 bg-emerald/10 font-mono text-sm font-bold text-emerald shadow-[0_0_14px_rgba(34,197,94,0.15)]">
                      {step.number}
                    </div>
                    <span className="font-mono text-xs uppercase tracking-wider text-dim">
                      Step {step.number}
                    </span>
                  </div>

                  {/* Title & Description */}
                  <h3 className="mb-2 text-base font-semibold text-ink sm:text-lg">
                    {step.title}
                  </h3>
                  <p className="mb-6 text-sm leading-relaxed text-muted">
                    {step.description}
                  </p>

                  {/* Code Block pushed to bottom */}
                  <div className="mt-auto">
                    <CodeBlock code={step.code} copyText={step.copyText} />
                  </div>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
