import Reveal from './Reveal';
import { SUPPORT_URL } from '../lib/site';

/** Low-key, optional support note. Deliberately no popup, no sticky bar, no icon. */
export default function SupportStrip() {
  return (
    <section id="support" className="px-4 pb-4 sm:px-6">
      <Reveal>
        <div className="mx-auto flex max-w-3xl flex-col items-center gap-4 rounded-2xl border border-white/10 bg-card px-6 py-6 text-center sm:flex-row sm:justify-between sm:text-left">
          <p className="text-sm leading-relaxed text-muted">
            <span className="font-semibold text-ink">agyr is free and open source (MIT).</span> No paywall, no
            accounts, no telemetry, and it always will be. If it saves you time, you can optionally support on
            Ko-fi to support development.
          </p>
          <a
            href={SUPPORT_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="shrink-0 rounded-lg border border-amber/40 bg-amber/10 px-4 py-2 text-sm font-semibold text-amber transition hover:bg-amber/20 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-amber"
          >
            Support on Ko-fi
          </a>
        </div>
      </Reveal>
    </section>
  );
}
