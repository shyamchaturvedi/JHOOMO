import React, { useState, useEffect } from 'react';
import { 
  collection, 
  getDocs, 
  doc, 
  setDoc, 
  updateDoc, 
  deleteDoc, 
  serverTimestamp 
} from 'firebase/firestore';
import { db } from './firebase';
import './index.css';

interface TicketTier {
  id: string;
  name: string;
  price: number;
  available: number;
  description: string;
}

interface EventItem {
  id: string;
  title: string;
  venue_name: string;
  city: string;
  event_date: string;
  event_time: string;
  banner_url: string;
  starting_price: number;
  tickets_left: number;
  status: string;
  organizer_name: string;
  description: string;
  ticket_tiers?: TicketTier[];
  highlights?: string[];
}

export function App() {
  const [activeTab, setActiveTab] = useState<'DASHBOARD' | 'EVENTS' | 'CREATE_EVENT' | 'STAFF' | 'PROMOTERS'>('DASHBOARD');
  const [events, setEvents] = useState<EventItem[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [selectedEvent, setSelectedEvent] = useState<EventItem | null>(null);
  const [isEditing, setIsEditing] = useState<boolean>(false);

  // Form State for Create / Edit Event
  const [formData, setFormData] = useState({
    id: '',
    title: '',
    category: 'Concert',
    city: 'Lucknow',
    venue_name: '',
    event_date: '',
    event_time: '',
    starting_price: 499,
    tickets_left: 500,
    banner_url: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=1200&q=80',
    description: '',
    organizer_name: 'Antimbre Private Limited',
    highlight: 'An Unforgettable Live Multi-Day Festival & Arena Experience!',
    tierName: 'General Admission Pass',
    tierPrice: 499,
    tierCapacity: 500,
  });

  const fetchEvents = async () => {
    try {
      setLoading(true);
      const snap = await getDocs(collection(db, 'events'));
      const list: EventItem[] = [];
      snap.forEach((d) => {
        const data = d.data();
        list.push({
          id: d.id,
          title: data.title || 'Untitled Event',
          venue_name: data.venue_name || data.venue || 'Venue',
          city: data.city || 'Lucknow',
          event_date: data.event_date || data.date || 'TBD',
          event_time: data.event_time || data.time || '07:00 PM',
          banner_url: data.banner_url || data.banner || '',
          starting_price: Number(data.starting_price || data.price || 499),
          tickets_left: Number(data.tickets_left || 500),
          status: (data.status || 'live').toUpperCase(),
          organizer_name: data.organizer_name || 'Verified Host',
          description: data.description || '',
          ticket_tiers: data.ticket_tiers || [],
          highlights: data.highlights || [],
        });
      });
      setEvents(list);
    } catch (err) {
      console.error('Error fetching events from Firestore:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchEvents();
  }, []);

  const handleEditClick = (ev: EventItem) => {
    setSelectedEvent(ev);
    setFormData({
      id: ev.id,
      title: ev.title,
      category: 'Concert',
      city: ev.city,
      venue_name: ev.venue_name,
      event_date: ev.event_date,
      event_time: ev.event_time,
      starting_price: ev.starting_price,
      tickets_left: ev.tickets_left,
      banner_url: ev.banner_url,
      description: ev.description,
      organizer_name: ev.organizer_name,
      highlight: ev.highlights?.[0] || 'An Unforgettable Live Event Experience',
      tierName: ev.ticket_tiers?.[0]?.name || 'General Admission',
      tierPrice: ev.ticket_tiers?.[0]?.price || ev.starting_price,
      tierCapacity: ev.ticket_tiers?.[0]?.available || ev.tickets_left,
    });
    setIsEditing(true);
    setActiveTab('CREATE_EVENT');
  };

  const handleCreateNew = () => {
    setSelectedEvent(null);
    setFormData({
      id: `ev_${Date.now()}`,
      title: '',
      category: 'Concert',
      city: 'Lucknow',
      venue_name: '',
      event_date: 'Sat, 20 Nov 2026',
      event_time: '07:00 PM',
      starting_price: 799,
      tickets_left: 500,
      banner_url: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=1200&q=80',
      description: '',
      organizer_name: 'Antimbre Private Limited',
      highlight: 'An Unforgettable Live Multi-Day Festival & Arena Experience!',
      tierName: 'Early Bird Pass',
      tierPrice: 799,
      tierCapacity: 500,
    });
    setIsEditing(false);
    setActiveTab('CREATE_EVENT');
  };

  const handleSaveEvent = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const docId = isEditing && selectedEvent ? selectedEvent.id : formData.id || `ev_${Date.now()}`;
      const eventDocRef = doc(db, 'events', docId);

      const eventPayload = {
        id: docId,
        title: formData.title,
        category: formData.category,
        city: formData.city,
        venue_name: formData.venue_name,
        event_date: formData.event_date,
        event_time: formData.event_time,
        banner_url: formData.banner_url,
        starting_price: Number(formData.starting_price),
        tickets_left: Number(formData.tickets_left),
        organizer_name: formData.organizer_name,
        description: formData.description,
        status: 'live',
        is_verified_organizer: true,
        is_trending: true,
        highlights: [formData.highlight],
        ticket_tiers: [
          {
            id: 't1',
            name: formData.tierName,
            price: Number(formData.tierPrice),
            description: 'Standard Entry Pass',
            available: Number(formData.tierCapacity),
          }
        ],
        updated_at: serverTimestamp(),
      };

      await setDoc(eventDocRef, eventPayload, { merge: true });
      alert(isEditing ? '✓ Event details updated live in JHOOMO!' : '✓ New event created & published to JHOOMO!');
      await fetchEvents();
      setActiveTab('EVENTS');
    } catch (err) {
      console.error('Failed to save event:', err);
      alert('Error saving event to Firestore: ' + err);
    }
  };

  const handleDeleteEvent = async (id: string) => {
    if (!confirm('Are you sure you want to remove this event from JHOOMO?')) return;
    try {
      await deleteDoc(doc(db, 'events', id));
      alert('Event deleted from Firestore.');
      await fetchEvents();
    } catch (err) {
      console.error('Error deleting event:', err);
    }
  };

  return (
    <div className="shell">
      {/* Sidebar Navigation */}
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
            onClick={(e) => { e.preventDefault(); setActiveTab('DASHBOARD'); }}
          >
            📊 Dashboard Overview
          </a>
          <a
            href="#events"
            className={`nav-link ${activeTab === 'EVENTS' ? 'active' : ''}`}
            onClick={(e) => { e.preventDefault(); setActiveTab('EVENTS'); }}
          >
            🎟️ My Events & Shows ({events.length})
          </a>
          <a
            href="#create"
            className={`nav-link ${activeTab === 'CREATE_EVENT' ? 'active' : ''}`}
            onClick={(e) => { e.preventDefault(); handleCreateNew(); }}
          >
            ✨ Create / Edit Event
          </a>
          <a
            href="#staff"
            className={`nav-link ${activeTab === 'STAFF' ? 'active' : ''}`}
            onClick={(e) => { e.preventDefault(); setActiveTab('STAFF'); }}
          >
            🚪 Gate Scanner Passcodes
          </a>
          <a
            href="#promoters"
            className={`nav-link ${activeTab === 'PROMOTERS' ? 'active' : ''}`}
            onClick={(e) => { e.preventDefault(); setActiveTab('PROMOTERS'); }}
          >
            📢 Promoter Referrals
          </a>
        </nav>

        <div style={{ marginTop: 'auto', borderTop: '1px solid rgba(255,255,255,0.1)', paddingTop: 16 }}>
          <div style={{ fontSize: 13, fontWeight: 700 }}>Antimbre Private Limited</div>
          <div style={{ fontSize: 11, color: '#94A3B8' }}>Verified Organizer • Live Studio</div>
        </div>
      </aside>

      {/* Main Workspace */}
      <main className="main-content">
        {activeTab === 'DASHBOARD' && (
          <>
            <div className="page-header">
              <div>
                <h1 className="page-title">Organizer Studio Overview</h1>
                <p className="page-sub">Live events directly connected to JHOOMO mobile database.</p>
              </div>
              <button className="btn-primary" onClick={handleCreateNew}>
                + Create New Event
              </button>
            </div>

            <div className="grid-4">
              <div className="stat-card">
                <div className="stat-label">Live Active Shows</div>
                <div className="stat-val">{events.length}</div>
                <span className="stat-badge green">✓ Firestore Realtime</span>
              </div>
              <div className="stat-card">
                <div className="stat-label">Total Inventory (Capacity)</div>
                <div className="stat-val">{events.reduce((a, b) => a + (b.tickets_left || 0), 0)}</div>
                <span className="stat-badge green">Across all cities</span>
              </div>
              <div className="stat-card">
                <div className="stat-label">Target Cities</div>
                <div className="stat-val">5 Cities</div>
                <span className="stat-badge green">Lucknow, Kanpur, Agra...</span>
              </div>
              <div className="stat-card">
                <div className="stat-label">Gate Staff Status</div>
                <div className="stat-val">Online</div>
                <span className="stat-badge green">Scanner App Sync</span>
              </div>
            </div>

            {/* Quick Events Table */}
            <div className="content-card">
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
                <h2 className="card-title" style={{ margin: 0 }}>Active Shows ({events.length})</h2>
                <button 
                  onClick={fetchEvents}
                  style={{ background: '#F1F5F9', border: 'none', padding: '6px 12px', borderRadius: 8, cursor: 'pointer', fontWeight: 600, fontSize: 12 }}
                >
                  🔄 Refresh Data
                </button>
              </div>

              {loading ? (
                <p style={{ color: '#64748B', padding: 20 }}>Loading live events from Firestore...</p>
              ) : (
                <table className="table">
                  <thead>
                    <tr>
                      <th>Title</th>
                      <th>City & Venue</th>
                      <th>Show Date</th>
                      <th>Starting Price</th>
                      <th>Status</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {events.map((ev) => (
                      <tr key={ev.id}>
                        <td style={{ fontWeight: 700 }}>{ev.title}</td>
                        <td style={{ color: '#64748B' }}>{ev.city} • {ev.venue_name}</td>
                        <td>{ev.event_date}</td>
                        <td style={{ fontWeight: 800, color: '#E11D48' }}>₹{ev.starting_price}</td>
                        <td>
                          <span style={{ background: '#ECFDF5', color: '#10B981', padding: '4px 8px', borderRadius: 6, fontWeight: 700, fontSize: 11 }}>
                            {ev.status}
                          </span>
                        </td>
                        <td>
                          <button
                            onClick={() => handleEditClick(ev)}
                            style={{ background: '#FFF1F2', color: '#E11D48', border: '1px solid #FECDD3', padding: '6px 12px', borderRadius: 8, cursor: 'pointer', fontWeight: 700, fontSize: 12, marginRight: 8 }}
                          >
                            ✏️ Edit Page
                          </button>
                          <button
                            onClick={() => handleDeleteEvent(ev.id)}
                            style={{ background: '#F8FAFC', color: '#64748B', border: '1px solid #E2E8F0', padding: '6px 10px', borderRadius: 8, cursor: 'pointer', fontSize: 12 }}
                          >
                            🗑️
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </>
        )}

        {activeTab === 'EVENTS' && (
          <div className="content-card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
              <div>
                <h2 className="card-title" style={{ margin: 0 }}>All Listed Shows & Details</h2>
                <p className="page-sub">Edit any show detail to update customer app instantly.</p>
              </div>
              <button className="btn-primary" onClick={handleCreateNew}>
                + Create New Event
              </button>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: 20 }}>
              {events.map((ev) => (
                <div key={ev.id} style={{ border: '1px solid #E2E8F0', borderRadius: 16, overflow: 'hidden', background: '#fff' }}>
                  <img src={ev.banner_url} alt={ev.title} style={{ width: '100%', height: 160, objectFit: 'cover' }} />
                  <div style={{ padding: 16 }}>
                    <div style={{ fontSize: 11, fontWeight: 800, color: '#E11D48', textTransform: 'uppercase' }}>{ev.city}</div>
                    <h3 style={{ fontSize: 16, fontWeight: 800, margin: '4px 0 8px' }}>{ev.title}</h3>
                    <p style={{ fontSize: 12, color: '#64748B', margin: '4px 0' }}>📍 {ev.venue_name}</p>
                    <p style={{ fontSize: 12, color: '#64748B', margin: '4px 0' }}>📅 {ev.event_date} • {ev.event_time}</p>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 16, paddingTop: 12, borderTop: '1px solid #F1F5F9' }}>
                      <span style={{ fontSize: 16, fontWeight: 900, color: '#0F172A' }}>₹{ev.starting_price}</span>
                      <button
                        onClick={() => handleEditClick(ev)}
                        style={{ background: '#E11D48', color: '#fff', border: 'none', padding: '8px 16px', borderRadius: 8, cursor: 'pointer', fontWeight: 700, fontSize: 12 }}
                      >
                        Edit Details
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {activeTab === 'CREATE_EVENT' && (
          <div className="content-card" style={{ maxWidth: 800 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
              <h2 className="card-title" style={{ margin: 0 }}>
                {isEditing ? `✏️ Edit Event Details: ${selectedEvent?.title}` : '✨ Create New Event'}
              </h2>
              <button 
                onClick={() => setActiveTab('EVENTS')}
                style={{ background: '#F1F5F9', border: 'none', padding: '6px 14px', borderRadius: 8, cursor: 'pointer', fontWeight: 600 }}
              >
                ✕ Cancel
              </button>
            </div>

            <form onSubmit={handleSaveEvent} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              <div>
                <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 6 }}>Event Title *</label>
                <input
                  type="text"
                  required
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  placeholder="e.g. Sunidhi Chauhan Live in Concert"
                  style={{ width: '100%', padding: '10px 14px', borderRadius: 10, border: '1px solid #CBD5E1', fontSize: 14 }}
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
                <div>
                  <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 6 }}>City *</label>
                  <select
                    value={formData.city}
                    onChange={(e) => setFormData({ ...formData, city: e.target.value })}
                    style={{ width: '100%', padding: '10px 14px', borderRadius: 10, border: '1px solid #CBD5E1', fontSize: 14 }}
                  >
                    <option value="Lucknow">Lucknow</option>
                    <option value="Kanpur">Kanpur</option>
                    <option value="Agra">Agra</option>
                    <option value="Delhi">Delhi</option>
                    <option value="Mumbai">Mumbai</option>
                    <option value="Ahmedabad">Ahmedabad</option>
                    <option value="Bengaluru">Bengaluru</option>
                    <option value="Jaipur">Jaipur</option>
                  </select>
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 6 }}>Category</label>
                  <input
                    type="text"
                    value={formData.category}
                    onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                    style={{ width: '100%', padding: '10px 14px', borderRadius: 10, border: '1px solid #CBD5E1', fontSize: 14 }}
                  />
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 6 }}>Venue Name & Address *</label>
                <input
                  type="text"
                  required
                  value={formData.venue_name}
                  onChange={(e) => setFormData({ ...formData, venue_name: e.target.value })}
                  placeholder="e.g. Ekana International Stadium, Sector 7, Gomti Nagar"
                  style={{ width: '100%', padding: '10px 14px', borderRadius: 10, border: '1px solid #CBD5E1', fontSize: 14 }}
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
                <div>
                  <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 6 }}>Event Date *</label>
                  <input
                    type="text"
                    required
                    value={formData.event_date}
                    onChange={(e) => setFormData({ ...formData, event_date: e.target.value })}
                    placeholder="e.g. Sat, 14 Nov 2026"
                    style={{ width: '100%', padding: '10px 14px', borderRadius: 10, border: '1px solid #CBD5E1', fontSize: 14 }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 6 }}>Event Time / Gate Opening</label>
                  <input
                    type="text"
                    value={formData.event_time}
                    onChange={(e) => setFormData({ ...formData, event_time: e.target.value })}
                    placeholder="e.g. 07:00 PM (Gates open 2 PM)"
                    style={{ width: '100%', padding: '10px 14px', borderRadius: 10, border: '1px solid #CBD5E1', fontSize: 14 }}
                  />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
                <div>
                  <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 6 }}>Starting Ticket Price (₹) *</label>
                  <input
                    type="number"
                    required
                    value={formData.starting_price}
                    onChange={(e) => setFormData({ ...formData, starting_price: Number(e.target.value) })}
                    style={{ width: '100%', padding: '10px 14px', borderRadius: 10, border: '1px solid #CBD5E1', fontSize: 14 }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 6 }}>Total Capacity / Tickets Left</label>
                  <input
                    type="number"
                    value={formData.tickets_left}
                    onChange={(e) => setFormData({ ...formData, tickets_left: Number(e.target.value) })}
                    style={{ width: '100%', padding: '10px 14px', borderRadius: 10, border: '1px solid #CBD5E1', fontSize: 14 }}
                  />
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 6 }}>Spotlight Tagline (Why This Event Stands Out)</label>
                <input
                  type="text"
                  value={formData.highlight}
                  onChange={(e) => setFormData({ ...formData, highlight: e.target.value })}
                  placeholder="e.g. An Unforgettable Live Multi-Day Festival Experience in Lucknow!"
                  style={{ width: '100%', padding: '10px 14px', borderRadius: 10, border: '1px solid #CBD5E1', fontSize: 14 }}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 6 }}>Banner Poster Image URL</label>
                <input
                  type="text"
                  value={formData.banner_url}
                  onChange={(e) => setFormData({ ...formData, banner_url: e.target.value })}
                  placeholder="https://..."
                  style={{ width: '100%', padding: '10px 14px', borderRadius: 10, border: '1px solid #CBD5E1', fontSize: 14 }}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 6 }}>About the Event / Description</label>
                <textarea
                  rows={4}
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  placeholder="Detailed show information, artist schedule, rules..."
                  style={{ width: '100%', padding: '10px 14px', borderRadius: 10, border: '1px solid #CBD5E1', fontSize: 14 }}
                />
              </div>

              <div style={{ marginTop: 10 }}>
                <button type="submit" className="btn-primary" style={{ width: '100%', justifyContent: 'center', padding: '14px 20px', fontSize: 15 }}>
                  💾 Save & Publish Changes Live to Customer App
                </button>
              </div>
            </form>
          </div>
        )}

        {activeTab === 'STAFF' && (
          <div className="content-card">
            <h2 className="card-title">Gate Staff & Offline Scanners</h2>
            <p className="page-sub">Assign 6-digit gate passcodes to your security bouncers & entry staff.</p>
            <div style={{ marginTop: 20, padding: 16, background: '#F8FAFC', borderRadius: 12, border: '1px solid #E2E8F0' }}>
              <div style={{ fontWeight: 700, fontSize: 14 }}>Active Passcode: <span style={{ color: '#E11D48' }}>GATE-7829</span></div>
              <p style={{ fontSize: 12, color: '#64748B', marginTop: 4 }}>Gate staff can enter this code in the JHOOMO Staff App to start scanning tickets.</p>
            </div>
          </div>
        )}

        {activeTab === 'PROMOTERS' && (
          <div className="content-card">
            <h2 className="card-title">Influencer & Promoter Links</h2>
            <p className="page-sub">Track real-time ticket attribution and commission payouts.</p>
            <div style={{ marginTop: 20 }}>
              <p style={{ color: '#64748B', fontSize: 13 }}>Promoter links are automatically tracked on ticket checkout with 10% attribution.</p>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
