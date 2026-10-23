export function inr(paise: number | null | undefined): string {
  const value = Number(paise ?? 0) / 100;
  return `₹${value.toLocaleString('en-IN', { maximumFractionDigits: 2 })}`;
}

export function dateTime(value: unknown): string {
  if (!value) return '—';
  const raw = value as { toDate?: () => Date; seconds?: number } | string | number;
  const date =
    typeof raw === 'object' && raw !== null && typeof raw.toDate === 'function'
      ? raw.toDate()
      : new Date(raw as string | number);
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
}

export function relTime(value: unknown): string {
  if (!value) return '—';
  const raw = value as { toDate?: () => Date } | string | number;
  const date =
    typeof raw === 'object' && raw !== null && typeof raw.toDate === 'function'
      ? raw.toDate()
      : new Date(raw as string | number);
  if (Number.isNaN(date.getTime())) return '—';
  const diffMs = Date.now() - date.getTime();
  const mins = Math.round(diffMs / 60000);
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.round(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.round(hours / 24);
  if (days < 30) return `${days}d ago`;
  return date.toLocaleDateString('en-IN');
}

export function titleCase(value: string): string {
  return value
    .replace(/[_-]+/g, ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase());
}
