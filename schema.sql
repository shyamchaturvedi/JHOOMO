-- ==============================================================================
-- MILO OFFICIAL SERVERLESS POSTGRESQL DATABASE SCHEMA (Neon / PostgreSQL)
-- Project: Milo — Meet | Vibe | Show
-- Compatible with: Neon PostgreSQL, Supabase, Standard Postgres 15+
-- ==============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- 1. USERS & PROFILES TABLE
-- ==============================================================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone_number VARCHAR(20) UNIQUE,
    full_name VARCHAR(150) NOT NULL,
    avatar_url TEXT,
    bio TEXT,
    city VARCHAR(100) DEFAULT 'Lucknow',
    gender VARCHAR(20),
    is_verified BOOLEAN DEFAULT FALSE,
    trust_score NUMERIC(3,2) DEFAULT 4.90,
    role VARCHAR(50) DEFAULT 'user', -- 'user', 'organizer', 'super_admin'
    emergency_contact_phone VARCHAR(20),
    emergency_contact_name VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index for instant lookup
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- Seed Super Admin user
INSERT INTO users (id, email, full_name, role, is_verified, trust_score)
VALUES (
    gen_random_uuid(),
    'iammshyam@gmail.com',
    'Milo Super Admin',
    'super_admin',
    TRUE,
    5.00
) ON CONFLICT (email) DO UPDATE SET role = 'super_admin', is_verified = TRUE;

-- ==============================================================================
-- 2. EVENTS TABLE (Large Shows, Dandiya, DJ, Comedy, Fests)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organizer_id UUID REFERENCES users(id) ON DELETE SET NULL,
    organizer_name VARCHAR(150) NOT NULL,
    is_verified_organizer BOOLEAN DEFAULT TRUE,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(100) NOT NULL, -- 'Dandiya/Garba', 'DJ Night', 'Standup Comedy', etc.
    banner_url TEXT,
    event_date VARCHAR(50) NOT NULL, -- e.g. 'Sat, 26 Sep 2026'
    event_time VARCHAR(50) NOT NULL, -- e.g. '07:00 PM onwards'
    venue_name VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    starting_price NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    tickets_left INTEGER DEFAULT 100,
    is_trending BOOLEAN DEFAULT FALSE,
    status VARCHAR(50) DEFAULT 'live', -- 'pending_approval', 'live', 'completed', 'cancelled'
    risk_score INTEGER DEFAULT 4, -- 0-100 risk assessment
    tags TEXT[] DEFAULT ARRAY[]::TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_events_city_category ON events(city, category);
CREATE INDEX IF NOT EXISTS idx_events_status ON events(status);

-- ==============================================================================
-- 3. TICKET TIERS TABLE (Pass Variations like Single, Couple, VIP)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS ticket_tiers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    tier_name VARCHAR(100) NOT NULL, -- 'Single Entry Pass', 'Couple Pass', 'VIP Squad'
    price NUMERIC(10,2) NOT NULL,
    description TEXT,
    perks TEXT[] DEFAULT ARRAY[]::TEXT[],
    available_seats INTEGER NOT NULL DEFAULT 50,
    sold_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ticket_tiers_event ON ticket_tiers(event_id);

-- ==============================================================================
-- 4. BOOKINGS & TICKETS TABLE (Issued Passes with QR Hashes)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_ref VARCHAR(50) UNIQUE NOT NULL, -- e.g. 'MILO-DND-9241'
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    user_name VARCHAR(150) NOT NULL,
    user_phone VARCHAR(20),
    event_id UUID REFERENCES events(id) ON DELETE CASCADE,
    tier_id UUID REFERENCES ticket_tiers(id) ON DELETE SET NULL,
    tier_name VARCHAR(100) NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    total_amount NUMERIC(10,2) NOT NULL,
    qr_hash_token VARCHAR(255) NOT NULL, -- Dynamic Anti-Screenshot Rotating Token
    payment_status VARCHAR(50) DEFAULT 'paid', -- 'pending', 'paid', 'refunded'
    referral_code VARCHAR(50), -- Promoter / Influencer code (e.g. 'LKO_VIKAS')
    promoter_commission NUMERIC(10,2) DEFAULT 0.00, -- 10% direct cash attribution
    is_checked_in BOOLEAN DEFAULT FALSE,
    checked_in_at TIMESTAMP WITH TIME ZONE,
    booked_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_bookings_user ON bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_ref ON bookings(booking_ref);
CREATE INDEX IF NOT EXISTS idx_bookings_event ON bookings(event_id);
CREATE INDEX IF NOT EXISTS idx_bookings_referral ON bookings(referral_code);

-- ==============================================================================
-- 4B. PROMOTER & INFLUENCER REFERRALS (Synced Transparency for Organizer & Influencer)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS promoter_referrals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    promoter_id UUID REFERENCES users(id) ON DELETE CASCADE,
    promoter_name VARCHAR(150) NOT NULL,
    promoter_handle VARCHAR(100) NOT NULL,
    referral_code VARCHAR(50) UNIQUE NOT NULL,
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    share_link TEXT NOT NULL,
    total_clicks INTEGER DEFAULT 0,
    tickets_sold INTEGER DEFAULT 0,
    gross_revenue NUMERIC(12,2) DEFAULT 0.00,
    commission_rate_percent NUMERIC(4,2) DEFAULT 10.00,
    commission_earned NUMERIC(12,2) DEFAULT 0.00,
    payout_status VARCHAR(50) DEFAULT 'pending_escrow', -- 'pending_escrow', 'settled'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_promoter_referrals_code ON promoter_referrals(referral_code);
