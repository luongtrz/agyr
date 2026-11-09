import type { ReactNode } from 'react';

export type CommandCategory = 'daily' | 'quota' | 'auto';

export interface CommandItem {
  id: string;
  syntax: string;
  copyText: string;
  categories: CommandCategory[];
  categoryLabel: string;
  description: ReactNode;
}

export const COMMANDS: CommandItem[] = [
  {
    id: 'cmd-list',
    syntax: 'agyr list',
    copyText: 'agyr list',
    categories: ['daily', 'quota'],
    categoryLabel: 'Account Management',
    description: (
      <>
        Inspect real-time quota across all accounts in parallel. Colors indicate percentage health: green (&gt;40%), yellow (11–40%), red (≤10%).
      </>
    ),
  },
  {
    id: 'cmd-list-claude',
    syntax: 'agyr list --claude',
    copyText: 'agyr list --claude',
    categories: ['daily', 'quota'],
    categoryLabel: 'Quota & Utilities',
    description: (
      <>
        Includes Claude 5-hour and Claude weekly limit columns (and GPT if supported) alongside Gemini and Argon quotas.
      </>
    ),
  },
  {
    id: 'cmd-list-c',
    syntax: 'agyr list -c',
    copyText: 'agyr list -c',
    categories: ['daily', 'quota'],
    categoryLabel: 'Quota & Utilities',
    description: (
      <>
        Fast cached quota inspection without calling the{' '}
        <code className="rounded bg-white/5 px-1 py-0.5 font-mono text-xs text-ink/90 border border-white/10">agy</code>{' '}
        binary. Instant results from local state.
      </>
    ),
  },
  {
    id: 'cmd-list-w',
    syntax: 'agyr list -w',
    copyText: 'agyr list -w',
    categories: ['quota'],
    categoryLabel: 'Quota & Utilities',
    description: (
      <>
        Wide format: prevents auto-collapsing optional model columns (Argon, Claude) even on narrow terminal windows.
      </>
    ),
  },
  {
    id: 'cmd-use',
    syntax: 'agyr use <name>',
    copyText: 'agyr use',
    categories: ['daily'],
    categoryLabel: 'Account Management',
    description: (
      <>
        Switch the active interactive account to{' '}
        <code className="rounded bg-white/5 px-1 py-0.5 font-mono text-xs text-ink/90 border border-white/10">&lt;name&gt;</code>.
        Swaps tokens atomically with backup safeguards.
      </>
    ),
  },
  {
    id: 'cmd-save',
    syntax: 'agyr save <name>',
    copyText: 'agyr save',
    categories: ['daily'],
    categoryLabel: 'Account Management',
    description: (
      <>
        Saves the current active interactive login into a named slot in{' '}
        <code className="rounded bg-white/5 px-1 py-0.5 font-mono text-xs text-ink/90 border border-white/10">
          ~/.gemini/antigravity-cli/accounts/
        </code>.
      </>
    ),
  },
  {
    id: 'cmd-swapui',
    syntax: 'agyr swapui <n1> <n2>',
    copyText: 'agyr swapui',
    categories: ['daily', 'quota'],
    categoryLabel: 'Account Management',
    description: (
      <>
        Swaps the UI display row order of two accounts in{' '}
        <code className="rounded bg-white/5 px-1 py-0.5 font-mono text-xs text-ink/90 border border-white/10">agyr list</code>{' '}
        without affecting rotation heuristics. Use{' '}
        <code className="rounded bg-white/5 px-1 py-0.5 font-mono text-xs text-ink/90 border border-white/10">--reset</code>{' '}
        to revert.
      </>
    ),
  },
  {
    id: 'cmd-rotate',
    syntax: 'agyr rotate [cooldown]',
    copyText: 'agyr rotate',
    categories: ['daily', 'auto'],
    categoryLabel: 'Automation & AI',
    description: (
      <>
        When interactive{' '}
        <code className="rounded bg-white/5 px-1 py-0.5 font-mono text-xs text-ink/90 border border-white/10">agy</code>{' '}
        runs out of quota, marks current account in cooldown and switches to next ready account.
      </>
    ),
  },
  {
    id: 'cmd-test',
    syntax: 'agyr test [name...]',
    copyText: 'agyr test',
    categories: ['quota'],
    categoryLabel: 'Quota & Utilities',
    description: (
      <>
        Sends a quick &quot;Hi&quot; probe to accounts to initialize their rolling 5-hour quota windows concurrently.
      </>
    ),
  },
  {
    id: 'cmd-forget',
    syntax: 'agyr forget [-f]',
    copyText: 'agyr forget',
    categories: ['daily'],
    categoryLabel: 'Account Management',
    description: (
      <>
        Drops local active login to sign in to another account. Refuses if unsaved unless{' '}
        <code className="rounded bg-white/5 px-1 py-0.5 font-mono text-xs text-ink/90 border border-white/10">-f</code>{' '}
        is passed.
      </>
    ),
  },
  {
    id: 'cmd-del',
    syntax: 'agyr del <name>',
    copyText: 'agyr del',
    categories: ['daily'],
    categoryLabel: 'Account Management',
    description: (
      <>
        Permanently deletes a saved slot token and associated quota/cooldown state. (Alias:{' '}
        <code className="rounded bg-white/5 px-1 py-0.5 font-mono text-xs text-ink/90 border border-white/10">agyr rm</code>).
      </>
    ),
  },
  {
    id: 'cmd-agy-run',
    syntax: 'agy-run --prompt "..."',
    copyText: 'agy-run',
    categories: ['auto'],
    categoryLabel: 'Automation & AI',
    description: (
      <>
        Runs headless{' '}
        <code className="rounded bg-white/5 px-1 py-0.5 font-mono text-xs text-ink/90 border border-white/10">agy</code>{' '}
        tasks with automated 429 failover. Automatically kills process on 429, switches accounts, and resumes session.
      </>
    ),
  },
  {
    id: 'cmd-agy-task',
    syntax: 'agy-task run --name ...',
    copyText: 'agy-task run',
    categories: ['auto'],
    categoryLabel: 'Automation & AI',
    description: (
      <>
        Orchestrates sub-agent coding tasks inside dedicated git worktrees with strict scope enforcement and compact exit summaries.
      </>
    ),
  },
];
