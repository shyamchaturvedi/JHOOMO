import { useState } from 'react';
import { PageHeader, Panel, Loading, ErrorBox, EmptyState, StatusPill } from '../components/ui';
import { call } from '../lib/api';
import { useCallable } from '../lib/useCallable';
import { relTime } from '../lib/format';

interface OrganizerRow {
  uid: string;
  displayName: string | null;
  email: string | null;
  kycStatus: string;
  legalName: string | null;
  panMasked: string | null;
  bankName: string | null;
  ifsc: string | null;
  nameMatchScore: number | null;
  trusted: boolean;
  completedEvents: number;
  updatedAt: unknown;
}

export function KycQueue() {
  const [status, setStatus] = useState<string>('');
  const { data, loading, error, reload } = useCallable<{ organizers: OrganizerRow[] }>(
    () => call('adminListKycQueue', status ? { status } : {}),
    [status],
  );
  const [busy, setBusy] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  async function decide(uid: string, decision: 'approve' | 'request_info' | 'reject' | 'suspend', reason?: string) {
    setBusy(uid);
    setActionError(null);
    try {
      await call('adminReviewKyc', {
        organizerUid: uid,
        decision,
        fields: decision === 'request_info' ? ['pan', 'bank'] : [],
        reason,
      });
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
        title="KYC review queue"
        subtitle="PAN and bank details are encrypted at rest; revealing them is audit logged."
        actions={
          <select value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="">All statuses</option>
            {['submitted', 'auto_verified', 'needs_info', 'approved', 'rejected', 'suspended'].map((s) => (
              <option key={s} value={s}>
                {s}
              </option>
            ))}
          </select>
        }
      />
      <ErrorBox message={error ?? actionError} />
      {loading ? <Loading /> : null}
      {data && data.organizers.length === 0 ? <EmptyState message="No organizers in this queue." /> : null}

      {data ? (
        <Panel>
          <table className="table">
            <thead>
              <tr>
                <th>Organizer</th>
                <th>Status</th>
                <th>PAN</th>
                <th>Bank</th>
                <th>Name match</th>
                <th>Updated</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {data.organizers.map((row) => (
                <tr key={row.uid}>
                  <td>
                    <strong>{row.displayName ?? row.uid}</strong>
                    <div className="muted small">{row.email ?? row.uid}</div>
                  </td>
                  <td>
                    <StatusPill value={row.kycStatus} />
                  </td>
                  <td className="mono">{row.panMasked ?? '—'}</td>
                  <td>
                    {row.bankName ?? '—'}
                    <div className="muted small mono">{row.ifsc ?? ''}</div>
                  </td>
                  <td>{row.nameMatchScore ?? '—'}</td>
                  <td className="muted small">{relTime(row.updatedAt)}</td>
                  <td className="actions">
                    <button className="btn" disabled={busy === row.uid} onClick={() => decide(row.uid, 'approve')}>
                      Approve
                    </button>
                    <button
                      className="btn btn-ghost"
                      disabled={busy === row.uid}
                      onClick={() => decide(row.uid, 'request_info', 'Please re-upload PAN and bank proof')}
                    >
                      Request info
                    </button>
                    <button
                      className="btn btn-ghost"
                      disabled={busy === row.uid}
                      onClick={() => decide(row.uid, 'reject', 'Verification failed')}
                    >
                      Reject
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
