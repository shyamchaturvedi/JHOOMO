import { PageHeader, Panel, Loading, ErrorBox } from '../components/ui';
import { call } from '../lib/api';
import { useCallable } from '../lib/useCallable';
import { inr, dateTime } from '../lib/format';

interface Stats {
  gmv30dPaise: number;
  bookings30d: number;
  queues: { kyc: number; eventReview: number; refunds: number; reports: number; fraud: number };
  liveEventsNow: number;
  daily: Array<{ id: string; gmvPaise?: number; bookings?: number; tickets?: number; refundsPaise?: number }>;
}

export function Dashboard() {
  const { data, loading, error } = useCallable<Stats>(() => call('adminDashboardStats', {}));

  return (
    <>
      <PageHeader title="Dashboard" subtitle="Live operational snapshot across Milo" />
      <ErrorBox message={error} />
      {loading ? <Loading /> : null}

      {data ? (
        <>
          <div className="grid-4">
            <Panel className="stat">
              <span className="muted small">GMV (30 d)</span>
              <strong>{inr(data.gmv30dPaise)}</strong>
            </Panel>
            <Panel className="stat">
              <span className="muted small">Bookings (30 d)</span>
              <strong>{data.bookings30d}</strong>
            </Panel>
            <Panel className="stat">
              <span className="muted small">Live events now</span>
              <strong>{data.liveEventsNow}</strong>
            </Panel>
            <Panel className="stat">
              <span className="muted small">Open queues</span>
              <strong>
                {data.queues.kyc + data.queues.eventReview + data.queues.refunds + data.queues.reports + data.queues.fraud}
              </strong>
            </Panel>
          </div>

          <div className="grid-2">
            <Panel>
              <h3>Review queues</h3>
              <table className="table">
                <tbody>
                  <tr>
                    <th>KYC reviews</th>
                    <td>{data.queues.kyc}</td>
                  </tr>
                  <tr>
                    <th>Event moderation</th>
                    <td>{data.queues.eventReview}</td>
                  </tr>
                  <tr>
                    <th>Refund disputes</th>
                    <td>{data.queues.refunds}</td>
                  </tr>
                  <tr>
                    <th>User reports</th>
                    <td>{data.queues.reports}</td>
                  </tr>
                  <tr>
                    <th>Fraud flags</th>
                    <td>{data.queues.fraud}</td>
                  </tr>
                </tbody>
              </table>
            </Panel>

            <Panel>
              <h3>Daily ledger (adminStats)</h3>
              {data.daily.length === 0 ? (
                <p className="muted">No daily stats written yet.</p>
              ) : (
                <table className="table">
                  <thead>
                    <tr>
                      <th>Day</th>
                      <th>GMV</th>
                      <th>Bookings</th>
                      <th>Refunds</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.daily.map((row) => (
                      <tr key={row.id}>
                        <td>{row.id}</td>
                        <td>{inr(row.gmvPaise ?? 0)}</td>
                        <td>{row.bookings ?? 0}</td>
                        <td>{inr(row.refundsPaise ?? 0)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
              <p className="muted small">Snapshot generated {dateTime(new Date())}</p>
            </Panel>
          </div>
        </>
      ) : null}
    </>
  );
}
