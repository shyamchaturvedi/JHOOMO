import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';
import 'my_tickets_screen.dart';
import 'organizer/organizer_dashboard_screen.dart';
import 'legal_policy_screen.dart';
import 'bank_account_settings_screen.dart';
import 'face_verification_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'promoter/promoter_dashboard_screen.dart';
import '../services/milo_auth_service.dart';
import '../services/milo_session_service.dart';
import '../config.dart';
import 'auth/phone_login_screen.dart';

class ProfileSafetyScreen extends StatefulWidget {
  const ProfileSafetyScreen({super.key});

  @override
  State<ProfileSafetyScreen> createState() => _ProfileSafetyScreenState();
}

class _ProfileSafetyScreenState extends State<ProfileSafetyScreen> {
  bool _ghostMode = false;
  bool _incognitoAttendance = true;
  bool _mutualRequestsOnly = true;
  bool _isFaceVerified = true;
  bool _isPhoneAdmin = false;

  @override
  void initState() {
    super.initState();
    MiloSessionService.currentRoleNotifier.addListener(_onRoleChanged);
    _resolvePhoneAdmin();
  }

  @override
  void dispose() {
    MiloSessionService.currentRoleNotifier.removeListener(_onRoleChanged);
    super.dispose();
  }

  void _onRoleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _resolvePhoneAdmin() async {
    final phone = MiloSessionService.currentUserPhone;
    if (phone.isEmpty) return;
    final isAdmin = await MiloAuthService.instance.isPhoneAdmin(phone: phone);
    if (!mounted) return;
    if (isAdmin != _isPhoneAdmin) setState(() => _isPhoneAdmin = isAdmin);
  }

  bool get _isSuperAdmin =>
      MiloSessionService.currentRoleNotifier.value == MiloRole.admin || _isPhoneAdmin;

  String get _uid => MiloSessionService.currentUid.trim();

  String get _inviteLink {
    final seed = _uid.isNotEmpty
        ? _uid
        : MiloSessionService.currentUserPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final shortCode = seed.length >= 6 ? seed.substring(seed.length - 6) : (seed.isEmpty ? 'sahil' : seed);
    return MiloConfig.inviteLink('join-$shortCode');
  }

