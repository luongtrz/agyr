import type { AccountRow, QuotaLevel } from './types';

export const ACCOUNTS_DATA: AccountRow[] = [
  {
    id: 'work-1',
    name: 'work-1',
    isActive: true,
    gemini5h: { percentage: 100, resetTime: '09/11/2026 05:00 PM' },
    geminiWeek: { percentage: 96, resetTime: '16/11/2026 09:30 AM' },
    argonWeek: { percentage: 100, resetTime: '16/11/2026 09:30 AM' },
    claude5h: { percentage: 100, resetTime: '09/11/2026 05:00 PM' },
    claudeWeek: { percentage: 92, resetTime: '16/11/2026 09:30 AM' },
    status: { label: 'ready', type: 'ready' },
  },
  {
    id: 'work-2',
    name: 'work-2',
    isActive: false,
    gemini5h: { percentage: 28, resetTime: '09/11/2026 02:15 PM' },
    geminiWeek: { percentage: 84, resetTime: '15/11/2026 10:00 PM' },
    argonWeek: { percentage: 100, resetTime: '15/11/2026 10:00 PM' },
    claude5h: { percentage: 100, resetTime: '09/11/2026 02:15 PM' },
    claudeWeek: { percentage: 88, resetTime: '15/11/2026 10:00 PM' },
    status: { label: 'ready', type: 'ready' },
  },
  {
    id: 'personal-1',
    name: 'personal-1',
    isActive: false,
    gemini5h: { percentage: 4, resetTime: '09/11/2026 01:45 PM' },
    geminiWeek: { percentage: 12, resetTime: '14/11/2026 06:20 PM' },
    argonWeek: { percentage: 50, resetTime: '14/11/2026 06:20 PM' },
    claude5h: { percentage: 20, resetTime: '09/11/2026 01:45 PM' },
    claudeWeek: { percentage: 35, resetTime: '14/11/2026 06:20 PM' },
    status: { label: 'low', type: 'low' },
  },
  {
    id: 'personal-2',
    name: 'personal-2',
    isActive: false,
    gemini5h: { percentage: 0, resetTime: '09/11/2026 04:30 PM' },
    geminiWeek: { percentage: 75, resetTime: '16/11/2026 11:00 AM' },
    argonWeek: { percentage: null },
    claude5h: { percentage: null },
    claudeWeek: { percentage: null },
    status: { label: 'cooldown, 3h42m left', type: 'cooldown' },
  },
  {
    id: 'backup',
    name: 'backup',
    isActive: false,
    gemini5h: { percentage: 100, resetTime: '09/11/2026 05:00 PM' },
    geminiWeek: { percentage: 100, resetTime: '16/11/2026 12:00 PM' },
    argonWeek: { percentage: 100, resetTime: '16/11/2026 12:00 PM' },
    claude5h: { percentage: 100, resetTime: '09/11/2026 05:00 PM' },
    claudeWeek: { percentage: 100, resetTime: '16/11/2026 12:00 PM' },
    status: { label: 'ready', type: 'ready' },
  },
];

/**
 * Returns quota level: green >= 50, yellow 20-49, red < 20
 */
export function getQuotaLevel(pct: number | null): QuotaLevel {
  if (pct === null) return 'dim';
  if (pct >= 50) return 'green';
  if (pct >= 20) return 'yellow';
  return 'red';
}

export function generateDashboardText(view: 'standard' | 'claude'): string {
  if (view === 'standard') {
    return `user@devbox:~/projects$ agyr list
┌──────────────────┬───────────────────────────┬───────────────────────────┬───────────────────────────┬─────────────────────────────┐
│ ACCOUNT          │ GEMINI 5H                 │ GEMINI WEEK               │ ARGON WEEK                │ STATUS                      │
├──────────────────┼───────────────────────────┼───────────────────────────┼───────────────────────────┼─────────────────────────────┤
│ * work-1         │ 100%  09/11/2026 05:00 PM │  96%  16/11/2026 09:30 AM │ 100%  16/11/2026 09:30 AM │ ready                       │
│   work-2         │  28%  09/11/2026 02:15 PM │  84%  15/11/2026 10:00 PM │ 100%  15/11/2026 10:00 PM │ ready                       │
│   personal-1     │   4%  09/11/2026 01:45 PM │  12%  14/11/2026 06:20 PM │  50%  14/11/2026 06:20 PM │ low                         │
│   personal-2     │   0%  09/11/2026 04:30 PM │  75%  16/11/2026 11:00 AM │   -                       │ cooldown, 3h42m left        │
│   backup         │ 100%  09/11/2026 05:00 PM │ 100%  16/11/2026 12:00 PM │ 100%  16/11/2026 12:00 PM │ ready                       │
└──────────────────┴───────────────────────────┴───────────────────────────┴───────────────────────────┴─────────────────────────────┘
Measured in parallel across 5 accounts in 12s · (* = selected account)`;
  }
  return `user@devbox:~/projects$ agyr list --claude
┌──────────────────┬───────────────────────────┬───────────────────────────┬───────────────────────────┬───────────────────────────┬─────────────────────────────┐
│ ACCOUNT          │ GEMINI 5H                 │ GEMINI WEEK               │ CLAUDE 5H                 │ CLAUDE WEEK               │ STATUS                      │
├──────────────────┼───────────────────────────┼───────────────────────────┼───────────────────────────┼───────────────────────────┼─────────────────────────────┤
│ * work-1         │ 100%  09/11/2026 05:00 PM │  96%  16/11/2026 09:30 AM │ 100%  09/11/2026 05:00 PM │  92%  16/11/2026 09:30 AM │ ready                       │
│   work-2         │  28%  09/11/2026 02:15 PM │  84%  15/11/2026 10:00 PM │ 100%  09/11/2026 02:15 PM │  88%  15/11/2026 10:00 PM │ ready                       │
│   personal-1     │   4%  09/11/2026 01:45 PM │  12%  14/11/2026 06:20 PM │  20%  09/11/2026 01:45 PM │  35%  14/11/2026 06:20 PM │ low                         │
│   personal-2     │   0%  09/11/2026 04:30 PM │  75%  16/11/2026 11:00 AM │   -                       │   -                       │ cooldown, 3h42m left        │
│   backup         │ 100%  09/11/2026 05:00 PM │ 100%  16/11/2026 12:00 PM │ 100%  09/11/2026 05:00 PM │ 100%  16/11/2026 12:00 PM │ ready                       │
└──────────────────┴───────────────────────────┴───────────────────────────┴───────────────────────────┴───────────────────────────┴─────────────────────────────┘
Measured in parallel across 5 accounts in 12s · (* = selected account)`;
}

export const FAILOVER_COMMAND = 'agy-run --add-dir . --prompt "Refactor auth middleware"';

export const FAILOVER_TERMINAL_TEXT = `user@devbox:~/projects/auth-svc$ ${FAILOVER_COMMAND}
[agy-run] running on account 'work-1' (model: gemini-3.8-flash-high)
agy: analyzing codebase and editing middleware.go...
[agy-run] 429 quota reached on 'work-1' (Resets in 4h13m20s) — killing agy immediately
[agy-run] cooldown 'work-1' set to 4h13m20s; switching to 'work-2' (weekly limit resets soonest)
[agy-run] resuming conversation 9c4e1a80-bf82-49da-8b29-9e8c45e69e41 on account 'work-2'
[agy-run] done (account 'work-2') — RESULT=OK
user@devbox:~/projects/auth-svc$ `;
