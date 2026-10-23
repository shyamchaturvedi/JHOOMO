import { useState } from 'react';
import { PageHeader, Panel, Loading, ErrorBox, EmptyState, StatusPill } from '../components/ui';
import { call } from '../lib/api';
import { useCallable } from '../lib/useCallable';
import { dateTime, titleCase } from '../lib/format';

interface TicketRow {
  id: string;
  userId: string;
  category: string;
  subject: string;
  status: string;
  priority: string;
  bookingId: string | null;
  slaDueAt: unknown;
  lastMessageAt: unknown;
}

export function SupportDesk() {
  const [status, setStatus] = useState('');
  const { data, loading, error, reload } = useCallable<{ tickets: TicketRow[] }>(
    () => call('adminListSupportTickets', status ? { status } : {}),
    [status],
  );
  const [reply, setReply] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  async function send(ticketId: string, nextStatus?: 'open' | 'in_progress' | 'resolved' | 'closed') {
    const text = (reply[ticketId] ?? '').trim();
    if (!text) return;
    setBusy(ticketId);
    setActionError(null);
    try {
      await call('adminReplySupportTicket', { ticketId, text, status: nextStatus });
      setReply((prev) => ({ ...prev, [ticketId]: '' }));
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
        title="Support desk"
        subtitle="SLA timers run from ticket creation. Safety tickets have a 4-hour SLA."
        actions={
          <select value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="">All tickets</option>
            {['open', 'in_progress', 'resolved', 'closed'].map((s) => (
              <option key={s} value={s}>
                {s}
              </option>
            ))}
          </select>
        }
      />
      <ErrorBox message={error ?? actionError} />
      {loading ? <Loading /> : null}
      {data && data.tickets.length === 0 ? <EmptyState message="Inbox is clear." /> : null}

      {data ? (
        <div className="stack">
          {data.tickets.map((ticket) => (
            <Panel key={ticket.id}>
              <div className="ticket-head">
                <div>
                  <strong>{ticket.subject}</strong>
                  <div className="muted small">
                    {titleCase(ticket.category)} · {ticket.id} · SLA {dateTime(ticket.slaDueAt)}
                  </div>
                </div>
                <div className="row">
                  <StatusPill value={ticket.status} />
                  {ticket.priority === 'high' ? <span className="pill pill-bad">high</span> : null}
                </div>
              </div>
              <div className="row">
                <input
                  value={reply[ticket.id] ?? ''}
                  placeholder="Reply to the customer…"
                  onChange={(e) => setReply((prev) => ({ ...prev, [ticket.id]: e.target.value }))}
                />
                <button className="btn btn-primary" disabled={busy === ticket.id} onClick={() => void send(ticket.id)}>
                  Send
                </button>
                <button
                  className="btn btn-ghost"
                  disabled={busy === ticket.id}
                  onClick={() => void send(ticket.id, 'resolved')}
                >
                  Resolve
                </button>
              </div>
            </Panel>
          ))}
        </div>
      ) : null}
    </>
  );
}
