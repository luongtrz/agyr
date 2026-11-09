import { useState, type ReactNode } from 'react';
import SectionHeading from './SectionHeading';
import Reveal from './Reveal';
import { SUPPORT_URL, REPO_URL } from '../lib/site';
import './rest/rest.css';

interface FaqItemData {
  id: string;
  question: string;
  answer: ReactNode;
}

const FAQ_ITEMS: FaqItemData[] = [
  {
    id: 'faq-1',
    question: 'Can Google ban my accounts for using agyr?',
    answer: (
      <p>
        No. Unlike proxy routers (which route traffic through custom servers with forged headers and cloud IPs),{' '}
        <code className="rounded border border-white/10 bg-white/5 px-1 py-0.5 font-mono text-xs text-cyan">
          agyr
        </code>{' '}
        is simply a local authentication swapper. It runs Google&apos;s official{' '}
        <code className="rounded border border-white/10 bg-white/5 px-1 py-0.5 font-mono text-xs text-cyan">
          agy
        </code>{' '}
        binary directly on your machine. To Google&apos;s servers, it looks completely identical to you logging in and
        out of different accounts manually.
      </p>
    ),
  },
  {
    id: 'faq-2',
    question: 'How does agy-run maintain conversation context after hitting a 429?',
    answer: (
      <p>
        When a 429 quota exhaustion is detected,{' '}
        <code className="rounded border border-white/10 bg-white/5 px-1 py-0.5 font-mono text-xs text-cyan">
          agy-run
        </code>{' '}
        terminates the current session immediately, puts that slot on cooldown, switches the active token file to the
        best available account, and immediately launches{' '}
        <code className="rounded border border-white/10 bg-white/5 px-1 py-0.5 font-mono text-xs text-cyan">
          agy --conversation &lt;existing-conversation-id&gt;
        </code>
        . Because Antigravity&apos;s conversation history is stored on disk or server session, the new account picks up the
        exact same context without wasting tokens re-reading files.
      </p>
    ),
  },
  {
    id: 'faq-3',
    question: 'What happens if all my saved accounts run out of quota simultaneously?',
    answer: (
      <p>
        If the entire account pool is on cooldown,{' '}
        <code className="rounded border border-white/10 bg-white/5 px-1 py-0.5 font-mono text-xs text-cyan">
          agyr
        </code>{' '}
        and{' '}
        <code className="rounded border border-white/10 bg-white/5 px-1 py-0.5 font-mono text-xs text-cyan">
          agy-run
        </code>{' '}
        cleanly exit with code <strong className="font-semibold text-ink">5</strong> (or code{' '}
        <strong className="font-semibold text-ink">3</strong> for interactive rotate) and display the exact earliest
        reset time in your local timezone (e.g.{' '}
        <em className="text-ink/80">&quot;all accounts on cooldown, earliest reset in 48m at 05:15 PM&quot;</em>). It never
        loops aimlessly or burns tokens.
      </p>
    ),
  },
  {
    id: 'faq-4',
    question: 'Does agyr work with Claude Code or Gemini CLI agents?',
    answer: (
      <p>
        Yes! That is one of its primary design goals. The repository ships with{' '}
        <code className="rounded border border-white/10 bg-white/5 px-1 py-0.5 font-mono text-xs text-cyan">
          skills/agy/
        </code>{' '}
        which lets Claude Code, Antigravity, and Gemini act as orchestrator/reviewers while delegating heavy repetitive
        coding tasks to{' '}
        <code className="rounded border border-white/10 bg-white/5 px-1 py-0.5 font-mono text-xs text-cyan">
          agy-task
        </code>{' '}
        in isolated git worktrees.
      </p>
    ),
  },
  {
    id: 'faq-5',
    question: 'Is agyr completely free? How can I support independent development?',
    answer: (
      <p>
        Yes! <strong className="font-semibold text-ink">agyr is 100% free and open-source</strong> under the MIT
        license with zero commercial tiers, no premium paywalls, and no telemetry. If agyr saves you hours of coding
        downtime and boosts your productivity, starring the project on{' '}
        <a
          href={REPO_URL}
          target="_blank"
          rel="noopener noreferrer"
          className="text-emerald font-medium underline hover:text-emerald-300"
        >
          GitHub
        </a>{' '}
        or buying a coffee on{' '}
        <a
          href={SUPPORT_URL}
          target="_blank"
          rel="noopener noreferrer"
          className="text-amber font-medium underline hover:text-amber-300"
        >
          Ko-fi
        </a>{' '}
        helps fuel continuous maintenance, testing harnesses, and new features.
      </p>
    ),
  },
];

export default function Faq() {
  const [openIds, setOpenIds] = useState<Record<string, boolean>>({
    'faq-1': true, // First open by default for preview
  });

  const toggleItem = (id: string) => {
    setOpenIds((prev) => ({
      ...prev,
      [id]: !prev[id],
    }));
  };

  return (
    <section id="faq" className="relative py-20 sm:py-24">
      {/* Background ambient glow */}
      <div
        className="pointer-events-none absolute left-1/2 top-1/2 -z-10 h-80 w-80 -translate-x-1/2 -translate-y-1/2 rounded-full bg-violet/10 blur-[120px]"
        aria-hidden="true"
      />

      <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
        <SectionHeading
          eyebrow="Frequently Asked Questions"
          title="Common Questions & Answers"
        />

        <div className="space-y-4">
          {FAQ_ITEMS.map((item, idx) => {
            const isOpen = !!openIds[item.id];
            const contentId = `${item.id}-content`;
            return (
              <Reveal key={item.id} delay={idx * 50}>
                <div
                  className={`rounded-xl border transition-all duration-200 ${
                    isOpen
                      ? 'border-emerald/45 bg-gradient-to-b from-[#141d30]/90 to-[#0d121f]/95 shadow-[0_12px_32px_rgba(0,0,0,0.5),0_0_24px_rgba(34,197,94,0.08)]'
                      : 'border-white/10 bg-card hover:border-white/20'
                  }`}
                >
                  <button
                    type="button"
                    onClick={() => toggleItem(item.id)}
                    aria-expanded={isOpen}
                    aria-controls={contentId}
                    className="flex w-full items-center justify-between gap-4 p-5 sm:p-6 text-left transition hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald/60 rounded-xl"
                  >
                    <span className="text-base sm:text-lg font-semibold text-ink">
                      {item.question}
                    </span>
                    <span
                      className={`shrink-0 transition-transform duration-300 ease-out ${
                        isOpen
                          ? 'rotate-180 text-cyan drop-shadow-[0_0_6px_rgba(56,189,248,0.5)]'
                          : 'text-dim'
                      }`}
                      aria-hidden="true"
                    >
                      <svg
                        className="h-5 w-5"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      >
                        <polyline points="6 9 12 15 18 9" />
                      </svg>
                    </span>
                  </button>

                  {/* Animated height container */}
                  <div
                    id={contentId}
                    role="region"
                    aria-labelledby={item.id}
                    className={`grid transition-[grid-template-rows] duration-300 ease-out motion-reduce:transition-none ${
                      isOpen ? 'grid-rows-[1fr]' : 'grid-rows-[0fr]'
                    }`}
                  >
                    <div className="overflow-hidden">
                      <div className="border-l-2 border-emerald/45 ml-5 sm:ml-6 mb-5 pl-4 pr-5 sm:pr-6 text-sm sm:text-base leading-relaxed text-muted animate-faq-slide">
                        {item.answer}
                      </div>
                    </div>
                  </div>
                </div>
              </Reveal>
            );
          })}
        </div>
      </div>
    </section>
  );
}
