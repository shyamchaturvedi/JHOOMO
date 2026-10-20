const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

const pool = new Pool({
  connectionString: 'postgresql://neondb_owner:npg_sWtnfINB3e1J@ep-lucky-truth-b5tk44nx-pooler.c-7.us-east-2.aws.neon.tech/neondb?sslmode=require',
  ssl: { rejectUnauthorized: false }
});

// 1. GET ALL LIVE EVENTS
app.get('/api/events', async (req, res) => {
  try {
    const { city, category } = req.query;
    let query = 'SELECT * FROM events WHERE status = $1';
    let params = ['live'];

    if (city && city !== 'All Cities' && city !== 'All') {
      params.push(city);
      query += ` AND city = $${params.length}`;
    }
    if (category && category !== 'All' && category !== 'All Categories') {
      params.push(category);
      query += ` AND category = $${params.length}`;
    }

    query += ' ORDER BY created_at DESC';
    const result = await pool.query(query, params);

    // Fetch ticket tiers for each event
    const eventsWithTiers = await Promise.all(
      result.rows.map(async (event) => {
        const tiersRes = await pool.query(
          'SELECT * FROM ticket_tiers WHERE event_id = $1 ORDER BY price ASC',
          [event.id]
        );
        return {
          ...event,
          ticketTiers: tiersRes.rows
        };
      })
    );

    res.json(eventsWithTiers);
  } catch (err) {
    console.error('Error fetching events:', err);
    res.status(500).json({ error: 'Database error fetching events' });
  }
});

// 2. CREATE NEW EVENT (Organizer)
app.post('/api/events', async (req, res) => {
  try {
    const {
      title,
      description,
      category,
      banner_url,
      event_date,
      event_time,
      venue_name,
      city,
      starting_price,
      organizer_name,
      tags
    } = req.body;

    const result = await pool.query(
      `INSERT INTO events 
      (title, description, category, banner_url, event_date, event_time, venue_name, city, starting_price, organizer_name, tags, status)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'live')
      RETURNING *`,
      [title, description, category, banner_url, event_date, event_time, venue_name, city, starting_price, organizer_name, tags || []]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error creating event:', err);
    res.status(500).json({ error: 'Database error creating event' });
  }
});

// 3. GET ACTIVE SPONTANEOUS BEACONS
app.get('/api/beacons', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT * FROM beacons 
      WHERE status = 'active' OR expires_at > NOW() 
      ORDER BY created_at DESC
    `);
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching beacons:', err);
    res.status(500).json({ error: 'Database error fetching beacons' });
  }
});

// 4. CREATE SPONTANEOUS BEACON
app.post('/api/beacons', async (req, res) => {
  try {
    const { creator_name, activity_type, category, location_name, squad_size_max } = req.body;
    const expiresAt = new Date(Date.now() + 2 * 60 * 60 * 1000); // 2 hours from now

    const result = await pool.query(
      `INSERT INTO beacons (creator_name, activity_type, category, location_name, squad_size_max, expires_at, status)
       VALUES ($1, $2, $3, $4, $5, $6, 'active')
       RETURNING *`,
      [creator_name || 'Milo Squad Lead', activity_type, category || 'Chai & Hangout', location_name, squad_size_max || 4, expiresAt]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error creating beacon:', err);
    res.status(500).json({ error: 'Database error creating beacon' });
  }
});

// 5. GET BOOKINGS / TICKETS
app.get('/api/bookings', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT b.*, e.title as event_title, e.event_date, e.event_time, e.venue_name, e.banner_url
      FROM bookings b
      LEFT JOIN events e ON b.event_id = e.id
      ORDER BY b.booked_at DESC
    `);
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching bookings:', err);
    res.status(500).json({ error: 'Database error fetching bookings' });
  }
});

// 6. CREATE TICKET BOOKING
app.post('/api/bookings', async (req, res) => {
  try {
    const {
      booking_ref,
      event_id,
      tier_name,
      quantity,
      total_amount,
      user_name,
      user_phone,
      qr_hash_token
    } = req.body;

    const result = await pool.query(
      `INSERT INTO bookings 
      (booking_ref, event_id, tier_name, quantity, total_amount, user_name, user_phone, qr_hash_token, payment_status)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'paid')
      RETURNING *`,
      [
        booking_ref || `MILO-${Date.now()}`,
        event_id,
        tier_name,
        quantity || 1,
        total_amount,
        user_name || 'Sahil (Verified)',
        user_phone || '+91 9876543210',
        qr_hash_token || `MILO_SECURE_${Date.now()}`
      ]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error creating booking:', err);
    res.status(500).json({ error: 'Database error creating booking' });
  }
});

// 7. GET USERS / SQUAD PROFILES
app.get('/api/users', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM users ORDER BY trust_score DESC');
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching users:', err);
    res.status(500).json({ error: 'Database error fetching users' });
  }
});

// 8. ESCROW PAYOUTS (Admin Only)
app.get('/api/admin/payouts', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM payouts_escrow ORDER BY created_at DESC');
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching payouts:', err);
    res.status(500).json({ error: 'Database error fetching payouts' });
  }
});

app.listen(port, () => {
  console.log(`Milo Neon Live Server running on port ${port}`);
});
