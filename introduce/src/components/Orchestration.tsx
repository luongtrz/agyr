import type { ReactNode } from 'react';
import Reveal from './Reveal';
import CopyButton from './CopyButton';
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

/**
 * Highlights shell commands, comments, flags, strings, roles, and paths.
 */
function highlightCodeLine(line: string, lineIndex: number): ReactNode {
  const trimmed = line.trimStart();

  if (trimmed.startsWith('#')) {
    return (
      <span key={lineIndex} className="text-dim italic">
        {line}
      </span>
    );
  }

  const tokenRegex =
    /(#[^\n]*)|("[^"]*"|'[^']*')|(--?[a-zA-Z0-9-]+)|(\b(?:agyr|agy-run|agy-task|agy|curl)\b)|(\b(?:Role|Sub-agent):)|((?:\.[a-zA-Z0-9_./-]+\.(?:txt|md|sh|ts|js))\b)|(\bgemini-[a-zA-Z0-9.-]+\b)/g;

  const elements: ReactNode[] = [];
  let lastIndex = 0;
  let match: RegExpExecArray | null;

  while ((match = tokenRegex.exec(line)) !== null) {
    if (match.index > lastIndex) {
      elements.push(line.slice(lastIndex, match.index));
    }

    const [, comment, str, flag, cmd, role, filePath, modelName] = match;

    if (comment) {
      elements.push(
        <span key={match.index} className="text-dim italic">
          {comment}
        </span>,
      );
    } else if (str) {
      elements.push(
        <span key={match.index} className="text-emerald">
          {str}
        </span>,
      );
    } else if (flag) {
      elements.push(
        <span key={match.index} className="text-amber">
          {flag}
        </span>,
      );
    } else if (cmd) {
      elements.push(
        <span key={match.index} className="font-semibold text-cyan">
          {cmd}
        </span>,
      );
    } else if (role) {
      elements.push(
        <span key={match.index} className="font-semibold text-violet">
          {role}
        </span>,
      );
    } else if (filePath) {
      elements.push(
        <span key={match.index} className="text-amber">
          {filePath}
        </span>,
      );
    } else if (modelName) {
      elements.push(
        <span key={match.index} className="text-emerald">
          {modelName}
        </span>,
      );
    }

    lastIndex = tokenRegex.lastIndex;
  }

  if (lastIndex < line.length) {
    elements.push(line.slice(lastIndex));
  }

  return <span key={lineIndex}>{elements}</span>;
}

export default function Orchestration() {
  return (
    <section id="agent-orchestration" className="relative py-16 sm:py-24">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <Reveal>
          <div className="rounded-3xl border border-white/10 bg-gradient-to-br from-[#101726]/95 via-[#0d121f]/95 to-[#141d30]/95 p-4 sm:p-10 lg:p-12 shadow-[0_20px_50px_rgba(0,0,0,0.5)] backdrop-blur-xl">
            <div className="grid grid-cols-1 items-center gap-10 lg:grid-cols-[1.1fr_1fr] lg:gap-12">
              {/* Left Column: Info, Workflow strip, Features, Links */}
              <div className="flex min-w-0 flex-col">
                <span className="inline-flex w-fit items-center gap-1.5 rounded-full border border-emerald/30 bg-emerald/10 px-3 py-1 font-mono text-xs font-semibold uppercase tracking-wider text-emerald">
                  AI Agent Orchestration
                </span>

                <h2 className="mt-3 text-2xl font-bold tracking-tight text-ink sm:text-4xl break-words">
                  Save Costly Claude &amp; Gemini Tokens
                </h2>

                <p className="mt-4 text-sm leading-relaxed text-muted sm:text-lg break-words">
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
                <div className="mt-6 mb-8 flex flex-col gap-3 rounded-2xl border border-white/10 bg-terminal/90 p-3.5 sm:p-4 shadow-inner sm:flex-row sm:flex-wrap sm:items-center sm:justify-between sm:gap-2">
                  {/* Step 1: Claude / Gemini */}
                  <div className="flex min-w-0 flex-col gap-1">
                    <div className="inline-flex max-w-full flex-wrap items-center gap-1.5 rounded-md border border-violet/35 bg-violet/15 px-2.5 py-1 text-xs font-bold text-violet">
                      <svg
                        className="h-3.5 w-3.5 shrink-0"
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
                      <span className="break-words">Claude / Gemini</span>
                    </div>
                    <span className="text-[11px] font-medium text-dim break-words">Architect &amp; Reviewer</span>
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
                  <div className="flex min-w-0 flex-col gap-1">
                    <div className="inline-flex max-w-full flex-wrap items-center gap-1.5 rounded-md border border-cyan/35 bg-cyan/15 px-2.5 py-1 text-xs font-bold text-cyan">
                      <svg
                        className="h-3.5 w-3.5 shrink-0"
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
                      <span className="break-words">agy-task</span>
                    </div>
                    <span className="text-[11px] font-medium text-dim break-words">Dedicated Coder</span>
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
                  <div className="flex min-w-0 flex-col gap-1">
                    <div className="inline-flex max-w-full flex-wrap items-center gap-1.5 rounded-md border border-emerald/35 bg-emerald/15 px-2.5 py-1 text-xs font-bold text-emerald">
                      <svg
                        className="h-3.5 w-3.5 shrink-0"
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
                      <span className="break-words">agyr auto</span>
                    </div>
                    <span className="text-[11px] font-medium text-dim break-words">Zero 429 Blocker</span>
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
                    <div className="min-w-0">
                      <h4 className="text-base font-semibold text-ink break-words">
                        Isolated Git Worktrees (
                        <code className="rounded bg-white/10 px-1 py-0.5 font-mono text-xs text-emerald">
                          agy-task
                        </code>
                        )
                      </h4>
                      <p className="mt-1 text-sm leading-relaxed text-dim break-words">
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
                    <div className="min-w-0">
                      <h4 className="text-base font-semibold text-ink break-words">
                        Reviewer &amp; Sub-Agent Coder Pattern
                      </h4>
                      <p className="mt-1 text-sm leading-relaxed text-dim break-words">
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
                <div className="flex flex-wrap items-center gap-2.5 sm:gap-3">
                  <a
                    href={`${REPO_URL}/blob/main/docs/agent-setup.md`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex max-w-full items-center gap-2 rounded-xl border border-emerald/50 bg-emerald/10 px-4 sm:px-5 py-2.5 sm:py-3 text-xs sm:text-sm font-semibold text-emerald transition hover:bg-emerald/20 hover:border-emerald hover:shadow-[0_0_20px_rgba(34,197,94,0.2)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald"
                  >
                    <span className="break-words">Read Orchestrator Setup Guide</span>
                    <svg
                      className="h-3.5 w-3.5 shrink-0"
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
                    className="inline-flex max-w-full items-center gap-1.5 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-xs font-medium text-muted transition hover:border-white/25 hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan"
                  >
                    <span className="break-words">AGENT.MCP.md Protocol</span>
                    <svg
                      className="h-3 w-3 shrink-0 opacity-70"
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
                    className="inline-flex max-w-full items-center gap-1.5 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-xs font-medium text-muted transition hover:border-white/25 hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan"
                  >
                    <span className="break-words">Full Reference</span>
                    <svg
                      className="h-3 w-3 shrink-0 opacity-70"
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
              <div className="w-full min-w-0">
                <div className="relative flex flex-col rounded-xl border border-white/15 bg-terminal shadow-2xl overflow-hidden">
                  {/* Top action bar / reserved gutter */}
                  <div className="flex items-center justify-between border-b border-white/5 bg-terminal-header/80 px-3.5 py-1.5 select-none">
                    <div className="flex items-center gap-1.5 min-w-0">
                      <span className="h-2.5 w-2.5 shrink-0 rounded-full bg-danger/80" aria-hidden="true" />
                      <span className="h-2.5 w-2.5 shrink-0 rounded-full bg-amber/80" aria-hidden="true" />
                      <span className="h-2.5 w-2.5 shrink-0 rounded-full bg-emerald/80" aria-hidden="true" />
                      <span className="ml-2 truncate font-mono text-[11px] font-medium uppercase tracking-wider text-dim">
                        CLAUDE.md / GEMINI.md Integration
                      </span>
                    </div>
                    <CopyButton text={ORCHESTRATION_CODE} className="shrink-0 text-xs" />
                  </div>

                  {/* Code body: wrapped cleanly, no horizontal scroll */}
                  <div className="p-3.5 min-w-0">
                    <pre className="font-mono text-xs leading-relaxed text-ink/90 whitespace-pre-wrap break-words">
                      <code>
                        {ORCHESTRATION_CODE.split('\n').map((line, idx) => (
                          <div key={idx} className="min-h-[1.25rem] break-words">
                            {highlightCodeLine(line, idx)}
                          </div>
                        ))}
                      </code>
                    </pre>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
