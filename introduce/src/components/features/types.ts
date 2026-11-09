import type { ReactNode } from 'react';

export type AccentColor = 'emerald' | 'cyan' | 'violet';

export interface UspItem {
  id: string;
  badge: {
    label: string;
    icon: ReactNode;
  };
  icon: ReactNode;
  title: string;
  description: ReactNode;
  points: ReactNode[];
  watermark: ReactNode;
  accentColor: AccentColor;
}

export type BadgeVariant = 'green' | 'red' | 'amber' | 'dim';

export interface ComparisonCell {
  badgeVariant: BadgeVariant;
  badgeText: string;
  description: ReactNode;
}

export interface ComparisonRow {
  id: string;
  title: string;
  subtitle: string;
  agyr: ComparisonCell;
  proxy: ComparisonCell;
}
