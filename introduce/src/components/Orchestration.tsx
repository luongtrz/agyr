import Reveal from './Reveal';
import CodeBlock from './quickstart/CodeBlock';
import { REPO_URL } from '../lib/site';

const ORCHESTRATION_CODE = `# Role split: Orchestrator delegates to agy sub-agent
Role: Main session = Reviewer & Architect
Sub-agent: agy = Dedicated Coder

# Run implementation task in isolated worktree
agy-task run \\
  --name "jwt-auth" \\
  --task .agy-sessions/auth.task.txt \\
  --scope "backend/internal/auth" \\
  --model gemini-3.8-flash-high

# agy-run handles 429 rotation automatically:
# - Switches accounts if quota hits limit
# - Resumes exact same conversation
# - Main session reviews git diff afterwards`;

export default function Orchestration() {
  return (
    <section id="agent-orchestration" className="relative py-20 sm:py-24">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <Reveal>
          <div className="rounded-3xl border border-white/10 bg-gradient-to-br from-[#101726]/95 via-[#0d121f]/95 to-[#141d30]/95 p-6 sm:p-10 lg:p-12 shadow-[0_20px_50px_rgba(0,0,0,0.5)] backdrop-blur-xl">
            <div className="grid grid-cols-1 items-center gap-10 lg:grid-cols-[1.1fr_1fr] lg:gap-12">
              {/* Left Column: Info, Workflow strip, Features, Links */}
              <div className="flex flex-col">
                <span className="inline-flex w-fit items-center gap-1.5 rounded-full border border-emerald/30 bg-emerald/10 px-3 py-1 font-mono text-xs font-semibold uppercase tracking-wider text-emerald">
                  AI Agent Orchestration
                </span>

                <h2 className="mt-3 text-3xl font-bold tracking-tight text-ink sm:text-4xl">
                  Save Costly Claude &amp; Gemini Tokens
                </h2>

                <p className="mt-4 text-base leading-relaxed text-muted sm:text-lg">
                  <strong className="font-semibold text-ink">agyr</strong> includes a battle-tested sub-agent
                  orchestration skill (
                  <code className="rounded bg-white/10 px-1.5 py-0.5 font-mono text-xs text-cyan">
                    skills/agy/
                  </code>
                  ) built for <strong className="font-semibold text-ink">Claude Code</strong>,{' '}
                  <strong className="font-semibold text-ink">Antigravity</strong>, and{' '}
                  <strong className="font-semibold text-ink">Gemini</strong> agents.
                </p>

                {/* Visual Pipeline Diagram (Strip) */}
                <div className="mt-6 mb-8 flex flex-col gap-3 rounded-2xl border border-white/10 bg-terminal/90 p-4 shadow-inner sm:flex-row sm:items-center sm:justify-between sm:gap-2">
                  {/* Step 1: Claude / Gemini */}
                  <div className="flex flex-col gap-1">
                    <div className="inline-flex w-fit items-center gap-1.5 rounded-md border border-violet/35 bg-violet/15 px-2.5 py-1 text-xs font-bold text-violet">
                      <svg
                        className="h-3.5 w-3.5"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        aria-hidden="true"
                      >
                        <circle cx="12" cy="12" r="9" />
                        <circle cx="12" cy="12" r="3" />
                      </svg>
                      <span>Claude / Gemini</span>
                    </div>
                    <span className="text-[11px] font-medium text-dim">Architect &amp; Reviewer</span>
                  </div>

                  {/* Arrow 1 */}
                  <div
                    className="flex shrink-0 items-center justify-center text-dim/60 sm:hidden"
                    aria-hidden="true"
                  >
                    <svg
                      className="h-3.5 w-3.5"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    >
                      <line x1="12" y1="4" x2="12" y2="20" />
                      <polyline points="6 14 12 20 18 14" />
                    </svg>
                  </div>
                  <div
                    className="hidden shrink-0 items-center text-dim/60 sm:flex"
                    aria-hidden="true"
                  >
                    <svg
                      className="h-4 w-4"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    >
                      <line x1="4" y1="12" x2="20" y2="12" />
                      <polyline points="14 6 20 12 14 18" />
                    </svg>
                  </div>

                  {/* Step 2: agy-task */}
                  <div className="flex flex-col gap-1">
                    <div className="inline-flex w-fit items-center gap-1.5 rounded-md border border-cyan/35 bg-cyan/15 px-2.5 py-1 text-xs font-bold text-cyan">
                      <svg
                        className="h-3.5 w-3.5"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        aria-hidden="true"
                      >
                        <polyline points="4 17 10 11 4 5" />
                        <line x1="12" y1="19" x2="20" y2="19" />
                      </svg>
                      <span>agy-task</span>
                    </div>
                    <span className="text-[11px] font-medium text-dim">Dedicated Coder</span>
                  </div>

                  {/* Arrow 2 */}
                  <div
                    className="flex shrink-0 items-center justify-center text-dim/60 sm:hidden"
                    aria-hidden="true"
                  >
                    <svg
                      className="h-3.5 w-3.5"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    >
                      <line x1="12" y1="4" x2="12" y2="20" />
                      <polyline points="6 14 12 20 18 14" />
                    </svg>
                  </div>
                  <div
                    className="hidden shrink-0 items-center text-dim/60 sm:flex"
                    aria-hidden="true"
                  >
                    <svg
                      className="h-4 w-4"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    >
                      <line x1="4" y1="12" x2="20" y2="12" />
                      <polyline points="14 6 20 12 14 18" />
                    </svg>
                  </div>

                  {/* Step 3: agyr auto */}
                  <div className="flex flex-col gap-1">
                    <div className="inline-flex w-fit items-center gap-1.5 rounded-md border border-emerald/35 bg-emerald/15 px-2.5 py-1 text-xs font-bold text-emerald">
                      <svg
                        className="h-3.5 w-3.5"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        aria-hidden="true"
                      >
                        <polyline points="23 4 23 10 17 10" />
                        <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10" />
                      </svg>
                      <span>agyr auto</span>
                    </div>
                    <span className="text-[11px] font-medium text-dim">Zero 429 Blocker</span>
                  </div>
                </div>

                {/* Features */}
                <div className="mb-8 space-y-5">
                  <div className="flex items-start gap-3.5">
                    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border border-emerald/30 bg-emerald/10 text-emerald shadow-sm">
                      <svg
                        className="h-5 w-5"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        aria-hidden="true"
                      >
                        <line x1="6" y1="3" x2="6" y2="15" />
                        <circle cx="18" cy="6" r="3" />
                        <circle cx="6" cy="18" r="3" />
                        <path d="M18 9a9 9 0 0 1-9 9" />
                      </svg>
                    </div>
                    <div>
                      <h4 className="text-base font-semibold text-ink">
                        Isolated Git Worktrees (
                        <code className="rounded bg-white/10 px-1 py-0.5 font-mono text-xs text-emerald">
                          agy-task
                        </code>
                        )
                      </h4>
                      <p className="mt-1 text-sm leading-relaxed text-dim">
                        Every sub-task runs in a clean, dedicated git worktree with strict scope boundary
                        verification.
                      </p>
                    </div>
                  </div>

                  <div className="flex items-start gap-3.5">
                    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border border-cyan/30 bg-cyan/10 text-cyan shadow-sm">
                      <svg
                        className="h-5 w-5"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        aria-hidden="true"
                      >
                        <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
                        <line x1="8" y1="21" x2="16" y2="21" />
                        <line x1="12" y1="17" x2="12" y2="21" />
                      </svg>
                    </div>
                    <div>
                      <h4 className="text-base font-semibold text-ink">
                        Reviewer &amp; Sub-Agent Coder Pattern
                      </h4>
                      <p className="mt-1 text-sm leading-relaxed text-dim">
                        Claude/Gemini acts as the architect and reviewer while local{' '}
                        <code className="rounded bg-white/10 px-1 py-0.5 font-mono text-xs text-cyan">
                          agy
                        </code>{' '}
                        writes code for free, saving thousands of primary tokens.
                      </p>
                    </div>
                  </div>
                </div>

                {/* Primary CTA and secondary doc links */}
                <div className="flex flex-wrap items-center gap-3">
                  <a
                    href={`${REPO_URL}/blob/main/docs/agent-setup.md`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-2 rounded-xl border border-emerald/50 bg-emerald/10 px-5 py-3 text-sm font-semibold text-emerald transition hover:bg-emerald/20 hover:border-emerald hover:shadow-[0_0_20px_rgba(34,197,94,0.2)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald"
                  >
                    <span>Read Orchestrator Setup Guide</span>
                    <svg
                      className="h-3.5 w-3.5"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      aria-hidden="true"
                    >
                      <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" />
                      <polyline points="15 3 21 3 21 9" />
                      <line x1="10" y1="14" x2="21" y2="3" />
                    </svg>
                  </a>

                  <a
                    href={`${REPO_URL}/blob/main/AGENT.MCP.md`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-1.5 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-xs font-medium text-muted transition hover:border-white/25 hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan"
                  >
                    <span>AGENT.MCP.md Protocol</span>
                    <svg
                      className="h-3 w-3 opacity-70"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      aria-hidden="true"
                    >
                      <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" />
                      <polyline points="15 3 21 3 21 9" />
                      <line x1="10" y1="14" x2="21" y2="3" />
                    </svg>
                  </a>

                  <a
                    href={`${REPO_URL}/blob/main/docs/reference.md`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-1.5 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-xs font-medium text-muted transition hover:border-white/25 hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan"
                  >
                    <span>Full Reference</span>
                    <svg
                      className="h-3 w-3 opacity-70"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      aria-hidden="true"
                    >
                      <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" />
                      <polyline points="15 3 21 3 21 9" />
                      <line x1="10" y1="14" x2="21" y2="3" />
                    </svg>
                  </a>
                </div>
              </div>

              {/* Right Column: Code Window Preview */}
              <div className="w-full">
                <CodeBlock
                  code={ORCHESTRATION_CODE}
                  copyText={ORCHESTRATION_CODE}
                  label="CLAUDE.md / GEMINI.md Integration"
                  className="border-white/15 bg-terminal shadow-2xl"
                />
              </div>
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
