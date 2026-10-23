import { useState } from 'react';
import { PageHeader, Panel, Loading, ErrorBox, EmptyState, StatusPill } from '../components/ui';
import { call } from '../lib/api';
import { useCallable } from '../lib/useCallable';
import { inr, relTime } from '../lib/format';

interface RefundRow {
  id: string;
  bookingId: string | null;
  eventId: string | null;
  userId: string | null;
  status: string;
  amountPaise: number;
  feePaise: number;
  reason: string | null;
  createdAt: unknown;
}

export function Refunds() {
  const [status, setStatus] = useState('');
  const { data, loading, error, reload } = useCallable<{ refunds: RefundRow[] }>(
    () => call('adminListRefunds', status ? { status } : {}),
    [status],
  );
  const [busy, setBusy] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  async function decide(refundId: string, decision: 'approve' | 'deny' | 'escalate', reason?: string) {
    setBusy(refundId);
    setActionError(null);
    try {
      await call('adminDecideRefund', { refundId, decision, reason });
      reload();
    } catch (err) {
      setActionError((err as Error).message);
    } finally {
      setBusy(null);
    }
  }

  return (
    <>
      <PageHeader
        title="Refunds & disputes"
        subtitle="Goodwill refunds up to ₹5,000 are L1; anything above escalates to L3."
        actions={
          <select value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="">All statuses</option>
            {['requested', 'needs_review', 'approved', 'processing', 'processed', 'denied', 'failed'].map((s) => (
              <option key={s} value={s}>
                {s}
              </option>
            ))}
          </select>
        }
      />
      <ErrorBox message={error ?? actionError} />
      {loading ? <Loading /> : null}
      {data && data.refunds.length === 0 ? <EmptyState message="No refunds in this view." /> : null}

      {data ? (
        <Panel>
          <table className="table">
            <thead>
              <tr>
                <th>Refund</th>
                <th>Booking</th>
                <th>Amount</th>
                <th>Fees</th>
                <th>Status</th>
                <th>Reason</th>
                <th>Age</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {data.refunds.map((row) => (
                <tr key={row.id}>
                  <td className="mono small">{row.id}</td>
                  <td className="mono small">{row.bookingId ?? '—'}</td>
                  <td>{inr(row.amountPaise)}</td>
                  <td>{inr(row.feePaise)}</td>
                  <td>
                    <StatusPill value={row.status} />
                  </td>
                  <td className="small muted">{row.reason ?? '—'}</td>
                  <td className="muted small">{relTime(row.createdAt)}</td>
                  <td className="actions">
                    <button className="btn" disabled={busy === row.id} onClick={() => decide(row.id, 'approve')}>
                      Approve
                    </button>
                    <button
                      className="btn btn-ghost"
                      disabled={busy === row.id}
                      onClick={() => decide(row.id, 'escalate', 'Escalated for L3 review')}
                    >
                      Escalate
                    </button>
                    <button
                      className="btn btn-ghost"
                      disabled={busy === row.id}
                      onClick={() => decide(row.id, 'deny', 'Outside refund policy')}
                    >
                      Deny
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </Panel>
      ) : null}
    </>
  );
}