  Future<void> _persistPrivacyPrefs(Map<String, dynamic> fields) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(fields, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Profile safety prefs persist error: $e');
    }
  }

  void _triggerFakeCall() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Container(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: MiloColors.bgCard,
                  child: Icon(Icons.person, size: 42, color: Colors.white70),
                ),
                const SizedBox(height: 14),
                Text('Mom 📞', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Incoming Call...', style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton(
                      heroTag: 'fake_call_decline',
                      backgroundColor: Colors.red,
                      onPressed: () => Navigator.pop(context),
                      child: const Icon(Icons.call_end, color: Colors.white),
                    ),
                    FloatingActionButton(
                      heroTag: 'fake_call_accept',
                      backgroundColor: Colors.green,
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Simulated Call Connected. You can now excuse yourself safely! 🛡️')),
                        );
                      },
                      child: const Icon(Icons.call, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _triggerSOS() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: MiloColors.bgSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: MiloColors.rose, size: 28),
              const SizedBox(width: 8),
              Text('Emergency SOS Alert', style: GoogleFonts.inter(color: MiloColors.rose, fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          content: Text(
            'This will immediately broadcast your last known event location & alert to your 2 designated emergency contacts + local venue safety desk.',
            style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              child: Text('Cancel', style: GoogleFonts.inter(color: MiloColors.textMuted)),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: MiloColors.rose),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: MiloColors.rose, content: Text('🚨 SOS Alert Dispatched to Emergency Contacts!')),
                );
              },
              child: Text('SEND SOS ALERT', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiloColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Profile & Safety Shield 🛡️', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: MiloColors.textPrimary, fontSize: 18)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          // Profile Card with Rapido Captain-Style Trust & Reputation Metrics
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MiloColors.bgSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: MiloColors.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        const CircleAvatar(
                          radius: 34,
                          backgroundImage: NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=300&q=80'),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _isFaceVerified ? MiloColors.emerald : MiloColors.amber,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isFaceVerified ? Icons.check : Icons.priority_high,
                              size: 12,
                              color: MiloColors.bg,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Sahil Kumar', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
                              const SizedBox(width: 6),
                              Icon(
                                _isFaceVerified ? Icons.verified : Icons.verified_outlined,
                                size: 16,
                                color: _isFaceVerified ? MiloColors.primaryLight : MiloColors.textMuted,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text('Lucknow • Vibe: Garba & Tech 🚀', style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: MiloColors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: MiloColors.amber.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.military_tech_rounded, color: MiloColors.amber, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Super Captain 🌟 (Top 1%)',
                                  style: GoogleFonts.inter(
                                    color: MiloColors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: MiloColors.border, height: 1),
                const SizedBox(height: 14),

                // ── Rapido Captain Style Performance Dashboard ──
                Row(
                  children: [
                    // Meetups / Rides completed
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: MiloColors.bgCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: MiloColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.handshake_rounded, color: MiloColors.primaryLight, size: 15),
                                const SizedBox(width: 4),
                                Text(
                                  '48',
                                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: MiloColors.textPrimary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('Meetups Done', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Rating & Reviews
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: MiloColors.bgCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: MiloColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.star_rounded, color: MiloColors.amber, size: 16),
                                const SizedBox(width: 3),
                                Text(
                                  '4.96',
                                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: MiloColors.textPrimary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('(68 Ratings)', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Reliability Score
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: MiloColors.bgCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: MiloColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.verified_user_rounded, color: MiloColors.emerald, size: 15),
                                const SizedBox(width: 4),
                                Text(
                                  '99%',
                                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: MiloColors.emerald),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('Reliability Rate', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Captain Compliments Badges
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    '⏱️ Always Punctual (42)',
                    '😎 Great Vibe (38)',
                    '🛡️ Safe Companion (45)',
                    '🌟 Super Helpful (29)',
                  ].map((compliment) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: MiloColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: MiloColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        compliment,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: MiloColors.primaryLight),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Face Selfie Verification Action Banner ──
          GestureDetector(
            onTap: () async {
              final verified = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (context) => const FaceVerificationScreen()),
              );
              if (verified == true) {
                setState(() => _isFaceVerified = true);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    MiloColors.cyan.withValues(alpha: 0.2),
                    MiloColors.bgSurface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: MiloColors.cyan.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MiloColors.cyan.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.face_retouching_natural, color: MiloColors.cyan, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Face & Selfie Verification',
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: MiloColors.emerald.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'AI Liveness',
                                style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 9, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Scan 3D selfie & match with profile photo for badge',
                          style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: MiloColors.cyan),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Quick Passes Launcher
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyTicketsScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [MiloColors.primary.withValues(alpha: 0.2), MiloColors.bgSurface],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: MiloColors.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: MiloColors.primary.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.confirmation_number_outlined, color: MiloColors.primaryLight, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Booked QR Passes 🎟️', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
                        Text('View active passes & rate completed events', style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: MiloColors.primaryLight),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Viral Squad Invite & App Share System (Free App Download) ──
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  MiloColors.primary.withValues(alpha: 0.2),
                  MiloColors.bgSurface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: MiloColors.primary.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_rounded, color: MiloColors.primaryLight, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Invite Friends to Milo 🚀',
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: MiloColors.emerald.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('100% FREE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: MiloColors.emerald)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Share your squad invite link so friends download Milo & join your events',
                            style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: MiloColors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MiloColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your Direct App Download Link:', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 10)),
                            const SizedBox(height: 2),
                            Text(_inviteLink, style: GoogleFonts.inter(color: MiloColors.primaryLight, fontWeight: FontWeight.w700, fontSize: 12)),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.share_outlined, size: 14, color: MiloColors.bg),
                        label: Text('Share', style: GoogleFonts.inter(color: MiloColors.bg, fontWeight: FontWeight.w800, fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MiloColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _inviteLink));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: MiloColors.bgSurface,
                              content: Text('📲 Invite Link copied: "Hey! Join my squad on Milo to meet up and attend events together. Download free: $_inviteLink"'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Safety & Emergency Toolkit ──
          Text('Emergency Safety Tools 🚨', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.rose)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _triggerFakeCall,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MiloColors.bgSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: MiloColors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.phone_in_talk, color: MiloColors.amber, size: 24),
                        const SizedBox(height: 10),
                        Text('Fake Call Exit', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text('Simulate incoming call to leave awkwardly', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _triggerSOS,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MiloColors.rose.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: MiloColors.rose.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.sos, color: MiloColors.rose, size: 24),
                        const SizedBox(height: 10),
                        Text('Instant SOS', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.rose)),
                        const SizedBox(height: 4),
                        Text('Alert trusted friends with live coords', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Privacy Shield Settings ──
          Text('Privacy Controls', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: MiloColors.bgSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MiloColors.glassBorder),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: MiloColors.primary,
                  activeThumbColor: MiloColors.primaryLight,
                  title: Text('Incognito Event Attendance', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: MiloColors.textPrimary)),
                  subtitle: Text('Never show other attendees you bought a ticket', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
                  value: _incognitoAttendance,
                  onChanged: (val) {
                    setState(() => _incognitoAttendance = val);
                    _persistPrivacyPrefs({'read_receipts': !val});
                  },
                ),
                const Divider(color: MiloColors.border, height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: MiloColors.primary,
                  activeThumbColor: MiloColors.primaryLight,
                  title: Text('Ghost Mode (Hide from Radar)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: MiloColors.textPrimary)),
                  subtitle: Text('Temporarily pause your discovery profile', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
                  value: _ghostMode,
                  onChanged: (val) {
                    setState(() => _ghostMode = val);
                    _persistPrivacyPrefs({'show_online': !val});
                  },
                ),
                const Divider(color: MiloColors.border, height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: MiloColors.primary,
                  activeThumbColor: MiloColors.primaryLight,
                  title: Text('Mutual Interest Requests Only', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: MiloColors.textPrimary)),
                  subtitle: Text('Only receive messages from shared event attendees', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
                  value: _mutualRequestsOnly,
                  onChanged: (val) {
                    setState(() => _mutualRequestsOnly = val);
                    _persistPrivacyPrefs({'discoverable': val});
                  },
                ),
              ],
            ),
          ),
        ),
          const SizedBox(height: 24),

          // ── Bank Account & Payout Settings ──
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BankAccountSettingsScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: MiloColors.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: MiloColors.glassBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: MiloColors.emerald.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance_rounded, color: MiloColors.emerald, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bank & Payout Settings 🏦', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
                          Text('HDFC Bank ••••••9201 (Verified)', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward_ios, color: MiloColors.primaryLight, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Switch to Organizer Mode ──
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OrganizerDashboardScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: MiloColors.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: MiloColors.glassBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: MiloColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.storefront_rounded, color: MiloColors.primaryLight, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Organizer Portal Mode 🎪',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Host Dandiya, Kitty, or Open Mic events',
                                style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios, color: MiloColors.primaryLight, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Influencer & Promoter Earnings Portal ──
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PromoterDashboardScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: MiloColors.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: MiloColors.emerald.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: MiloColors.emerald.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.campaign_rounded, color: MiloColors.emerald, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Promoter & Influencer Portal 📢',
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(color: MiloColors.emerald, borderRadius: BorderRadius.circular(4)),
                                    child: Text('10% CASH', style: GoogleFonts.inter(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                                  ),
                                ],
                              ),
                              Text(
                                'Track forwarded events, sold tickets & direct payouts',
                                style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios, color: MiloColors.emerald, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Super Admin Central Portal (role-verified only) ──
          if (_isSuperAdmin) ...[
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      MiloColors.rose.withValues(alpha: 0.15),
                      MiloColors.bgSurface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: MiloColors.rose.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: MiloColors.rose.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.admin_panel_settings_rounded, color: MiloColors.rose, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Super Admin Central 🛡️',
                                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(color: MiloColors.rose, borderRadius: BorderRadius.circular(4)),
                                      child: Text('ADMIN', style: GoogleFonts.inter(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Event approvals, escrow release & reports',
                                  style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios, color: MiloColors.rose, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 10),

          // ── Legal, Privacy & Policies Section ──
          Text('Legal, Policies & Terms 📄', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: MiloColors.bgSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MiloColors.glassBorder),
            ),
            child: Column(
              children: [
                _buildLegalItem(
                  title: 'User Terms of Service',
                  subtitle: 'Platform marketplace disclaimer & ticket rules',
                  icon: Icons.description_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LegalPolicyScreen(
                          title: 'Terms of Service',
                          policyType: 'terms',
                        ),
                      ),
                    );
                  },
                ),
                const Divider(color: MiloColors.border, height: 1),
                _buildLegalItem(
                  title: 'Organizer & Host Agreement',
                  subtitle: 'Pricing autonomy, coupon rules & host liability',
                  icon: Icons.business_center_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LegalPolicyScreen(
                          title: 'Organizer Terms & Agreement',
                          policyType: 'organizer_terms',
                        ),
                      ),
                    );
                  },
                ),
                const Divider(color: MiloColors.border, height: 1),
                _buildLegalItem(
                  title: 'Privacy & Safety Policy',
                  subtitle: 'How your data, location & chats are protected',
                  icon: Icons.security_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LegalPolicyScreen(
                          title: 'Privacy Policy',
                          policyType: 'privacy',
                        ),
                      ),
                    );
                  },
                ),
                const Divider(color: MiloColors.border, height: 1),
                _buildLegalItem(
                  title: 'Cancellation & Refund Policy',
                  subtitle: '100% refund guarantee for host cancellations',
                  icon: Icons.currency_exchange_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LegalPolicyScreen(
                          title: 'Refund & Cancellation Policy',
                          policyType: 'refund_policy',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Switch Role / Logout Tile ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MiloColors.bgSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MiloColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: MiloColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.swap_horiz_rounded, color: MiloColors.primaryLight, size: 20),
                  ),
                  title: Text('Switch Account Persona / Role', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
                  subtitle: Text('Change to Organizer, Promoter, Staff or Attendee', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: MiloColors.primaryLight, size: 14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PhoneLoginScreen()),
                    );
                  },
                ),
                const Divider(color: MiloColors.border, height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: MiloColors.rose.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.logout_rounded, color: MiloColors.rose, size: 20),
                  ),
                  title: Text('Log Out Account', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: MiloColors.rose)),
                  subtitle: Text('Clear session and return to phone login', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: MiloColors.rose, size: 14),
                  onTap: () async {
                    await MiloSessionService.logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const PhoneLoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _buildLegalItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: MiloColors.primaryLight, size: 20),
      title: Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: MiloColors.textPrimary)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textMuted)),
      trailing: const Icon(Icons.arrow_forward_ios, color: MiloColors.textMuted, size: 14),
    );
  }
}
