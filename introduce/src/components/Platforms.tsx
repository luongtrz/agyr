import SectionHeading from './SectionHeading';
import Reveal from './Reveal';

export default function Platforms() {
  return (
    <section id="platforms" className="relative py-20 sm:py-24">
      {/* Background ambient glow */}
      <div
        className="pointer-events-none absolute right-0 top-1/4 -z-10 h-72 w-72 rounded-full bg-cyan/10 blur-[100px]"
        aria-hidden="true"
      />

      <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
        <SectionHeading
          eyebrow="Cross-Platform Architecture"
          title="Native Support on Linux & Windows"
          subtitle="Tailored platform layers ensure zero hacks and rock-solid credential isolation."
        />

        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2 lg:gap-8">
          {/* Linux Card */}
          <Reveal delay={0}>
            <div className="h-full rounded-2xl border border-white/10 bg-card p-6 sm:p-8 backdrop-blur-sm transition duration-200 hover:-translate-y-1 hover:border-emerald/40 hover:shadow-[0_18px_40px_rgba(0,0,0,0.45),0_0_25px_rgba(34,197,94,0.08)]">
              {/* Header */}
              <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
                <div className="flex items-center gap-3">
                  <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl border border-emerald/30 bg-emerald/10 text-emerald">
                    {/* Linux Penguin Icon */}
                    <svg
                      className="h-6 w-6"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="#22c55e"
                      strokeWidth="2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      aria-hidden="true"
                    >
                      <path d="M12 2C8 2 7 5 7 8v5c0 2-1 3-2 3v2h14v-2c-1 0-2-1-2-3V8c0-3-1-6-5-6z" />
                      <circle cx="10" cy="8" r="1" fill="#22c55e" />
                      <circle cx="14" cy="8" r="1" fill="#22c55e" />
                      <path d="M10 12c1 1 3 1 4 0" />
                    </svg>
                  </div>
                  <h3 className="text-xl font-bold text-ink">
                    Linux Backend (
                    <code className="font-mono text-sm text-cyan">file</code>)
                  </h3>
                </div>
                <span className="rounded-full border border-emerald/35 bg-emerald/15 px-2.5 py-0.5 text-xs font-semibold text-[#4ade80]">
                  D-Bus Keyring Isolation
                </span>
              </div>

              {/* Features List */}
              <ul className="space-y-4 text-sm leading-relaxed text-muted">
                <li className="flex items-start gap-3">
                  <span className="mt-1 flex h-4 w-4 shrink-0 items-center justify-center rounded-full bg-emerald/15 text-emerald" aria-hidden="true">
                    <svg className="h-3 w-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                      <polyline points="20 6 9 17 4 12" />
                    </svg>
                  </span>
                  <div>
                    <strong className="block font-semibold text-ink">D-Bus Session Bus Bypass:</strong>
                    Disables GNOME Keyring fallback with{' '}
                    <code className="rounded border border-white/10 bg-white/5 px-1 py-0.5 font-mono text-xs text-ink/90">
                      DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent
                    </code>{' '}
                    so{' '}
                    <code className="rounded border border-white/10 bg-white/5 px-1 py-0.5 font-mono text-xs text-ink/90">
                      agy
                    </code>{' '}
                    reads swapped tokens cleanly.
                  </div>
                </li>

                <li className="flex items-start gap-3">
                  <span className="mt-1 flex h-4 w-4 shrink-0 items-center justify-center rounded-full bg-emerald/15 text-emerald" aria-hidden="true">
                    <svg className="h-3 w-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                      <polyline points="20 6 9 17 4 12" />
                    </svg>
                  </span>
                  <div>
                    <strong className="block font-semibold text-ink">Parallel Quota Measurement:</strong>
                    Spawns parallel probe environments in temporary home dirs via{' '}
                    <code className="rounded border border-white/10 bg-white/5 px-1 py-0.5 font-mono text-xs text-ink/90">
                      setsid
                    </code>{' '}
                    without modifying live session tokens.
                  </div>
                </li>

                <li className="flex items-start gap-3">
                  <span className="mt-1 flex h-4 w-4 shrink-0 items-center justify-center rounded-full bg-emerald/15 text-emerald" aria-hidden="true">
                    <svg className="h-3 w-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                      <polyline points="20 6 9 17 4 12" />
                    </svg>
                  </span>
                  <div>
                    <strong className="block font-semibold text-ink">Process Group Termination:</strong>
                    Cleanly kills orphaned sub-agent processes and task groups without zombie leaves.
                  </div>
                </li>
              </ul>
            </div>
          </Reveal>

          {/* Windows Card */}
          <Reveal delay={120}>
            <div className="h-full rounded-2xl border border-white/10 bg-card p-6 sm:p-8 backdrop-blur-sm transition duration-200 hover:-translate-y-1 hover:border-cyan/40 hover:shadow-[0_18px_40px_rgba(0,0,0,0.45),0_0_25px_rgba(56,189,248,0.08)]">
              {/* Header */}
              <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
                <div className="flex items-center gap-3">
                  <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl border border-cyan/30 bg-cyan/10 text-cyan">
                    {/* Windows Icon */}
                    <svg
                      className="h-6 w-6"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="#38bdf8"
                      strokeWidth="2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      aria-hidden="true"
                    >
                      <rect x="3" y="3" width="8" height="8" rx="1" />
                      <rect x="13" y="3" width="8" height="8" rx="1" />
                      <rect x="3" y="13" width="8" height="8" rx="1" />
                      <rect x="13" y="13" width="8" height="8" rx="1" />
                    </svg>
                  </div>
                  <h3 className="text-xl font-bold text-ink">
                    Windows Backend (
                    <code className="font-mono text-sm text-cyan">wincred</code>)
                  </h3>
                </div>
                <span className="rounded-full border border-cyan/35 bg-cyan/15 px-2.5 py-0.5 text-xs font-semibold text-cyan">
                  Native WinCred & DPAPI
                </span>
              </div>

              {/* Features List */}
              <ul className="space-y-4 text-sm leading-relaxed text-muted">
                <li className="flex items-start gap-3">
                  <span className="mt-1 flex h-4 w-4 shrink-0 items-center justify-center rounded-full bg-cyan/15 text-cyan" aria-hidden="true">
                    <svg className="h-3 w-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                      <polyline points="20 6 9 17 4 12" />
                    </svg>
                  </span>
                  <div>
                    <strong className="block font-semibold text-ink">Windows Credential Manager:</strong>
                    Directly swaps credentials in{' '}
                    <code className="rounded border border-white/10 bg-white/5 px-1 py-0.5 font-mono text-xs text-ink/90">
                      gemini:antigravity
                    </code>{' '}
                    using native PowerShell API wrappers.
                  </div>
                </li>

                <li className="flex items-start gap-3">
                  <span className="mt-1 flex h-4 w-4 shrink-0 items-center justify-center rounded-full bg-cyan/15 text-cyan" aria-hidden="true">
                    <svg className="h-3 w-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                      <polyline points="20 6 9 17 4 12" />
                    </svg>
                  </span>
                  <div>
                    <strong className="block font-semibold text-ink">All Shells Supported:</strong>
                    Generates both Git Bash scripts and native Windows{' '}
                    <code className="rounded border border-white/10 bg-white/5 px-1 py-0.5 font-mono text-xs text-ink/90">
                      .cmd
                    </code>{' '}
                    wrappers for PowerShell and Command Prompt (CMD).
                  </div>
                </li>

                <li className="flex items-start gap-3">
                  <span className="mt-1 flex h-4 w-4 shrink-0 items-center justify-center rounded-full bg-cyan/15 text-cyan" aria-hidden="true">
                    <svg className="h-3 w-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                      <polyline points="20 6 9 17 4 12" />
                    </svg>
                  </span>
                  <div>
                    <strong className="block font-semibold text-ink">Argument Conversion Guard:</strong>
                    Bypasses MSYS path rewrites via{' '}
                    <code className="rounded border border-white/10 bg-white/5 px-1 py-0.5 font-mono text-xs text-ink/90">
                      MSYS2_ARG_CONV_EXCL
                    </code>{' '}
                    and terminates Windows process trees via{' '}
                    <code className="rounded border border-white/10 bg-white/5 px-1 py-0.5 font-mono text-xs text-ink/90">
                      taskkill //T //F
                    </code>
                    .
                  </div>
                </li>
              </ul>
            </div>
          </Reveal>
        </div>
      </div>
    </section>
  );
}
