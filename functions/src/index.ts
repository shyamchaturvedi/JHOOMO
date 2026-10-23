import { setGlobalOptions } from 'firebase-functions/v2';
import { logger } from 'firebase-functions';

setGlobalOptions({ region: 'asia-south1', maxInstances: 20 });

export {
  bootstrapUser,
  completeProfile,
  linkEmail,
  exportMyData,
  requestAccountDeletion,
  cancelAccountDeletion,
  confirmFaceVerification,
} from './customer/account';

export { becomePromoter, requestPromoterPayout } from './customer/promoter';

export { createBooking, applyPromo, cancelPendingBooking } from './booking/booking';
export { getTicketQrToken, generateTicketPdf } from './booking/tickets';
export { requestRefund, organizerApproveRefund, organizerRejectRefund } from './booking/refunds';
export { razorpayWebhook } from './booking/webhooks';

export {
  saveKycDraft,
  verifyPanCallable,
  verifyBankCallable,
  sendEmailCodeCallable,
  verifyEmailCodeCallable,
  submitKyc,
  getKycStatus,
} from './organizer/kyc';

export {
  saveEventDraft,
  submitEventForReview,
  updateLiveEvent,
  cancelEvent,
  createPromoCode,
  listMyEvents,
} from './organizer/events';

export { listEvents, searchEvents, getEventDetails, toggleWishlist, listWishlist } from './events/discovery';
export { onEventWrite, onTierShardWrite } from './events/triggers';

export {
  createStaffPasscode,
  revokeStaff,
  listStaff,
  staffLogin,
  endGateSession,
} from './gate/staff';

export {
  gateCheckIn,
  manualLookup,
  admitManualLookup,
  getGateManifest,
  syncOfflineCheckins,
} from './gate/checkin';

export { settlementRun, approveSettlement, listSettlements } from './settlement/run';

export {
  expireReservations,
  eventReminders,
  computeTrendScore,
  accountDeletionJob,
  completeFinishedEvents,
  lockGroupChats,
  archiveChats,
  expireBeacons,
} from './scheduler/jobs';

export {
  setRadarOptIn,
  listRadarMembers,
  sendConnectionRequest,
  respondConnection,
  listConnections,
  blockUser,
  submitReport,
} from './social/radar';

export { createBeacon, joinBeacon, listBeacons } from './social/beacons';

export {
  createCommunityPost,
  toggleCommunityLike,
  addCommunityComment,
  deleteCommunityComment,
  shareCommunityPost,
  requestCommunityCollab,
} from './social/community';

export {
  listChats,
  getChatMessages,
  sendMessage,
  markChatRead,
  deleteMessage,
  joinEventGroupChat,
  moderateChat,
} from './social/chat';

export { triggerSOS, updateSOSLocation, resolveSOS } from './safety/sos';

export {
  updatePrivacy,
  addEmergencyContact,
  confirmEmergencyContact,
  listEmergencyContacts,
  removeEmergencyContact,
  testEmergencyAlert,
} from './profile/privacy';

export {
  listNotifications,
  markNotificationRead,
  markAllNotificationsRead,
  deleteNotification,
  registerDevice,
  unregisterDevice,
  updateNotificationPrefs,
  listHelpArticles,
} from './notifications/center';

export {
  createSupportTicket,
  listMySupportTickets,
  getSupportTicket,
  replySupportTicket,
  adminListSupportTickets,
  adminReplySupportTicket,
} from './support/help';

export {
  adminDashboardStats,
  adminReviewKyc,
  adminReviewEvent,
  adminDecideRefund,
  adminReleaseSettlement,
  adminFraudAction,
  adminUserAction,
  adminPromoterAction,
  adminUpdateConfig,
  adminSendCampaign,
  adminListReports,
  adminResolveReport,
  adminListAuditLogs,
  adminListKycQueue,
  adminListEventQueue,
  adminListRefunds,
  adminListSettlements,
  adminListPromoters,
  adminSearchUsers,
  adminGetConfig,
  adminListFraudFlags,
} from './admin/console';

export { referralRedirect, sosTrackingPage, confirmEmergencyContactLink } from './web/public';

logger.info('milo.functions.loaded');
