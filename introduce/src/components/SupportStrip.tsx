import Reveal from './Reveal';
import { SUPPORT_URL, REPO_URL } from '../lib/site';

/** Tasteful community & independent open source support spotlight. */
export default function SupportStrip() {
  return (
    <section id="support" className="px-4 py-8 sm:px-6 lg:px-8">
      <Reveal>
        <div className="relative mx-auto max-w-4xl overflow-hidden rounded-3xl border border-amber/30 bg-gradient-to-br from-[#121a2c] via-[#0d1424] to-[#080d18] p-6 sm:p-8 shadow-[0_12px_40px_rgba(0,0,0,0.6),0_0_30px_rgba(245,158,11,0.08)]">
          {/* Ambient amber glow in the background */}
          <div
            className="pointer-events-none absolute -right-16 -top-16 h-56 w-56 rounded-full bg-amber/15 blur-3xl"
            aria-hidden="true"
          />

          <div className="relative z-10 flex flex-col md:flex-row items-center md:items-start justify-between gap-6 text-center md:text-left">
            <div className="max-w-2xl min-w-0">
              <div className="inline-flex items-center gap-2 rounded-full border border-amber/35 bg-amber/10 px-3 py-1 text-xs font-semibold text-amber">
                <svg className="h-3.5 w-3.5 fill-current" viewBox="0 0 24 24" aria-hidden="true">
                  <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" />
                </svg>
                <span>100% Free &amp; Open Source forever</span>
              </div>

              <h3 className="mt-3.5 text-lg sm:text-xl font-bold text-ink">
                Support Independent Development
              </h3>

              <p className="mt-2 text-sm leading-relaxed text-muted">
                <strong className="text-ink">agyr</strong> has no subscriptions, no paywalls, and no telemetry — it is free forever under the MIT license. If it saves you hours of quota lockouts and powers your autonomous coding workflows, buying a coffee on Ko-fi helps keep continuous updates, tests, and new features coming!
              </p>

              <div className="mt-4 flex flex-wrap items-center justify-center md:justify-start gap-3 sm:gap-4 text-xs text-dim">
                <span className="flex items-center gap-1.5 font-medium text-ink/80">
                  <span className="h-2 w-2 rounded-full bg-emerald"></span>
                  Crafted by Trần Lượng (
                  <a
                    href="https://github.com/luongtrz"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-cyan hover:underline"
                  >
                    @luongtrz
                  </a>
                  )
                </span>
                <span className="text-white/20" aria-hidden="true">•</span>
                <span>MIT Licensed</span>
                <span className="text-white/20" aria-hidden="true">•</span>
                <span>Zero Telemetry</span>
              </div>
            </div>

            <div className="flex shrink-0 flex-col sm:flex-row md:flex-col gap-3 w-full sm:w-auto">
              <a
                href={SUPPORT_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center justify-center gap-2 rounded-xl border border-amber/40 bg-gradient-to-r from-amber/20 to-amber/10 px-5 py-3 text-sm font-semibold text-amber shadow-[0_0_20px_rgba(245,158,11,0.15)] transition-all duration-200 hover:-translate-y-0.5 hover:border-amber/60 hover:bg-amber/25 hover:text-amber-300 hover:shadow-[0_0_25px_rgba(245,158,11,0.3)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber"
              >
                <svg className="h-4 w-4 fill-current text-amber" viewBox="0 0 24 24" aria-hidden="true">
                  <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" />
                </svg>
                <span>Support on Ko-fi</span>
              </a>

              <a
                href={REPO_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center justify-center gap-2 rounded-xl border border-white/10 bg-white/5 px-5 py-2.5 text-xs font-semibold text-ink transition hover:border-white/20 hover:bg-white/10 hover:text-white"
              >
                <svg className="h-3.5 w-3.5 fill-current" viewBox="0 0 24 24" aria-hidden="true">
                  <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z" />
                </svg>
                <span>Star on GitHub</span>
              </a>
            </div>
          </div>
        </div>
      </Reveal>
    </section>
  );
}
