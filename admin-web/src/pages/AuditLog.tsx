import { useState } from 'react';
import { PageHeader, Panel, Loading, ErrorBox, EmptyState } from '../components/ui';
import { call } from '../lib/api';
import { useCallable } from '../lib/useCallable';
import { dateTime, titleCase } from '../lib/format';

interface AuditRow {
  id: string;
  actorUid: string;
  actorLevel: string | null;
  action: string;
  targetType: string;
  targetId: string;
  reason: string | null;
  ip: string | null;
  at: unknown;
}

export function AuditLog() {
  const [action, setAction] = useState('');
  const { data, loading, error } = useCallable<{ logs: AuditRow[] }>(
    () => call('adminListAuditLogs', action ? { action } : {}),
    [action],
  );

  return (
    <>
      <PageHeader
        title="Audit log"
        subtitle="Append-only record of every mutating admin action. Sink to BigQuery for long-term retention."
        actions={
          <input
            value={action}
            placeholder="action e.g. kyc.approve"
            onChange={(e) => setAction(e.target.value)}
          />
        }
      />
      <ErrorBox message={error} />
      {loading ? <Loading /> : null}
      {data && data.logs.length === 0 ? <EmptyState message="No audit entries." /> : null}

      {data ? (
        <Panel>
          <table className="table">
            <thead>
              <tr>
                <th>When</th>
                <th>Action</th>
                <th>Actor</th>
                <th>Target</th>
                <th>Reason</th>
                <th>IP</th>
              </tr>
            </thead>
            <tbody>
              {data.logs.map((row) => (
                <tr key={row.id}>
                  <td className="small muted">{dateTime(row.at)}</td>
                  <td className="small">{titleCase(row.action)}</td>
                  <td className="small">
                    <span className="mono">{row.actorUid.slice(0, 10)}…</span>
                    {row.actorLevel ? <div className="muted small">{row.actorLevel}</div> : null}
                  </td>
                  <td className="small">
                    {row.targetType}
                    <div className="muted mono">{row.targetId}</div>
                  </td>
                  <td className="small muted">{row.reason ?? '—'}</td>
                  <td className="small mono muted">{row.ip ?? '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </Panel>
      ) : null}
    </>
  );
}