CREATE INDEX IF NOT EXISTS idx_promoter_referrals_event ON promoter_referrals(event_id);

-- ==============================================================================
-- 5. SPONTANEOUS BEACONS TABLE (2-Hour Near-Me Meets)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS beacons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id UUID REFERENCES users(id) ON DELETE CASCADE,
    creator_name VARCHAR(150) NOT NULL,
    activity_type VARCHAR(100) NOT NULL, -- 'Chai & Brainstorm', 'Badminton Doubles', etc.
    category VARCHAR(50) NOT NULL, -- 'Coffee', 'Sports', 'Coworking', 'Chill'
    location_name VARCHAR(255) NOT NULL,
    distance_km NUMERIC(4,2) DEFAULT 1.2,
    squad_size_current INTEGER DEFAULT 1,
    squad_size_max INTEGER DEFAULT 4,
    privacy_mode VARCHAR(50) DEFAULT 'exact', -- 'exact', '500m_fuzz', 'female_only'
    status VARCHAR(50) DEFAULT 'active', -- 'active', 'expired', 'full'
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_beacons_status ON beacons(status);

-- ==============================================================================
-- 6. REVIEWS & RATINGS TABLE (Post-Event Feedback & Rapido Badges)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    user_name VARCHAR(150) NOT NULL,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    badges TEXT[] DEFAULT ARRAY[]::TEXT[], -- 'Vibrant Crowd 💃', 'Top Sound System 🔊', etc.
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_reviews_event ON reviews(event_id);

-- ==============================================================================
-- 7. ESCROW SETTLEMENTS & PAYOUTS TABLE (3-5 Days Escrow Policy)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS payouts_escrow (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organizer_id UUID REFERENCES users(id) ON DELETE CASCADE,
    event_id UUID REFERENCES events(id) ON DELETE CASCADE,
    event_title VARCHAR(255) NOT NULL,
    gross_revenue NUMERIC(12,2) NOT NULL,
    platform_fee NUMERIC(12,2) NOT NULL,
    net_payout NUMERIC(12,2) NOT NULL,
    settlement_status VARCHAR(50) DEFAULT 'escrow_locked', -- 'escrow_locked', 'released', 'disputed'
    release_due_date DATE NOT NULL,
    dispute_reason TEXT,
    approved_by_admin UUID REFERENCES users(id),
    released_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_payouts_status ON payouts_escrow(settlement_status);

-- ==============================================================================
-- SAMPLE SEED DATA FOR IMMEDIATE APP LAUNCH
-- ==============================================================================

-- Seed 1: Grand Dandiya Mahotsav
INSERT INTO events (id, organizer_name, is_verified_organizer, title, description, category, banner_url, event_date, event_time, venue_name, city, starting_price, tickets_left, is_trending, status, risk_score, tags)
VALUES (
    'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
    'Utsav Events & Club',
    TRUE,
    'Grand Dandiya Mahotsav 2026 ✨',
    'Experience Lucknow’s most extravagant Dandiya & Garba Night with authentic Gujarati food stalls, high-energy live dhol, celebrity DJ beats, and massive prizes for best-dressed couple and solo dancers!',
    'Dandiya/Garba',
    'https://images.unsplash.com/photo-1600093463592-8e36ae95ef56?auto=format&fit=crop&w=800&q=80',
    'Sat, 26 Sep 2026',
    '07:00 PM onwards',
    'Sanskriti Lawns, Gomti Nagar',
    'Lucknow',
    499.00,
    42,
    TRUE,
    'live',
    4,
    ARRAY['Traditional Garba', 'Live Dhol', 'Celebrity DJ', 'Food Court']
) ON CONFLICT DO NOTHING;

-- Seed Ticket Tiers for Dandiya
INSERT INTO ticket_tiers (event_id, tier_name, price, description, perks, available_seats, sold_count)
VALUES 
('a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d', 'Single Entry Pass', 499.00, 'Standard single entry access with 1 complimentary mocktail.', ARRAY['Ground Entry', 'Free Dandiya Sticks', '1 Beverage'], 120, 78),
('a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d', 'Couple Pass', 899.00, 'Couples only. Priority lane entry + photo booth access.', ARRAY['Priority Entry for 2', '2 Pairs Dandiya Sticks', '2 Mocktails', 'Photo Souvenir'], 65, 30),
('a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d', 'VIP Group Squad (5 Pax)', 2199.00, 'Reserved high table seating + dedicated food & beverage service.', ARRAY['VIP Table for 5', '5 Pairs Dandiya', 'Starter Platter', 'VIP Parking'], 12, 6)
ON CONFLICT DO NOTHING;
