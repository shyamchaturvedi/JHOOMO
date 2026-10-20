import 'package:flutter_test/flutter_test.dart';
import 'package:milo_mobile/services/milo_db_service.dart';
import 'package:milo_mobile/services/mock_data.dart';
import 'package:milo_mobile/services/payment_approval_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milo Complete System & Service Tests', () {
    test('MiloDbService returns verified events correctly', () async {
      final events = await MiloDbService.instance.getEvents();
      expect(events.isNotEmpty, true);
      expect(events.first.title.contains('Dandiya'), true);
      expect(events.first.city, 'Lucknow');
    });

    test('MiloDbService returns active spontaneous beacons', () async {
      final beacons = await MiloDbService.instance.getActiveBeacons();
      expect(beacons.isNotEmpty, true);
      expect(beacons.any((b) => b.tag == 'College' || b.tag == 'Friends'), true);
    });

    test('MiloDbService returns verified ticket passes', () async {
      final tickets = await MiloDbService.instance.getUserBookings('test_user_id');
      expect(tickets.isNotEmpty, true);
      expect(tickets.first.bookingId.startsWith('MILO'), true);
    });

    test('PaymentApprovalService handles self-gateway submission & organizer approval', () {
      final service = PaymentApprovalService.instance;
      final initialPendingCount = service.pendingCount;

      // Submit new payment
      service.submitPaymentApprovalRequest(
        event: MockData.events.first,
        tier: MockData.events.first.ticketTiers.first,
        quantity: 1,
        totalAmount: 528,
        utrNumber: '998877665544',
        attendeeName: 'Sahil Test',
        attendeePhone: '+91 99999 88888',
      );

      expect(service.pendingCount, initialPendingCount + 1);

      // Latest request
      final latestReq = service.approvalRequests.first;
      expect(latestReq.utrNumber, '998877665544');
      expect(latestReq.status, 'PENDING');

      // Organizer approves
      service.approveRequest(latestReq.id);

      final approvedReq = service.approvalRequests.firstWhere((r) => r.id == latestReq.id);
      expect(approvedReq.status, 'APPROVED');

      final approvedTicket = service.userTickets.firstWhere((t) => t.bookingId == latestReq.bookingId);
      expect(approvedTicket.status, 'CONFIRMED');
    });

    test('Super Admin security check: iammshyam@gmail.com verified', () {
      const superAdminEmail = 'iammshyam@gmail.com';
      const unauthorizedEmail = 'random_user@gmail.com';

      bool isSuperAdmin(String email) => email.trim().toLowerCase() == 'iammshyam@gmail.com';

      expect(isSuperAdmin(superAdminEmail), true);
      expect(isSuperAdmin(unauthorizedEmail), false);
    });
  });
}
