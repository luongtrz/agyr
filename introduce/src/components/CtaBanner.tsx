import { REPO_URL, INSTALL_CMD } from '../lib/site';
import CopyButton from './CopyButton';
import Reveal from './Reveal';
import './rest/rest.css';

export default function CtaBanner() {
  return (
    <section id="get-started" className="relative py-20 sm:py-24">
      {/* Background ambient glow */}
      <div
        className="pointer-events-none absolute left-1/2 top-1/2 -z-10 h-96 w-96 -translate-x-1/2 -translate-y-1/2 rounded-full bg-emerald/10 blur-[130px]"
        aria-hidden="true"
      />

      <div className="mx-auto max-w-5xl px-4 sm:px-6 lg:px-8">
        <Reveal>
          {/* Animated gradient border container */}
          <div className="relative overflow-hidden rounded-3xl p-[1px] shadow-[0_24px_65px_rgba(0,0,0,0.7),0_0_40px_rgba(34,197,94,0.12)]">
            {/* Spinning conic gradient border */}
            <div
              className="absolute -top-[50%] -left-[50%] h-[200%] w-[200%] animate-cta-spin opacity-85 pointer-events-none"
              style={{
                background:
                  'conic-gradient(transparent, rgba(34, 197, 94, 0.45), rgba(56, 189, 248, 0.5), rgba(168, 85, 247, 0.4), transparent 65%)',
              }}
              aria-hidden="true"
            />

            {/* Inner banner surface */}
            <div className="relative z-10 rounded-[calc(1.5rem-1px)] bg-gradient-to-b from-[#0d1527] to-[#070b14] px-4 py-10 text-center sm:px-12 sm:py-16">
              <h2 className="mx-auto max-w-2xl text-xl font-bold tracking-tight text-ink sm:text-3xl md:text-4xl break-words">
                Ready to 10x your Antigravity coding capacity?
              </h2>
              <p className="mx-auto mt-4 max-w-xl text-sm text-muted sm:text-base md:text-lg break-words">
                Install agyr in seconds with zero configuration and start rotating accounts today.
              </p>

              {/* Install command box */}
              <div className="mx-auto mt-8 max-w-2xl">
                <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 rounded-xl border border-white/10 bg-terminal/95 p-3 sm:px-4 sm:py-3 shadow-inner">
                  <div className="flex min-w-0 flex-1 items-start sm:items-center gap-2.5 py-1">
                    <span className="shrink-0 select-none font-mono text-sm font-bold text-emerald">$</span>
                    <code className="min-w-0 font-mono text-xs sm:text-sm text-ink break-all whitespace-pre-wrap">
                      {INSTALL_CMD}
                    </code>
                  </div>
                  <CopyButton text={INSTALL_CMD} className="shrink-0 self-end sm:self-auto" />
                </div>
              </div>

              {/* Action buttons */}
              <div className="mt-8 flex justify-center">
                <a
                  href={REPO_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex max-w-full items-center justify-center gap-2.5 rounded-xl border border-cyan/40 bg-gradient-to-r from-emerald/20 to-cyan/20 px-5 sm:px-6 py-3.5 text-xs sm:text-base font-semibold text-ink shadow-[0_0_20px_rgba(56,189,248,0.2)] transition duration-200 hover:-translate-y-0.5 hover:border-emerald/50 hover:from-emerald/30 hover:to-cyan/30 hover:shadow-[0_0_25px_rgba(34,197,94,0.35)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan/60"
                >
                  <svg className="h-5 w-5 shrink-0 fill-current" viewBox="0 0 24 24" aria-hidden="true">
                    <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z" />
                  </svg>
                  <span className="break-words">Explore GitHub Repository</span>
                </a>
              </div>
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
