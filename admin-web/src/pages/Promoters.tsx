import { useState } from 'react';
import { PageHeader, Panel, Loading, ErrorBox, EmptyState, StatusPill } from '../components/ui';
import { call } from '../lib/api';
import { useCallable } from '../lib/useCallable';
import { inr, relTime } from '../lib/format';

interface PromoterRow {
  uid: string;
  code: string | null;
  displayName: string | null;
  status: string;
  panMasked: string | null;
  commissionCapPct: number | null;
  pendingPaise: number;
  approvedPaise: number;
  paidPaise: number;
  createdAt: unknown;
}

export function Promoters() {
  const { data, loading, error, reload } = useCallable<{ promoters: PromoterRow[] }>(
    () => call('adminListPromoters', {}),
    [],
  );
  const [busy, setBusy] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  async function act(uid: string, action: 'approve' | 'suspend', reason?: string) {
    setBusy(uid);
    setActionError(null);
    try {
      await call('adminPromoterAction', { promoterUid: uid, action, reason });
      reload();
    } catch (err) {
      setActionError((err as Error).message);
    } finally {
      setBusy(null);
    }
  }

  return (
    <>
      <PageHeader title="Promoters & commissions" subtitle="Self-referral attempts are flagged automatically." />
      <ErrorBox message={error ?? actionError} />
      {loading ? <Loading /> : null}
      {data && data.promoters.length === 0 ? <EmptyState message="No promoters yet." /> : null}

      {data ? (
        <Panel>
          <table className="table">
            <thead>
              <tr>
                <th>Promoter</th>
                <th>Code</th>
                <th>Status</th>
                <th>PAN</th>
                <th>Pending</th>
                <th>Approved</th>
                <th>Paid</th>
                <th>Joined</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {data.promoters.map((row) => (
                <tr key={row.uid}>
                  <td>
                    <strong>{row.displayName ?? row.uid}</strong>
                    <div className="muted small mono">{row.uid}</div>
                  </td>
                  <td className="mono">{row.code ?? '—'}</td>
                  <td>
                    <StatusPill value={row.status} />
                  </td>
                  <td className="mono small">{row.panMasked ?? '—'}</td>
                  <td>{inr(row.pendingPaise)}</td>
                  <td>{inr(row.approvedPaise)}</td>
                  <td>{inr(row.paidPaise)}</td>
                  <td className="muted small">{relTime(row.createdAt)}</td>
                  <td className="actions">
                    <button className="btn" disabled={busy === row.uid} onClick={() => act(row.uid, 'approve')}>
                      Approve
                    </button>
                    <button
                      className="btn btn-ghost"
                      disabled={busy === row.uid}
                      onClick={() => act(row.uid, 'suspend', 'Suspended by admin')}
                    >
                      Suspend
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
