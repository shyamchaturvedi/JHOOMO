import type { ReactNode } from 'react';
import { titleCase } from '../lib/format';

export function StatusPill({ value }: { value: string | undefined | null }) {
  const v = (value ?? 'unknown').toLowerCase();
  const tone = (() => {
    if (['live', 'approved', 'active', 'accepted', 'processed', 'paid', 'joined', 'confirmed', 'resolved'].includes(v)) return 'ok';
    if (['pending', 'pending_review', 'submitted', 'on_hold', 'requested', 'auto_verified', 'in_review'].includes(v)) return 'warn';
    if (['rejected', 'failed', 'denied', 'banned', 'suspended', 'expired', 'cancelled', 'closed', 'revoked', 'void'].includes(v)) return 'bad';
    return 'muted';
  })();
  return <span className={`pill pill-${tone}`}>{titleCase(v)}</span>;
}

export function PageHeader({
  title,
  subtitle,
  actions,
}: {
  title: string;
  subtitle?: string;
  actions?: ReactNode;
}) {
  return (
    <header className="page-header">
      <div>
        <h1>{title}</h1>
        {subtitle ? <p className="muted">{subtitle}</p> : null}
      </div>
      <div className="page-actions">{actions}</div>
    </header>
  );
}

export function Panel({ children, className }: { children: ReactNode; className?: string }) {
  return <section className={`panel ${className ?? ''}`}>{children}</section>;
}

export function Loading() {
  return <div className="loading">Loading…</div>;
}

export function ErrorBox({ message }: { message: string | null }) {
  if (!message) return null;
  return <div className="error-box">{message}</div>;
}

export function EmptyState({ message }: { message: string }) {
  return <div className="empty">{message}</div>;
}
