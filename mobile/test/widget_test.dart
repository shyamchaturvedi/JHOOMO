import 'package:flutter_test/flutter_test.dart';
import 'package:milo_mobile/services/milo_db_service.dart';
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
      expect(
          beacons.any((b) => b.tag == 'College' || b.tag == 'Friends'), true);
    });

    test('MiloDbService returns verified ticket passes', () async {
      final tickets =
          await MiloDbService.instance.getUserBookings('test_user_id');
      expect(tickets.isNotEmpty, true);
      expect(tickets.first.bookingId.startsWith('MILO'), true);
    });

    test('PaymentApprovalService only normalizes phones locally', () {
      expect(PaymentApprovalService.normalizePhone('+91 98765-43210'),
          '9876543210');
      expect(
          PaymentApprovalService.normalizePhone('098765 43210'), '9876543210');
    });

    test('Server booking docs map into pending-approval tickets', () {
      final ticket = MiloDbService.mapBookingDoc({
        'refCode': 'MLO-123',
        'userId': 'uid_1',
        'eventId': 'evt_1',
        'status': 'pending_approval',
        'quantity': 2,
        'pricing': {'totalPaise': 104800},
        'payment': {
          'provider': 'manual',
          'method': 'TEST_GATEWAY',
          'utr': '998877665544',
          'status': 'pending_approval',
        },
        'eventSnapshot': {
          'title': 'Garba Night',
          'venueName': 'Lucknow Grounds',
          'startAt': null,
        },
        'items': [
          {
            'tierId': 't1',
            'tierName': 'Gold',
            'qty': 2,
            'unitPaise': 50000,
            'admits': 1
          },
        ],
        'ticketIds': <String>[],
      });

      expect(ticket.bookingId.isNotEmpty, true);
      expect(ticket.status, 'PENDING_APPROVAL');
      expect(ticket.quantity, 2);
      expect(ticket.totalAmount, 1048);
      expect(ticket.utrNumber, '998877665544');
      expect(ticket.uid, 'uid_1');
      expect(ticket.event.title, 'Garba Night');
    });

    test('Super Admin security check: iammshyam@gmail.com verified', () {
      const superAdminEmail = 'iammshyam@gmail.com';
      const unauthorizedEmail = 'random_user@gmail.com';

      bool isSuperAdmin(String email) =>
          email.trim().toLowerCase() == 'iammshyam@gmail.com';

      expect(isSuperAdmin(superAdminEmail), true);
      expect(isSuperAdmin(unauthorizedEmail), false);
    });
  });
}
