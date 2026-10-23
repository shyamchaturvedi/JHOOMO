class EventModel {
 final String id;
 final String title;
 final String category;
 final String date;
 final String time;
 final String venue;
 final String city;
 final String googleMapsUrl;
 final double startingPrice;
 final String imageUrl;
 final String organizerName;
 final bool isVerifiedOrganizer;
 final double rating;
 final List<String> tags;
 final int ticketsLeft;
 final bool isTrending;
 final String description;
 final List<TicketTier> ticketTiers;
 final List<OrganizerCoupon> organizerCoupons;
 final String customTermsAndConditions;
 final bool autoReminder30Min;

 const EventModel({
 required this.id,
 required this.title,
 required this.category,
 required this.date,
 required this.time,
 required this.venue,
 required this.city,
 this.googleMapsUrl = 'https://maps.google.com/?q=Event+Venue',
 required this.startingPrice,
 required this.imageUrl,
 required this.organizerName,
 this.isVerifiedOrganizer = true,
 this.rating = 4.8,
 required this.tags,
 required this.ticketsLeft,
 this.isTrending = false,
 required this.description,
 required this.ticketTiers,
 this.organizerCoupons = const [],
 this.customTermsAndConditions = '',
 this.autoReminder30Min = true,
 });
}

class OrganizerCoupon {
 final String code;
 final double discountAmount;
 final double minOrderValue;
 final String description;

 const OrganizerCoupon({
 required this.code,
 required this.discountAmount,
 this.minOrderValue = 0,
 required this.description,
 });
}

class TicketTier {
 final String id;
 final String name;
 final double price;
 final String description;
 final List<String> perks;
 final int available;

 const TicketTier({
 required this.id,
 required this.name,
 required this.price,
 required this.description,
 required this.perks,
 required this.available,
 });
}

class UserModel {
 final String id;
 final String name;
 final int age;
 final String city;
 final String bio;
 final String avatarUrl;
 final List<String> vibes;
 final List<String> interests;
 final String mutualEvent;
 final bool isOnline;
 final bool isVerified;
 final String lookingFor;
 final String matchCategory;
 // Rapido Captain-Style Trust & Reputation Metrics
 final int meetupsCount; // e.g. 48 Meetups Completed
 final double rating; // e.g. 4.92 / 5.0 
 final int ratingCount; // e.g. 84 Ratings
 final String badgeLevel; // e.g. 'Super Captain ' or 'Gold Host ' or 'Trusted Explorer '
 final int reliabilityScore; // e.g. 99% On-time & Friendly
 final List<String> complimentBadges; // e.g. ['Punctual ⏱', 'Great Vibe ', 'Super Host ', 'Safe & Polite ']

 const UserModel({
 required this.id,
 required this.name,
 required this.age,
 required this.city,
 required this.bio,
 required this.avatarUrl,
 required this.vibes,
 required this.interests,
 this.mutualEvent = '',
 this.isOnline = false,
 this.isVerified = true,
 this.lookingFor = 'Meetup & Hangout ',
 this.matchCategory = 'Social',
 this.meetupsCount = 24,
 this.rating = 4.88,
 this.ratingCount = 38,
 this.badgeLevel = 'Super Captain ',
 this.reliabilityScore = 98,
 this.complimentBadges = const ['Punctual ⏱', 'Great Vibe ', 'Safe & Polite '],
 });
}

class BeaconModel {
 final String id;
 final String userName;
 final String userAvatar;
 final String title;
 final String activity;
 final String location;
 final String googleMapsUrl;
 final String timeAgo;
 final int spotsLeft;
 final String tag;
 final bool autoReminder30Min;

 const BeaconModel({
 required this.id,
 required this.userName,
 required this.userAvatar,
 required this.title,
 required this.activity,
 required this.location,
 this.googleMapsUrl = 'https://maps.google.com/?q=Meetup+Spot',
 required this.timeAgo,
 required this.spotsLeft,
 required this.tag,
 this.autoReminder30Min = true,
 });
}


class BookedTicket {
 final String bookingId;
 final EventModel event;
 final TicketTier tier;
 final int quantity;
 final double totalAmount;
 final String bookingTime;
 final String qrData;
 final String status; // 'CONFIRMED' | 'PENDING_APPROVAL' | 'REJECTED'
 final String paymentMethod;
 final String utrNumber;
 final String organizerUpiId;
 final String attendeeName;
 final String attendeePhone;
 final String paymentProofUrl;
 final String rejectionReason;
 final String uid; // Firebase UID of the buyer (empty = demo/legacy data)
 final bool checkedIn;

 const BookedTicket({
 required this.bookingId,
 required this.event,
 required this.tier,
 required this.quantity,
 required this.totalAmount,
 required this.bookingTime,
 required this.qrData,
 this.status = 'CONFIRMED',
 this.paymentMethod = 'SELF_UPI',
 this.utrNumber = '',
 this.organizerUpiId = 'utsav.events@okhdfcbank',
 this.attendeeName = 'Sahil (Verified Member)',
 this.attendeePhone = '+91 98765 43210',
 this.paymentProofUrl = '',
 this.rejectionReason = '',
 this.uid = '',
 this.checkedIn = false,
 });

