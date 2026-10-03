import 'package:flutter_test/flutter_test.dart';
import 'package:smart_office_queue/config/api_config.dart';
import 'package:smart_office_queue/models/department.dart';
import 'package:smart_office_queue/models/token.dart';
import 'package:smart_office_queue/models/user.dart';
import 'package:smart_office_queue/utils/constants.dart';
import 'package:smart_office_queue/utils/validators.dart';

void main() {
  group('ApiConfig.normalize', () {
    test('adds scheme and strips trailing slash', () {
      expect(ApiConfig.normalize('192.168.1.10:8080/'), 'http://192.168.1.10:8080');
      expect(ApiConfig.normalize('https://example.com//'), 'https://example.com');
    });
    test('empty falls back to default', () {
      expect(ApiConfig.normalize('  '), ApiConfig.defaultBaseUrl);
    });
  });

  group('models', () {
    test('Token.fromJson', () {
      final t = Token.fromJson({
        'id': 21,
        'token_number': 'IT-021',
        'visitor_name': 'Sohan',
        'visitor_mobile': '9876543210',
        'department_id': 1,
        'department_name': 'IT Support',
        'department_code': 'IT',
        'priority': true,
        'status': 'WAITING',
        'no_show_count': 0,
        'queue_position': 5,
        'people_ahead': 4,
        'estimated_wait_seconds': 1500,
        'generated_at': '2026-10-03T10:00:00Z',
      });
      expect(t.tokenNumber, 'IT-021');
      expect(t.isWaiting, isTrue);
      expect(t.queuePosition, 5);
      expect(formatWait(t.estimatedWaitSeconds), '~ 25 min');
    });

    test('Department.fromJson handles missing lists', () {
      final d = Department.fromJson({'id': 1, 'name': 'IT Support', 'code': 'IT', 'status': 'PAUSED'});
      expect(d.isPaused, isTrue);
      expect(d.currentlyServing, isEmpty);
    });

    test('User.canManage', () {
      final staff = User(id: 2, name: 'IT', email: 'it@x.com', role: 'STAFF', departmentId: 1);
      final admin = User(id: 1, name: 'A', email: 'a@x.com', role: 'ADMIN');
      expect(staff.canManage(1), isTrue);
      expect(staff.canManage(2), isFalse);
      expect(admin.canManage(3), isTrue);
    });
  });

  group('validators', () {
    test('mobile', () {
      expect(Validators.mobile('98765 43210'), isNull);
      expect(Validators.mobile('+91-98765-43210'), isNull);
      expect(Validators.mobile('12'), isNotNull);
      expect(Validators.mobile(''), isNotNull);
    });
    test('email', () {
      expect(Validators.email('admin@smartoffice.com'), isNull);
      expect(Validators.email('nope'), isNotNull);
    });
  });

  test('formatWait', () {
    expect(formatWait(0), 'No wait');
    expect(formatWait(30), '< 1 min');
    expect(formatWait(300), '~ 5 min');
    expect(formatWait(3900), '~ 1 h 5 min');
  });
}
