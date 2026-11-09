import { REPO_URL, SUPPORT_URL } from '../lib/site';

export default function Footer() {
  return (
    <footer className="relative border-t border-white/10 bg-[#05070c] pt-16 pb-12">
      {/* Top gradient accent line */}
      <div
        className="pointer-events-none absolute left-0 right-0 top-0 h-[2px] shadow-[0_0_16px_rgba(56,189,248,0.35)]"
        style={{
          background:
            'linear-gradient(90deg, transparent 0%, rgba(34, 197, 94, 0.45) 20%, rgba(56, 189, 248, 0.75) 50%, rgba(168, 85, 247, 0.45) 80%, transparent 100%)',
        }}
        aria-hidden="true"
      />

      <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 gap-10 lg:grid-cols-12 lg:gap-12">
          {/* Brand info */}
          <div className="lg:col-span-5 flex min-w-0 flex-col gap-4">
            <a href="#top" className="inline-flex items-center gap-2 text-ink transition hover:opacity-80">
              <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg border border-cyan/30 bg-cyan/10 text-cyan">
                <svg
                  className="h-5 w-5"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2.2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  aria-hidden="true"
                >
                  <polyline points="4 17 10 11 4 5" />
                  <line x1="12" y1="19" x2="20" y2="19" />
                  <path d="M19 5a7 7 0 0 1 0 10" stroke="#38bdf8" />
                </svg>
              </span>
              <span className="text-xl font-bold tracking-tight text-ink">agyr</span>
            </a>

            <p className="max-w-sm text-sm leading-relaxed text-dim break-words">
              Zero-ban Google account auto-rotation and live quota monitor for Antigravity CLI (
              <code className="rounded border border-white/10 bg-white/5 px-1 py-0.5 font-mono text-xs text-ink/80">
                agy
              </code>
              ). Pure Bash, 100% local, zero proxy overhead.
            </p>
          </div>

          {/* Links groups */}
          <div className="grid grid-cols-1 gap-8 sm:grid-cols-3 lg:col-span-7 min-w-0">
            {/* Project Links */}
            <div className="flex min-w-0 flex-col gap-3">
              <h4 className="text-xs font-bold uppercase tracking-wider text-ink">Project</h4>
              <ul className="space-y-2 text-sm text-dim">
                <li>
                  <a
                    href={REPO_URL}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="break-words transition hover:text-emerald"
                  >
                    GitHub Repository
                  </a>
                </li>
                <li>
                  <a
                    href={`${REPO_URL}/releases`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="break-words transition hover:text-emerald"
                  >
                    Releases &amp; Changelog
                  </a>
                </li>
                <li>
                  <a
                    href={`${REPO_URL}/issues`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="break-words transition hover:text-emerald"
                  >
                    Report an Issue
                  </a>
                </li>
                <li>
                  <a
                    href={`${REPO_URL}/blob/main/LICENSE`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="break-words transition hover:text-emerald"
                  >
                    MIT License
                  </a>
                </li>
              </ul>
            </div>

            {/* Documentation Links */}
            <div className="flex min-w-0 flex-col gap-3">
              <h4 className="text-xs font-bold uppercase tracking-wider text-ink">Documentation</h4>
              <ul className="space-y-2 text-sm text-dim">
                <li>
                  <a
                    href={`${REPO_URL}/blob/main/README.md`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="break-words transition hover:text-emerald"
                  >
                    README Quickstart
                  </a>
                </li>
                <li>
                  <a
                    href={`${REPO_URL}/blob/main/docs/reference.md`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="break-words transition hover:text-emerald"
                  >
                    Full Technical Reference
                  </a>
                </li>
                <li>
                  <a
                    href={`${REPO_URL}/blob/main/docs/agent-setup.md`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="break-words transition hover:text-emerald"
                  >
                    AI Agent Orchestrator Setup
                  </a>
                </li>
                <li>
                  <a
                    href={`${REPO_URL}/blob/main/AGENT.MCP.md`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="break-words transition hover:text-emerald"
                  >
                    AGENT.MCP.md Protocol
                  </a>
                </li>
              </ul>
            </div>

            {/* Community Links */}
            <div className="flex min-w-0 flex-col gap-3">
              <h4 className="text-xs font-bold uppercase tracking-wider text-ink">Community</h4>
              <ul className="space-y-2 text-sm text-dim">
                <li>
                  <a
                    href={`${REPO_URL}/stargazers`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="break-words transition hover:text-emerald"
                  >
                    Star on GitHub
                  </a>
                </li>
                <li>
                  <a
                    href={`${REPO_URL}/forks`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="break-words transition hover:text-emerald"
                  >
                    Fork Repository
                  </a>
                </li>
                <li>
                  <a
                    href="https://github.com/luongtrz"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="break-words transition hover:text-emerald"
                  >
                    Author Profile (@luongtrz)
                  </a>
                </li>
                <li>
                  <a
                    href={SUPPORT_URL}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-1.5 break-words font-medium text-amber transition hover:text-amber-300"
                  >
                    <svg className="h-3.5 w-3.5 fill-current text-amber" viewBox="0 0 24 24" aria-hidden="true">
                      <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" />
                    </svg>
                    <span>Support on Ko-fi</span>
                  </a>
                </li>
              </ul>
            </div>
          </div>
        </div>

        {/* Footer Bottom */}
        <div className="mt-12 flex flex-col items-center justify-between gap-4 border-t border-white/10 pt-8 text-xs text-dim sm:flex-row sm:flex-wrap">
          <p className="break-words text-center sm:text-left">© 2026 Trần Lượng. Released under the MIT License.</p>
          <p className="text-center sm:text-right break-words">
            Antigravity CLI (
            <code className="rounded border border-white/10 bg-white/5 px-1 py-0.5 font-mono text-[11px] text-ink/80">
              agy
            </code>
            ) and Gemini are trademarks of Google LLC.{' '}
            <code className="rounded border border-white/10 bg-white/5 px-1 py-0.5 font-mono text-[11px] text-ink/80">
              agyr
            </code>{' '}
            is an independent open-source tool.
          </p>
        </div>
      </div>
    </footer>
  );
}
