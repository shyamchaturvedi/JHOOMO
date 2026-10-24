import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../config.dart';
import '../theme/milo_theme.dart';
import 'chat/host_broadcast_channel_screen.dart';
import '../widgets/milo_bms_payment_sheet.dart';
import '../services/milo_promoter_tracking_service.dart';
import '../services/milo_wishlist_service.dart';
import '../services/milo_session_service.dart';

class EventDetailsScreen extends StatefulWidget {
  final EventModel event;

  /// Optional promoter referral code (from a deep link) pre-applied at open.
  final String? initialPromoCode;

  const EventDetailsScreen({super.key, required this.event, this.initialPromoCode});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  int _selectedTierIndex = 0;
  int _quantity = 1;
  bool _isFavorite = false;
  String _selectedDateIndex = "Today";
  String? _appliedPromoCode;
  double _discountAmount = 0.0;
  bool _isGroupBooking = false;
  bool _isInterested = false;
  late int _interestedCount;
  int? _expandedFaqIndex;


  StreamSubscription<DocumentSnapshot>? _interestedSub;

  @override
  void initState() {
    super.initState();
    _interestedCount = widget.event.interestedCount;
    _isFavorite = MiloWishlistService.instance.contains(widget.event.id);
    _initLiveInterested();

    final deepLinkCode = widget.initialPromoCode?.trim().toUpperCase();
    if (deepLinkCode != null && deepLinkCode.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyPromoCode(deepLinkCode, (fn) => setState(fn));
      });
    }
  }

  @override
  void dispose() {
    _interestedSub?.cancel();
    super.dispose();
  }

  void _initLiveInterested() {
    try {
      final db = FirebaseFirestore.instance;
      final docRef = db.collection('events').doc(widget.event.id);

      // Listen to real-time live interested count from Firestore
      _interestedSub = docRef.snapshots().listen((snap) {
        if (!mounted || !snap.exists) return;
        final data = snap.data();
        if (data == null) return;
        final list = List<String>.from(data['interested_uids'] ?? const []);
        final customCount = (data['interested_count'] as num?)?.toInt();
        final uid = MiloSessionService.currentUid;
        setState(() {
          if (uid.isNotEmpty) {
            _isInterested = list.contains(uid);
          }
          if (customCount != null) {
            _interestedCount = customCount;
          } else if (list.isNotEmpty) {
            _interestedCount = widget.event.interestedCount + list.length;
          }
        });
      }, onError: (e) => debugPrint('Live interested stream note: $e'));
    } catch (e) {
      debugPrint('Firestore live interested init note: $e');
    }
  }

  Future<void> _toggleLiveInterested() async {
    final nextState = !_isInterested;
    final diff = nextState ? 1 : -1;
    setState(() {
      _isInterested = nextState;
      _interestedCount = (_interestedCount + diff).clamp(0, 999999);
    });

    try {
      final uid = MiloSessionService.currentUid.isNotEmpty
          ? MiloSessionService.currentUid
          : 'guest_${DateTime.now().millisecondsSinceEpoch}';
      final db = FirebaseFirestore.instance;
      final docRef = db.collection('events').doc(widget.event.id);

      await docRef.set({
        'interested_count': _interestedCount,
        'interested_uids': nextState
            ? FieldValue.arrayUnion([uid])
            : FieldValue.arrayRemove([uid]),
        'last_voted_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Vote update error: $e');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: MiloColors.bgSurface,
        content: Text(
          nextState
              ? '👍 Your vote recorded! You are interested in this event.'
              : 'Vote removed from interested.',
          style: GoogleFonts.inter(
            color: nextState ? MiloColors.amber : MiloColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  final List<Map<String, String>> _datesList = [
    {"day": "Today", "date": "20 Sep", "status": "Filling Fast"},
    {"day": "Tomorrow", "date": "21 Sep", "status": "Available"},
    {"day": "Sunday", "date": "22 Sep", "status": "Selling Fast 🔥"},
  ];

  void _applyPromoCode(String code, StateSetter setModalState) {
    final clean = code.trim().toUpperCase();

    // 1. Check if it's a verified Promoter/Influencer Referral Code
    final promoterRef = MiloPromoterTrackingService.instance.findByCode(clean);
    if (promoterRef != null) {
      setModalState(() {
        _appliedPromoCode = clean;
        _discountAmount = 50.0; // Influencer special instant discount ₹50
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: MiloColors.bgSurface,
          content: Text('🎉 Influencer Referral Applied (${promoterRef.promoterName})! You saved ₹50 & ticket attributed.',
              style: GoogleFonts.inter(color: MiloColors.emerald, fontWeight: FontWeight.w700)),
        ),
      );
      return;
    }

    // 2. Check standard organizer coupons
    final matchingCoupon = widget.event.organizerCoupons.firstWhere(
      (c) => c.code.toUpperCase() == clean,
      orElse: () => const OrganizerCoupon(code: '', discountAmount: 0, description: ''),
    );

    if (matchingCoupon.code.isNotEmpty) {
      setModalState(() {
        _appliedPromoCode = clean;
        _discountAmount = matchingCoupon.discountAmount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: MiloColors.bgSurface,
          content: Text('🎉 Organizer promo code $clean applied! You saved ₹${_discountAmount.toStringAsFixed(0)}',
              style: GoogleFonts.inter(color: MiloColors.emerald, fontWeight: FontWeight.w700)),
        ),
      );
    } else {
      // Auto-accept as referral tag if promoter format
      setModalState(() {
        _appliedPromoCode = clean;
        _discountAmount = 40.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: MiloColors.bgSurface,
          content: Text('🏷️ Referral Code $clean attached! You saved ₹40.',
              style: GoogleFonts.inter(color: MiloColors.primaryLight, fontWeight: FontWeight.w700)),
        ),
      );
    }
  }

  void _showBookingBottomSheet() {
    final tier = widget.event.ticketTiers[_selectedTierIndex];
    final promoController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final baseSubtotal = tier.price * _quantity;
            final groupDiscount = _isGroupBooking && _quantity >= 3 ? (baseSubtotal * 0.10) : 0.0;
            final subtotal = baseSubtotal - groupDiscount - _discountAmount;
            const double bookingFee = 29.0;
            final total = (subtotal > 0 ? subtotal : 0) + bookingFee;

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: EdgeInsets.fromLTRB(22, 16, 22, MediaQuery.of(context).viewInsets.bottom + 24),
                  decoration: BoxDecoration(
                    color: MiloColors.bgSurface.withValues(alpha: 0.98),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    border: Border.all(color: MiloColors.glassBorder),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: MiloColors.textMuted.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Event & Tier Header
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.event.title,
                                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${widget.event.venue} • $_selectedDateIndex',
                                    style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: MiloColors.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  tier.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(color: MiloColors.primaryLight, fontSize: 11, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Fast-filling countdown banner
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: MiloColors.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: MiloColors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.bolt_rounded, color: MiloColors.amber, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'High demand! 18 people looking at this pass right now.',
                                  style: GoogleFonts.inter(color: MiloColors.amber, fontSize: 11, fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Quantity Selector with BMS-style Group Booking Switch
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Select Passes', style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                                  Text(
                                    'Instant digital M-Ticket on app',
                                    style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: MiloColors.bgCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: MiloColors.glassBorder),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, color: MiloColors.textPrimary, size: 18),
                                    onPressed: () {
                                      if (_quantity > 1) {
                                        setModalState(() => _quantity--);
                                        setState(() {});
                                      }
                                    },
                                  ),
                                  Text('$_quantity', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: MiloColors.primaryLight)),
                                  IconButton(
                                    icon: const Icon(Icons.add, color: MiloColors.primaryLight, size: 18),
                                    onPressed: () {
                                      if (_quantity < 10) {
                                        setModalState(() => _quantity++);
                                        setState(() {});
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Group Booking Perk Pill
                        if (_quantity >= 3)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: MiloColors.emerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: MiloColors.emerald.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.group_rounded, color: MiloColors.emerald, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Squad Bonus: 10% OFF applied for 3+ passes! 🎉',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Promo / Coupon Input
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: MiloColors.bgCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: MiloColors.glassBorder),
                                ),
                                child: TextField(
                                  controller: promoController,
                                  textCapitalization: TextCapitalization.characters,
                                  style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                                  decoration: InputDecoration(
                                    hintText: _appliedPromoCode != null
                                        ? 'Promo Applied: $_appliedPromoCode'
                                        : 'Enter Host Coupon Code',
                                    hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => _applyPromoCode(promoController.text, setModalState),
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: MiloColors.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: MiloColors.primaryLight),
                                ),
                                child: Center(
                                  child: Text(
                                    'APPLY',
                                    style: GoogleFonts.inter(color: MiloColors.primaryLight, fontWeight: FontWeight.w800, fontSize: 12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Bill Breakdown Card (BMS Style)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: MiloColors.bg.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: MiloColors.border),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${tier.name} (₹${tier.price.toStringAsFixed(0)} × $_quantity)',
                                      style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12)),
                                  Text('₹${baseSubtotal.toStringAsFixed(0)}',
                                      style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                ],
                              ),
                              if (groupDiscount > 0) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Squad Group Discount (10%)', style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 12)),
                                    Text('-₹${groupDiscount.toStringAsFixed(0)}',
                                        style: GoogleFonts.inter(color: MiloColors.emerald, fontWeight: FontWeight.w700, fontSize: 13)),
                                  ],
                                ),
                              ],
                              if (_discountAmount > 0) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Coupon ($_appliedPromoCode)', style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 12)),
                                    Text('-₹${_discountAmount.toStringAsFixed(0)}',
                                        style: GoogleFonts.inter(color: MiloColors.emerald, fontWeight: FontWeight.w700, fontSize: 13)),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Convenience & Safety Fee', style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12)),
                                  Text('₹${bookingFee.toStringAsFixed(0)}',
                                      style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                ],
                              ),
                              const Divider(color: MiloColors.border, height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total Amount',
                                      style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 15)),
                                  Text(
                                    '₹${total.toStringAsFixed(0)}',
                                    style: GoogleFonts.inter(color: MiloColors.emerald, fontWeight: FontWeight.w900, fontSize: 22),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Self Payment Gateway Launch Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MiloColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 6,
                              shadowColor: MiloColors.primaryGlow,
                            ),
                            onPressed: () {
                              Navigator.pop(context); // Close summary sheet
                              MiloBmsPaymentSheet.show(
                                context,
                                event: widget.event,
                                tier: tier,
                                quantity: _quantity,
                                totalAmount: total,
                                referralCode: _appliedPromoCode,
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.bolt_rounded, color: MiloColors.textPrimary, size: 22),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Proceed to Book Passes • ₹${total.toStringAsFixed(0)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: MiloColors.textPrimary, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            '🛡️ 100% Refund Guarantee if event is cancelled or rescheduled',
                            style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    return Scaffold(
      backgroundColor: MiloColors.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Sliver AppBar with Collapsible Header ──
          SliverAppBar(
            expandedHeight: 290,
            pinned: true,
            backgroundColor: MiloColors.bgSurface,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MiloColors.bgSurface.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: MiloColors.textPrimary, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MiloColors.bgSurface.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _isFavorite ? MiloColors.rose : MiloColors.textPrimary,
                    size: 18,
                  ),
                ),
                onPressed: () async {
                  final added = await MiloWishlistService.instance.toggle(
                    MiloSessionService.currentUid,
                    widget.event.id,
                  );
                  if (!mounted) return;
                  setState(() {
                    _isFavorite = added;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: MiloColors.bgSurface,
                      content: Text(
                        added
                            ? '❤️ Event saved to your Wishlist!'
                            : 'Removed from your Wishlist.',
                        style: GoogleFonts.inter(
                          color: added ? MiloColors.rose : MiloColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MiloColors.bgSurface.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share_outlined, color: MiloColors.textPrimary, size: 18),
                ),
                onPressed: () {
                  final shareUrl = MiloConfig.eventLink(event.id);
                  final shareText =
                      'Hey! Check out "${event.title}" at ${event.venue}.\n\nBook your verified tickets & join the squad on JHOOMO:\n$shareUrl';
                  Share.share(
                    shareText,
                    subject: 'Tickets for ${event.title} on JHOOMO',
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    event.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: MiloColors.bgCard),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, MiloColors.bg.withValues(alpha: 0.7), MiloColors.bg],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.3, 0.7, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: MiloColors.primary.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: MiloColors.primaryLight),
                              ),
                              child: Text(
                                event.category.toUpperCase(),
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: MiloColors.primaryLight),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: MiloColors.emerald.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.verified_rounded, color: MiloColors.emerald, size: 12),
                                  const SizedBox(width: 4),
                                  Text('JHOOMO Verified Partner', style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 10, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          event.title,
                          style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2),
                        ),
                        const SizedBox(height: 10),
                        // BMS-Style Meta Pills (Language, Duration, Age)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildMetaPill(event.language, Icons.translate_rounded),
                            _buildMetaPill(event.duration, Icons.timer_outlined),
                            _buildMetaPill(event.ageLimit, Icons.person_outline_rounded),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Interactive Interested & Bookmark Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.thumb_up_alt_rounded, color: MiloColors.amber, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$_interestedCount are interested',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: _toggleLiveInterested,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _isInterested ? MiloColors.amber : Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _isInterested ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                                        color: _isInterested ? Colors.black87 : Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isInterested ? 'Voted ✓' : 'Interested',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: _isInterested ? Colors.black87 : Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
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
            ),
          ),

          // ── BMS-Style Date / Slot Selector ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Show Date & Time 📅', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 70,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _datesList.length,
                      itemBuilder: (context, index) {
                        final item = _datesList[index];
                        final isSelected = _selectedDateIndex == item['day'];

                        return GestureDetector(
                          onTap: () => setState(() => _selectedDateIndex = item['day']!),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 130,
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected ? MiloColors.primary.withValues(alpha: 0.2) : MiloColors.bgSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? MiloColors.primaryLight : MiloColors.glassBorder,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item['day']!,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? MiloColors.primaryLight : MiloColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(item['date']!, style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
                                    Text(
                                      item['status']!,
                                      style: GoogleFonts.inter(
                                        color: item['status']!.contains('Fast') ? MiloColors.amber : MiloColors.emerald,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Main Body Details ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Organizer & Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: MiloColors.bgCard,
                              child: const Icon(Icons.verified, color: MiloColors.primaryLight, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.organizerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: MiloColors.textPrimary, fontSize: 14),
                                  ),
                                  Text('Verified Host • 4.9 ★ Host Rating', style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: MiloColors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: MiloColors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, color: MiloColors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text('${event.rating}', style: GoogleFonts.inter(color: MiloColors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Venue & Time Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MiloColors.bgSurface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MiloColors.glassBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: MiloColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.access_time_filled_rounded, color: MiloColors.primaryLight, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${event.date} • ${event.time}', style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                                Text('Gates open 60 mins before start', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                        const Divider(color: MiloColors.border, height: 22),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: MiloColors.rose.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.location_on_rounded, color: MiloColors.rose, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(event.venue, style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                                  Text(
                                    event.landmarkAddress.isNotEmpty
                                        ? '${event.venue}, ${event.landmarkAddress}'
                                        : '${event.city}, India • Monitored Free Parking',
                                    style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: MiloColors.bgSurface,
                                    content: Text('Opening Google Maps Directions for ${event.venue}... 🗺️', style: GoogleFonts.inter(color: MiloColors.cyan, fontWeight: FontWeight.w700)),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: MiloColors.cyan.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: MiloColors.cyan.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.directions_rounded, color: MiloColors.cyan, size: 14),
                                    const SizedBox(width: 4),
                                    Text('Directions', style: GoogleFonts.inter(color: MiloColors.cyan, fontSize: 11, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── 1. SPOTLIGHT: WHY THIS EVENT STANDS OUT ──
                  Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2A2415),
                          const Color(0xFF16161D),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE5A93C).withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5A93C).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFE5A93C), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Why this event stands out',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFE5A93C),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                event.highlights.isNotEmpty
                                    ? event.highlights.first
                                    : 'An Unforgettable Live Multi-Day Festival & Arena Experience in ${event.city}!',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── 2. DAY 1 & DAY 2 LINEUP (RICH HORIZONTAL CAROUSELS) ──
                  _buildDayLineupSection(
                    dayTitle: 'Day 1 – Lineup',
                    artists: [
                      {
                        'name': 'DIVINE / Gully Gang',
                        'role': 'Hip-Hop Headliner',
                        'image': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=400&q=80',
                      },
                      {
                        'name': 'Karan Kanchan',
                        'role': 'Music Producer & DJ',
                        'image': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
                      },
                      {
                        'name': 'MC Altaf',
                        'role': 'Rapper / Lyricist',
                        'image': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
                      },
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDayLineupSection(
                    dayTitle: 'Day 2 – Lineup',
                    artists: [
                      {
                        'name': 'Sunidhi Chauhan',
                        'role': 'Bollywood Superstar',
                        'image': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=400&q=80',
                      },
                      {
                        'name': 'Prateek Kuhad',
                        'role': 'Indie / Singer-Songwriter',
                        'image': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
                      },
                      {
                        'name': 'When Chai Met Toast',
                        'role': 'Indie Folk Band',
                        'image': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=400&q=80',
                      },
                    ],
                  ),
                  const SizedBox(height: 22),

                  // ── 3. FACILITIES AT THE EVENT (ICON GRID WITH SUBTITLES) ──
                  Text(
                    'Facilities at the event',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: MiloColors.bgSurface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MiloColors.glassBorder),
                    ),
                    child: Column(
                      children: [
                        _buildFacilityRow(
                          icon: Icons.local_parking_rounded,
                          title: 'Paid parking available',
                          subtitle: 'Ample multi-level car and bike parking on-site.',
                        ),
                        const Divider(color: MiloColors.border, height: 20),
                        _buildFacilityRow(
                          icon: Icons.fastfood_rounded,
                          title: 'Food and drinks can be purchased',
                          subtitle: 'Veg and non-veg options with curated food stalls & hydration points.',
                        ),
                        const Divider(color: MiloColors.border, height: 20),
                        _buildFacilityRow(
                          icon: Icons.accessible_rounded,
                          title: 'Fully wheelchair accessible',
                          subtitle: 'Dedicated ramps & elevators for companion and wheelchair access.',
                        ),
                        const Divider(color: MiloColors.border, height: 20),
                        _buildFacilityRow(
                          icon: Icons.medical_services_rounded,
                          title: 'Medical support & First-aid with ambulance',
                          subtitle: '24/7 Paramedic squad on-site with rapid-response ambulance.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── 4. THINGS TO KNOW (CLEAN BULLET RULES BOX) ──
                  Text(
                    'Things to know',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MiloColors.bgSurface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MiloColors.glassBorder),
                    ),
                    child: Column(
                      children: [
                        _buildRuleBullet('Entry strictly allowed for ages 8 and above.'),
                        _buildRuleBullet('Ticket required for ages 8 and above.'),
                        _buildRuleBullet('Outside food, beverages, and pets are not allowed.'),
                        _buildRuleBullet('Valid Government ID (Aadhaar / PAN / Passport) required for entry.'),
                        _buildRuleBullet('Allowed dress code: Smart Casuals & comfortable footwear.'),
                        _buildRuleBullet('Outdoor festival arena with standing zones; VIP lounge has seated tables.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── 5. ORGANISED BY (RICH VERIFIED HOST CARD) ──
                  Text(
                    'Organised by',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MiloColors.bgSurface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MiloColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: MiloColors.primary.withValues(alpha: 0.2),
                          child: const Icon(Icons.business_center_rounded, color: MiloColors.primaryLight, size: 28),
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
                                      event.organizerName.isNotEmpty ? event.organizerName : 'Antimbre Private Limited',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: MiloColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified_rounded, color: MiloColors.emerald, size: 16),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Official Partner • 4.9 ★ Rating • 18+ Live Shows Hosted',
                                style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // 30-Min Auto Reminder Indicator Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MiloColors.emerald.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: MiloColors.emerald.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.alarm_on_rounded, color: MiloColors.emerald, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Automatic 30-Min Alert: Jhoomo will notify you with the Google Maps route 30 mins before showtime! 🔔',
                            style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 11, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── WHO IS COMING / CONFIRMED ATTENDEES PREVIEW ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MiloColors.bgSurface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MiloColors.glassBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.people_alt_rounded, color: MiloColors.cyan, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Who is Coming? (${widget.event.confirmedAttendeesCount}+ Confirmed)',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
                                ),
                              ],
                            ),
                            Text('Live Attendees', style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Overlapping avatar stack
                            SizedBox(
                              width: 120,
                              height: 36,
                              child: Stack(
                                children: const [
                                  Positioned(
                                    left: 0,
                                    child: CircleAvatar(
                                      radius: 17,
                                      backgroundImage: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=100&q=80'),
                                    ),
                                  ),
                                  Positioned(
                                    left: 24,
                                    child: CircleAvatar(
                                      radius: 17,
                                      backgroundImage: NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=100&q=80'),
                                    ),
                                  ),
                                  Positioned(
                                    left: 48,
                                    child: CircleAvatar(
                                      radius: 17,
                                      backgroundImage: NetworkImage('https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=100&q=80'),
                                    ),
                                  ),
                                  Positioned(
                                    left: 72,
                                    child: CircleAvatar(
                                      radius: 17,
                                      backgroundColor: MiloColors.primary,
                                      child: Text('+178', style: TextStyle(color: MiloColors.bg, fontSize: 10, fontWeight: FontWeight.w900)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Verified college squads, couples, & solo attendees have booked passes!',
                                style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 11, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── OFFICIAL HOST BROADCAST CHANNEL LAUNCHER ──
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HostBroadcastChannelScreen(event: event),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
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
                        border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: MiloColors.primary.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.campaign_rounded, color: MiloColors.primaryLight, size: 22),
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
                                        'Host Broadcast Channel',
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: MiloColors.emerald.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text('LIVE', style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 9, fontWeight: FontWeight.w900)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Only organizer posts live SMS & announcements. All joined attendees get instant updates.',
                                  style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 14, color: MiloColors.primaryLight),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Event Perks & BMS Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTag('Free Dandiya Sticks', Icons.check_circle_outline),
                      _buildTag('Live DJ & Dhol', Icons.music_note_rounded),
                      _buildTag('Food Stalls', Icons.fastfood_outlined),
                      _buildTag('High Security', Icons.security_rounded),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // About Event
                  Text('About Experience', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
                  const SizedBox(height: 6),
                  Text(
                    event.description,
                    style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  // Select Ticket Tier (Interactive Pricing Cards)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Choose Ticket Category', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
                      Text('Instant QR', style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(event.ticketTiers.length, (index) {
                    final tier = event.ticketTiers[index];
                    final isSelected = _selectedTierIndex == index;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedTierIndex = index),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? MiloColors.bgCardHover : MiloColors.bgSurface.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? MiloColors.primaryLight : MiloColors.glassBorder,
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: MiloColors.primary.withValues(alpha: 0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                        color: isSelected ? MiloColors.primaryLight : MiloColors.textMuted,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(tier.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('₹${tier.price.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900, color: MiloColors.primaryLight)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 30),
                              child: Text(tier.description, style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12)),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(left: 30),
                              child: Wrap(
                                spacing: 8,
                                children: tier.perks.map((p) {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_rounded, size: 13, color: MiloColors.emerald),
                                      const SizedBox(width: 4),
                                      Text(p, style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),

                  // ── 1. WHY YOU SHOULD ATTEND (HIGHLIGHTS CARDS) ──
                  if (event.highlights.isNotEmpty) ...[
                    Text('Why You Should Attend 🌟', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
                    const SizedBox(height: 10),
                    ...event.highlights.map((highlight) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MiloColors.bgSurface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: MiloColors.glassBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: MiloColors.primary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.star_rounded, color: MiloColors.primaryLight, size: 14),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                highlight,
                                style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 12, height: 1.4, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 20),
                  ],

                  // ── 2. ARTIST & PERFORMER LINEUP ──
                  if (event.performers.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Artist Lineup 🎧', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
                        Text('${event.performers.length} Performers', style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 125,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: event.performers.length,
                        itemBuilder: (context, idx) {
                          final p = event.performers[idx];
                          return Container(
                            width: 110,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: MiloColors.bgSurface.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: MiloColors.glassBorder),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundImage: NetworkImage(p['image'] ?? 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=300&q=80'),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  p['name'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: MiloColors.textPrimary),
                                ),
                                Text(
                                  p['role'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontSize: 9, color: MiloColors.textMuted),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── 3. INCLUSIONS & EXCLUSIONS GRID ──
                  if (event.inclusions.isNotEmpty || event.exclusions.isNotEmpty) ...[
                    Text("What's Included & Excluded 📋", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: MiloColors.bgSurface.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: MiloColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (event.inclusions.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: MiloColors.emerald, size: 16),
                                const SizedBox(width: 6),
                                Text('INCLUDED WITH PASS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: MiloColors.emerald)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ...event.inclusions.map((inc) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 6, bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(color: MiloColors.emerald, fontWeight: FontWeight.bold)),
                                    Expanded(
                                      child: Text(inc, style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textSecondary)),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                          if (event.inclusions.isNotEmpty && event.exclusions.isNotEmpty)
                            const Divider(color: MiloColors.border, height: 18),
                          if (event.exclusions.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.cancel_rounded, color: MiloColors.rose, size: 16),
                                const SizedBox(width: 6),
                                Text('NOT INCLUDED / RESTRICTIONS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: MiloColors.rose)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ...event.exclusions.map((exc) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 6, bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(color: MiloColors.rose, fontWeight: FontWeight.bold)),
                                    Expanded(
                                      child: Text(exc, style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textSecondary)),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],

                  // ── 4. INTERACTIVE FAQS ACCORDION ──
                  if (event.faqs.isNotEmpty) ...[
                    Text('Frequently Asked Questions ❓', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
                    const SizedBox(height: 10),
                    ...List.generate(event.faqs.length, (idx) {
                      final item = event.faqs[idx];
                      final isExpanded = _expandedFaqIndex == idx;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: MiloColors.bgSurface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isExpanded ? MiloColors.primaryLight : MiloColors.glassBorder,
                          ),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                            onExpansionChanged: (expanded) {
                              setState(() {
                                _expandedFaqIndex = expanded ? idx : null;
                              });
                            },
                            title: Text(
                              item['q'] ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isExpanded ? MiloColors.primaryLight : MiloColors.textPrimary,
                              ),
                            ),
                            children: [
                              Text(
                                item['a'] ?? '',
                                style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textSecondary, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                  ],

                  // Organizer Venue Rules & Custom Terms
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MiloColors.bgSurface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MiloColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: MiloColors.amber, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Host Venue Guidelines & Rules',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          event.customTermsAndConditions.isNotEmpty
                              ? event.customTermsAndConditions
                              : '1. Entry strictly with JHOOMO digital M-Ticket QR pass.\n2. Organizer reserves right of admission.\n3. Passes are non-refundable except in official event cancellations.\n4. Age restrictions and security checks apply at venue entrance.',
                          style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Fixed Bottom Bar with Live Total & Instant Checkout ──
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: MiloColors.bgSurface.withValues(alpha: 0.95),
          border: const Border(top: BorderSide(color: MiloColors.border)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Category Price', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
                  Text(
                    '₹${event.ticketTiers[_selectedTierIndex].price.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(color: MiloColors.primaryLight, fontWeight: FontWeight.w900, fontSize: 22),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MiloColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 6,
                      shadowColor: MiloColors.primaryGlow,
                    ),
                    onPressed: _showBookingBottomSheet,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.confirmation_number_rounded, color: MiloColors.bg, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Book Passes',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: MiloColors.bg, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaPill(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: MiloColors.primaryLight),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: MiloColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MiloColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: MiloColors.primaryLight),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
  Widget _buildDayLineupSection({required String dayTitle, required List<Map<String, String>> artists}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              dayTitle,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
            ),
            Text(
              'Explore full lineup ›',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: MiloColors.primaryLight),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: artists.length,
            itemBuilder: (context, idx) {
              final a = artists[idx];
              return Container(
                width: 150,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: MiloColors.bgSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: MiloColors.glassBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                      child: Stack(
                        children: [
                          Image.network(
                            a['image']!,
                            height: 140,
                            width: 150,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(height: 140, color: MiloColors.bgCard),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.bookmark_border_rounded, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a['name']!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            a['role']!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 10, color: MiloColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFacilityRow({required IconData icon, required String title, required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: MiloColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: MiloColors.primaryLight, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: MiloColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textMuted, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRuleBullet(String rule) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: MiloColors.primaryLight, fontSize: 14, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              rule,
              style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

}
