import React, { useState } from 'react';
import './index.css';

interface EventItem {
  id: string;
  title: string;
  venue: string;
  date: string;
  sold: number;
  capacity: number;
  revenue: number;
  status: 'LIVE' | 'DRAFT' | 'COMPLETED';
}

const MOCK_EVENTS: EventItem[] = [
  {
    id: 'e1',
    title: 'Sunidhi Chauhan Live in Concert',
    venue: 'Ekana Stadium, Lucknow',
    date: '28 Oct 2026 • 07:00 PM',
    sold: 1420,
    capacity: 2500,
    revenue: 708580,
    status: 'LIVE',
  },
  {
    id: 'e2',
    title: 'Navratri Dandiya & Garba Mahotsav',
    venue: 'Indira Gandhi Pratishthan, Lucknow',
    date: '02 Nov 2026 • 06:30 PM',
    sold: 850,
    capacity: 1200,
    revenue: 254150,
    status: 'LIVE',
  },
];

export function App() {
  const [activeTab, setActiveTab] = useState<'DASHBOARD' | 'EVENTS' | 'STAFF' | 'PROMOTERS' | 'SETTLEMENTS'>('DASHBOARD');

  const totalRevenue = MOCK_EVENTS.reduce((acc, ev) => acc + ev.revenue, 0);
  const totalSold = MOCK_EVENTS.reduce((acc, ev) => acc + ev.sold, 0);

  return (
    <div className="shell">
      {/* Sidebar */}
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-badge">JH</div>
          <div>
            <div className="brand-title">JHOOMO</div>
            <span className="brand-sub">Organizer Studio</span>
          </div>
        </div>

        <nav className="nav-menu">
          <a
            href="#dashboard"
            className={`nav-link ${activeTab === 'DASHBOARD' ? 'active' : ''}`}
            onClick={() => setActiveTab('DASHBOARD')}
          >
            📊 Dashboard Overview
          </a>
          <a
            href="#events"
            className={`nav-link ${activeTab === 'EVENTS' ? 'active' : ''}`}
            onClick={() => setActiveTab('EVENTS')}
          >
            🎟️ My Events & Shows
          </a>
          <a
            href="#staff"
            className={`nav-link ${activeTab === 'STAFF' ? 'active' : ''}`}
            onClick={() => setActiveTab('STAFF')}
          >
            🚪 Gate Staff & Scanners
          </a>
          <a
            href="#promoters"
            className={`nav-link ${activeTab === 'PROMOTERS' ? 'active' : ''}`}
            onClick={() => setActiveTab('PROMOTERS')}
          >
            📢 Influencer Tracking
          </a>
          <a
            href="#settlements"
            className={`nav-link ${activeTab === 'SETTLEMENTS' ? 'active' : ''}`}
            onClick={() => setActiveTab('SETTLEMENTS')}
          >
            💰 Payouts & KYC
          </a>
        </nav>

        <div style={{ marginTop: 'auto', borderTop: '1px solid rgba(255,255,255,0.1)', paddingTop: 16 }}>
          <div style={{ fontSize: 13, fontWeight: 700 }}>Vikas Events & Ent.</div>
          <div style={{ fontSize: 11, color: '#94A3B8' }}>Verified Host • Lucknow</div>
        </div>
      </aside>

      {/* Main Panel Content */}
      <main className="main-content">
        <div className="page-header">
          <div>
            <h1 className="page-title">Event Operations Dashboard</h1>
            <p className="page-sub">Live ticketing analytics, gate occupancy and realtime revenue.</p>
          </div>
          <button
            className="btn-primary"
            onClick={() => alert('New Event Creation wizard will open here.')}
          >
            + Create New Event
          </button>
        </div>

        {/* 4 Metric Stats */}
        <div className="grid-4">
          <div className="stat-card">
            <div className="stat-label">Gross Ticket Sales</div>
            <div className="stat-val">₹{totalRevenue.toLocaleString('en-IN')}</div>
            <span className="stat-badge green">↑ 100% Realtime</span>
          </div>

          <div className="stat-card">
            <div className="stat-label">Total Passes Sold</div>
            <div className="stat-val">{totalSold}</div>
            <span className="stat-badge green">Across 2 Live Shows</span>
          </div>

          <div className="stat-card">
            <div className="stat-label">Active Gate Staff</div>
            <div className="stat-val">4 Devices</div>
            <span className="stat-badge green">Scanner App Sync</span>
          </div>

          <div className="stat-card">
            <div className="stat-label">Influencer Referrals</div>
            <div className="stat-val">348 Sold</div>
            <span className="stat-badge green">10% Commission Model</span>
          </div>
        </div>

        {/* Active Events Table */}
        <div className="content-card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
            <h2 className="card-title" style={{ margin: 0 }}>Active Live Events</h2>
            <span style={{ fontSize: 12, color: '#64748B', fontWeight: 600 }}>Syncing with Firebase Firestore</span>
          </div>

          <table className="table">
            <thead>
              <tr>
                <th>Event Title</th>
                <th>Date & Venue</th>
                <th>Capacity Sold</th>
                <th>Gross Revenue</th>
                <th>Gate Staff Passcode</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {MOCK_EVENTS.map((ev) => {
                const percent = Math.round((ev.sold / ev.capacity) * 100);
                return (
                  <tr key={ev.id}>
                    <td style={{ fontWeight: 700 }}>{ev.title}</td>
                    <td style={{ color: '#64748B' }}>{ev.venue}</td>
                    <td>
                      <strong>{ev.sold}</strong> / {ev.capacity}
                      <span style={{ marginLeft: 8, fontSize: 11, color: '#10B981', fontWeight: 700 }}>
                        ({percent}%)
                      </span>
                    </td>
                    <td style={{ fontWeight: 800, color: '#E11D48' }}>₹{ev.revenue.toLocaleString('en-IN')}</td>
                    <td>
                      <span style={{ background: '#FFF1F2', color: '#E11D48', padding: '4px 8px', borderRadius: 6, fontWeight: 700, fontSize: 12 }}>
                        GATE-7829
                      </span>
                    </td>
                    <td>
                      <button
                        style={{ background: 'none', border: '1px solid #E2E8F0', padding: '6px 12px', borderRadius: 8, cursor: 'pointer', fontSize: 12, fontWeight: 600 }}
                        onClick={() => alert(`Share Staff Scanner Link for ${ev.title}:\nhttps://jhoomo.in/staff/join?eventId=${ev.id}`)}
                      >
                        Share Staff Link
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </main>
    </div>
  );
}
