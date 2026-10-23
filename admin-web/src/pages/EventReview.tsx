import { useState } from 'react';
import { PageHeader, Panel, Loading, ErrorBox, EmptyState, StatusPill } from '../components/ui';
import { call } from '../lib/api';
import { useCallable } from '../lib/useCallable';
import { dateTime, inr, relTime } from '../lib/format';

interface EventRow {
  id: string;
  title: string;
  cityId: string | null;
  categoryId: string | null;
  status: string;
  organizerId: string;
  organizerName: string | null;
  startAt: unknown;
  capacityTotal: number;
  minPricePaise: number;
  ageLimit: number;
  reportCount: number;
  updatedAt: unknown;
}

export function EventReview() {
  const [status, setStatus] = useState('pending_review');
  const { data, loading, error, reload } = useCallable<{ events: EventRow[] }>(
    () => call('adminListEventQueue', status ? { status } : {}),
    [status],
  );
  const [busy, setBusy] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  async function decide(eventId: string, decision: string, reason?: string) {
    setBusy(eventId);
    setActionError(null);
    try {
      await call('adminReviewEvent', { eventId, decision, reason });
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
        title="Event review & moderation"
        subtitle="Check poster policy, venue, tiers, refund policy, age rating and lineup before approving."
        actions={
          <select value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="">All statuses</option>
            {['pending_review', 'live', 'changes_requested', 'rejected', 'taken_down', 'draft'].map((s) => (
              <option key={s} value={s}>
                {s}
              </option>
            ))}
          </select>
        }
      />
      <ErrorBox message={error ?? actionError} />
      {loading ? <Loading /> : null}
      {data && data.events.length === 0 ? <EmptyState message="Nothing in this queue." /> : null}

      {data ? (
        <Panel>
          <table className="table">
            <thead>
              <tr>
                <th>Event</th>
                <th>Organizer</th>
                <th>Status</th>
                <th>Starts</th>
                <th>Price from</th>
                <th>Age</th>
                <th>Reports</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {data.events.map((row) => (
                <tr key={row.id}>
                  <td>
                    <strong>{row.title}</strong>
                    <div className="muted small">
                      {row.cityId ?? '—'} · {row.categoryId ?? '—'} · {row.capacityTotal} capacity
                    </div>
                  </td>
                  <td>
                    {row.organizerName ?? row.organizerId}
                    <div className="muted small">{relTime(row.updatedAt)}</div>
                  </td>
                  <td>
                    <StatusPill value={row.status} />
                  </td>
                  <td className="small">{dateTime(row.startAt)}</td>
                  <td>{inr(row.minPricePaise)}</td>
                  <td>{row.ageLimit}+</td>
                  <td>{row.reportCount > 0 ? <span className="pill pill-bad">{row.reportCount}</span> : '0'}</td>
                  <td className="actions">
                    <button className="btn" disabled={busy === row.id} onClick={() => decide(row.id, 'approve')}>
                      Approve
                    </button>
                    <button
                      className="btn btn-ghost"
                      disabled={busy === row.id}
                      onClick={() => decide(row.id, 'request_changes', 'Please update venue and refund policy')}
                    >
                      Changes
                    </button>
                    <button
                      className="btn btn-ghost"
                      disabled={busy === row.id}
                      onClick={() => decide(row.id, 'reject', 'Does not meet listing policy')}
                    >
                      Reject
                    </button>
                    {row.status === 'live' ? (
                      <button
                        className="btn btn-ghost"
                        disabled={busy === row.id}
                        onClick={() => decide(row.id, 'take_down', 'Taken down by moderation')}
                      >
                        Take down
                      </button>
                    ) : null}
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
