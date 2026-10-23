import { useState } from 'react';
import { PageHeader, Panel, Loading, ErrorBox, EmptyState, StatusPill } from '../components/ui';
import { call } from '../lib/api';
import { useCallable } from '../lib/useCallable';
import { relTime } from '../lib/format';

interface ReportRow {
  id: string;
  reporterId: string;
  targetType: string;
  targetId: string;
  eventId: string | null;
  reason: string;
  note: string | null;
  status: string;
  evidence?: Array<{ senderId: string; text: string }>;
  createdAt: unknown;
}

interface FlagRow {
  id: string;
  type: string;
  severity: string;
  subjectType: string;
  subjectId: string;
  status: string;
  details: Record<string, unknown>;
  createdAt: unknown;
}

interface UserSearchResult {
  users: Array<{
    uid: string;
    displayName: string | null;
    emailMasked: string | null;
    phoneMasked: string | null;
    status: string;
    roles: string[];
    faceVerified: boolean;
    createdAt: unknown;
  }>;
  sosAlerts: Array<{ id: string; status: string; startedAt: unknown; resolvedAt: unknown }>;
}

export function UsersReports() {
  const [tab, setTab] = useState<'reports' | 'fraud' | 'users'>('reports');
  const [query, setQuery] = useState('');
  const [searchResult, setSearchResult] = useState<UserSearchResult | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const reports = useCallable<{ reports: ReportRow[] }>(() => call('adminListReports', {}), []);
  const flags = useCallable<{ flags: FlagRow[] }>(() => call('adminListFraudFlags', {}), []);

  async function resolveReport(reportId: string, status: 'in_review' | 'actioned' | 'dismissed') {
    setBusy(reportId);
    setActionError(null);
    try {
      await call('adminResolveReport', { reportId, status });
      reports.reload();
    } catch (err) {
      setActionError((err as Error).message);
    } finally {
      setBusy(null);
    }
  }

  async function fraudAction(flagId: string, action: 'confirm' | 'false_positive') {
    setBusy(flagId);
    setActionError(null);
    try {
      await call('adminFraudAction', { flagId, action });
      flags.reload();
    } catch (err) {
      setActionError((err as Error).message);
    } finally {
      setBusy(null);
    }
  }

  async function userAction(uid: string, action: 'warn' | 'ghost' | 'suspend' | 'ban' | 'restore', reason?: string) {
    setBusy(uid);
    setActionError(null);
    try {
      await call('adminUserAction', { uid, action, reason });
    } catch (err) {
      setActionError((err as Error).message);
    } finally {
      setBusy(null);
    }
  }

  async function search() {
    setActionError(null);
    try {
      setSearchResult(await call<Record<string, unknown>, UserSearchResult>('adminSearchUsers', { query }));
    } catch (err) {
      setActionError((err as Error).message);
    }
  }

  return (
    <>
      <PageHeader
        title="Users, reports & fraud"
        subtitle="PII stays masked. Reveal and destructive actions are audit logged."
        actions={
          <div className="tabs">
            {(['reports', 'fraud', 'users'] as const).map((t) => (
              <button key={t} className={`btn ${tab === t ? 'btn-primary' : 'btn-ghost'}`} onClick={() => setTab(t)}>
                {t}
              </button>
            ))}
          </div>
        }
      />
      <ErrorBox message={actionError} />

      {tab === 'reports' ? (
        <>
          {reports.loading ? <Loading /> : null}
          {reports.data && reports.data.reports.length === 0 ? (
            <EmptyState message="No reports open." />
          ) : null}
          {reports.data ? (
            <Panel>
              <table className="table">
                <thead>
                  <tr>
                    <th>Report</th>
                    <th>Target</th>
                    <th>Reason</th>
                    <th>Status</th>
                    <th>Age</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {reports.data.reports.map((row) => (
                    <tr key={row.id}>
                      <td className="mono small">{row.id}</td>
                      <td className="small">
                        {row.targetType}
                        <div className="muted mono">{row.targetId}</div>
                      </td>
                      <td>
                        {row.reason}
                        {row.note ? <div className="muted small">{row.note}</div> : null}
                      </td>
                      <td>
                        <StatusPill value={row.status} />
                      </td>
                      <td className="muted small">{relTime(row.createdAt)}</td>
                      <td className="actions">
                        <button className="btn" disabled={busy === row.id} onClick={() => resolveReport(row.id, 'actioned')}>
                          Action
                        </button>
                        <button
                          className="btn btn-ghost"
                          disabled={busy === row.id}
                          onClick={() => resolveReport(row.id, 'dismissed')}
                        >
                          Dismiss
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </Panel>
          ) : null}
        </>
      ) : null}

      {tab === 'fraud' ? (
        <>
          {flags.loading ? <Loading /> : null}
          {flags.data && flags.data.flags.length === 0 ? <EmptyState message="No fraud flags." /> : null}
          {flags.data ? (
            <Panel>
              <table className="table">
                <thead>
                  <tr>
                    <th>Type</th>
                    <th>Subject</th>
                    <th>Severity</th>
                    <th>Status</th>
                    <th>Age</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {flags.data.flags.map((row) => (
                    <tr key={row.id}>
                      <td>{row.type}</td>
                      <td className="small">
                        {row.subjectType}
                        <div className="muted mono">{row.subjectId}</div>
                      </td>
                      <td>
                        <StatusPill value={row.severity} />
                      </td>
                      <td>
                        <StatusPill value={row.status} />
                      </td>
                      <td className="muted small">{relTime(row.createdAt)}</td>
                      <td className="actions">
                        <button className="btn" disabled={busy === row.id} onClick={() => fraudAction(row.id, 'confirm')}>
                          Confirm
                        </button>
                        <button
                          className="btn btn-ghost"
                          disabled={busy === row.id}
                          onClick={() => fraudAction(row.id, 'false_positive')}
                        >
                          False positive
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </Panel>
          ) : null}
        </>
      ) : null}

      {tab === 'users' ? (
        <Panel>
          <div className="row">
            <input
              value={query}
              placeholder="UID, phone or email"
              onChange={(e) => setQuery(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') void search();
              }}
            />
            <button className="btn btn-primary" onClick={() => void search()}>
              Search
            </button>
          </div>

          {searchResult ? (
            <table className="table">
              <thead>
                <tr>
                  <th>User</th>
                  <th>Contact</th>
                  <th>Status</th>
                  <th>SOS history</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {searchResult.users.map((user) => (
                  <tr key={user.uid}>
                    <td>
                      <strong>{user.displayName ?? 'Unknown'}</strong>
                      <div className="muted small mono">{user.uid}</div>
                    </td>
                    <td className="small">
                      {user.emailMasked ?? '—'}
                      <div className="muted small">{user.phoneMasked ?? '—'}</div>
                    </td>
                    <td>
                      <StatusPill value={user.status} />
                      {user.faceVerified ? <span className="pill pill-ok">verified</span> : null}
                    </td>
                    <td className="small">
                      {searchResult.sosAlerts.length === 0 ? (
                        <span className="muted">none</span>
                      ) : (
                        searchResult.sosAlerts.map((s) => (
                          <div key={s.id}>
                            <StatusPill value={s.status} />
                          </div>
                        ))
                      )}
                    </td>
                    <td className="actions">
                      <button className="btn" disabled={busy === user.uid} onClick={() => userAction(user.uid, 'warn')}>
                        Warn
                      </button>
                      <button
                        className="btn btn-ghost"
                        disabled={busy === user.uid}
                        onClick={() => userAction(user.uid, 'ghost')}
                      >
                        Ghost
                      </button>
                      <button
                        className="btn btn-ghost"
                        disabled={busy === user.uid}
                        onClick={() => userAction(user.uid, 'suspend')}
                      >
                        Suspend
                      </button>
                      <button
                        className="btn btn-ghost"
                        disabled={busy === user.uid}
                        onClick={() => userAction(user.uid, 'restore')}
                      >
                        Restore
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <p className="muted">Search a user by UID, phone or email to see masked profile, SOS history and actions.</p>
          )}
        </Panel>
      ) : null}
    </>
  );
}