 BookedTicket copyWith({
 String? status,
 String? utrNumber,
 String? paymentProofUrl,
 String? rejectionReason,
 String? uid,
 bool? checkedIn,
 }) {
 return BookedTicket(
 bookingId: bookingId,
 event: event,
 tier: tier,
 quantity: quantity,
 totalAmount: totalAmount,
 bookingTime: bookingTime,
 qrData: qrData,
 status: status ?? this.status,
 paymentMethod: paymentMethod,
 utrNumber: utrNumber ?? this.utrNumber,
 organizerUpiId: organizerUpiId,
 attendeeName: attendeeName,
 attendeePhone: attendeePhone,
 paymentProofUrl: paymentProofUrl ?? this.paymentProofUrl,
 rejectionReason: rejectionReason ?? this.rejectionReason,
 uid: uid ?? this.uid,
 checkedIn: checkedIn ?? this.checkedIn,
 );
 }
}

class PaymentApprovalRequest {
 final String id;
 final String bookingId;
 final String eventId;
 final String eventTitle;
 final String tierName;
 final int quantity;
 final double totalAmount;
 final String attendeeName;
 final String attendeePhone;
 final String utrNumber;
 final String organizerUpiId;
 final String timestamp;
 final String status; // 'PENDING' | 'APPROVED' | 'REJECTED'
 final String proofImageUrl;
 final String note;
 final String rejectionReason;

 const PaymentApprovalRequest({
 required this.id,
 required this.bookingId,
 required this.eventId,
 required this.eventTitle,
 required this.tierName,
 required this.quantity,
 required this.totalAmount,
 required this.attendeeName,
 required this.attendeePhone,
 required this.utrNumber,
 required this.organizerUpiId,
 required this.timestamp,
 this.status = 'PENDING',
 this.proofImageUrl = '',
 this.note = '',
 this.rejectionReason = '',
 });

 PaymentApprovalRequest copyWith({
 String? status,
 String? rejectionReason,
 }) {
 return PaymentApprovalRequest(
 id: id,
 bookingId: bookingId,
 eventId: eventId,
 eventTitle: eventTitle,
 tierName: tierName,
 quantity: quantity,
 totalAmount: totalAmount,
 attendeeName: attendeeName,
 attendeePhone: attendeePhone,
 utrNumber: utrNumber,
 organizerUpiId: organizerUpiId,
 timestamp: timestamp,
 status: status ?? this.status,
 proofImageUrl: proofImageUrl,
 note: note,
 rejectionReason: rejectionReason ?? this.rejectionReason,
 );
 }
}

class CommunityComment {
 final String id;
 final String authorName;
 final String authorRole;
 final String authorAvatar;
 final String text;
 final String timeAgo;

 const CommunityComment({
 required this.id,
 required this.authorName,
 required this.authorRole,
 required this.authorAvatar,
 required this.text,
 required this.timeAgo,
 });
}

class CommunityPost {
 final String id;
 final String authorName;
 final String authorRole; // 'ORGANIZER' | 'INFLUENCER' | 'ARTIST' | 'SPONSOR' | 'ATTENDEE'
 final String roleBadge;
 final String authorAvatar;
 final String content;
 final String? eventTag;
 final String? eventId;
 final String timeAgo;
 final int likesCount;
 final bool isLiked;
 final int commentsCount;
 final String? mediaUrl;
  final bool isCollabOpen;
  final String? collabType;
  final List<CommunityComment> comments;

  // Official Collab & Affiliate Protocol fields (Organizer Approved)
  final String? socialHandle; // e.g. '@riya_lifestyle'
  final String? officialPromoCode; // Organizer authorized code
  final double organizerApprovedDiscount; // e.g. 20.0 (Organizer set only)
  final bool isOfficialCollab; // True if accepted by organizer
  final int bookingsViaCreatorCount; // Live counter e.g. 42

  const CommunityPost({
    required this.id,
    required this.authorName,
    required this.authorRole,
    required this.roleBadge,
    required this.authorAvatar,
    required this.content,
    this.eventTag,
    this.eventId,
    required this.timeAgo,
    this.likesCount = 0,
    this.isLiked = false,
    this.commentsCount = 0,
    this.mediaUrl,
    this.isCollabOpen = false,
    this.collabType,
    this.comments = const [],
    this.socialHandle,
    this.officialPromoCode,
    this.organizerApprovedDiscount = 0.0,
    this.isOfficialCollab = false,
    this.bookingsViaCreatorCount = 0,
  });

  CommunityPost copyWith({
    int? likesCount,
    bool? isLiked,
    int? commentsCount,
    List<CommunityComment>? comments,
    int? bookingsViaCreatorCount,
  }) {
    return CommunityPost(
      id: id,
      authorName: authorName,
      authorRole: authorRole,
      roleBadge: roleBadge,
      authorAvatar: authorAvatar,
      content: content,
      eventTag: eventTag,
      eventId: eventId,
      timeAgo: timeAgo,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
      commentsCount: commentsCount ?? this.commentsCount,
      mediaUrl: mediaUrl,
      isCollabOpen: isCollabOpen,
      collabType: collabType,
      comments: comments ?? this.comments,
      socialHandle: socialHandle,
      officialPromoCode: officialPromoCode,
      organizerApprovedDiscount: organizerApprovedDiscount,
      isOfficialCollab: isOfficialCollab,
      bookingsViaCreatorCount: bookingsViaCreatorCount ?? this.bookingsViaCreatorCount,
    );
  }
}

