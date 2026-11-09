export type QuotaLevel = 'green' | 'yellow' | 'red' | 'dim';

export interface QuotaEntry {
  percentage: number | null; // null represents '-'
  resetTime?: string;
}

export type AccountStatusType = 'ready' | 'low' | 'cooldown';

export interface AccountStatus {
  label: string;
  type: AccountStatusType;
}

export interface AccountRow {
  id: string;
  name: string;
  isActive: boolean;
  gemini5h: QuotaEntry;
  geminiWeek: QuotaEntry;
  argonWeek: QuotaEntry;
  claude5h: QuotaEntry;
  claudeWeek: QuotaEntry;
  status: AccountStatus;
}

export type ShowcaseTab = 'list' | 'rotate';
export type DashboardViewMode = 'standard' | 'claude';
