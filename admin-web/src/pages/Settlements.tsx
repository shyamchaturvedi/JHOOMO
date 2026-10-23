import { useState } from 'react';
import { PageHeader, Panel, Loading, ErrorBox, EmptyState, StatusPill } from '../components/ui';
import { call } from '../lib/api';
import { useCallable } from '../lib/useCallable';
import { dateTime, inr } from '../lib/format';

interface SettlementRow {
  id: string;
  eventId: string;
  organizerId: string;
  status: string;
  holdReasons: string[];
  grossPaise: number;
  refundsPaise: number;
  platformFeePaise: number;
  gstOnFeePaise: number;
  promoterCommissionPaise: number;
  netPaise: number;
  bankMasked: string | null;
  utr: string | null;
  scheduledFor: unknown;
  paidAt: unknown;
  approvals: Array<{ by: string }>;
}

export function Settlements() {
  const [status, setStatus] = useState('');
  const { data, loading, error, reload } = useCallable<{ settlements: SettlementRow[] }>(
    () => call('adminListSettlements', status ? { status } : {}),
    [status],
  );
  const [busy, setBusy] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  async function act(settlementId: string, action: 'release' | 'hold' | 'retry', reason?: string) {
    setBusy(settlementId);
    setActionError(null);
    try {
      await call('adminReleaseSettlement', { settlementId, action, reason });
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
        title="Settlements & payout control"
        subtitle="Payouts run T+1 at 11:00 IST. Above the four-eyes threshold, two L3 approvals are required."
        actions={
          <select value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="">All statuses</option>
            {['scheduled', 'processing', 'paid', 'failed', 'on_hold'].map((s) => (
              <option key={s} value={s}>
                {s}
              </option>
            ))}
          </select>
        }
      />
      <ErrorBox message={error ?? actionError} />
      {loading ? <Loading /> : null}
      {data && data.settlements.length === 0 ? <EmptyState message="No settlements in this view." /> : null}

      {data ? (
        <Panel>
          <table className="table">
            <thead>
              <tr>
                <th>Settlement</th>
                <th>Event</th>
                <th>Status</th>
                <th>Net</th>
                <th>Holds</th>
                <th>Approvals</th>
                <th>Scheduled</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {data.settlements.map((row) => (
                <tr key={row.id}>
                  <td className="mono small">
                    {row.id}
                    <div className="muted small">{row.bankMasked ?? '—'}</div>
                  </td>
                  <td className="mono small">{row.eventId}</td>
                  <td>
                    <StatusPill value={row.status} />
                  </td>
                  <td>
                    {inr(row.netPaise)}
                    <div className="muted small">gross {inr(row.grossPaise)}</div>
                  </td>
                  <td className="small">
                    {row.holdReasons.length === 0 ? (
                      <span className="muted">—</span>
                    ) : (
                      row.holdReasons.map((r) => (
                        <span className="pill pill-warn" key={r}>
                          {r}
                        </span>
                      ))
                    )}
                  </td>
                  <td>{row.approvals.length}</td>
                  <td className="small muted">{dateTime(row.scheduledFor)}</td>
                  <td className="actions">
                    <button className="btn" disabled={busy === row.id} onClick={() => act(row.id, 'release')}>
                      Release
                    </button>
                    <button
                      className="btn btn-ghost"
                      disabled={busy === row.id}
                      onClick={() => act(row.id, 'hold', 'Held by admin')}
                    >
                      Hold
                    </button>
                    <button
                      className="btn btn-ghost"
                      disabled={busy === row.id}
                      onClick={() => act(row.id, 'retry')}
                    >
                      Retry
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
