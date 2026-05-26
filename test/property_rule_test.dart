import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/models/property_rule_model.dart';
import 'package:hdbhms_mobile/screens/property_rules_screen.dart';
import 'package:hdbhms_mobile/services/auth_service.dart';
import 'package:hdbhms_mobile/services/property_rule_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePropertyRuleService extends PropertyRuleService {
  const _FakePropertyRuleService(this.response);

  final PropertyRulesResponse response;

  @override
  Future<PropertyRulesResponse> getRules({int? tenantId}) async {
    return response;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PropertyRuleService uses saved tenant id and bearer token', () async {
    SharedPreferences.setMockInitialValues({
      AuthService.accessTokenKey: 'token-123',
      AuthService.tenantIdKey: 23,
    });

    final service = PropertyRuleService(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/tenants/23/rules');
        expect(request.headers['Authorization'], 'Bearer token-123');

        return http.Response(
          jsonEncode(_rulesJson()),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final response = await service.getRules();

    expect(response.updatedAt, DateTime(2026, 5, 18, 10));
    expect(response.items.length, 5);
    expect(response.items.first.category, RuleCategory.general);
    expect(response.items.last.category, RuleCategory.fine);
  });

  test('PropertyRuleService returns cached rules when network fails', () async {
    SharedPreferences.setMockInitialValues({
      AuthService.accessTokenKey: 'token-123',
      AuthService.tenantIdKey: 23,
      'property_rules_cache_23': jsonEncode(_rulesJson()),
    });

    final service = PropertyRuleService(
      client: MockClient((request) {
        throw http.ClientException('offline');
      }),
    );

    final response = await service.getRules();

    expect(response.isFromCache, isTrue);
    expect(response.items, isNotEmpty);
  });

  testWidgets('property rules screen renders sections and fine cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PropertyRulesScreen(
          ruleService: _FakePropertyRuleService(
            PropertyRulesResponse.fromJson(_rulesJson()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nội quy nhà trọ'), findsOneWidget);
    expect(find.text('Nội Quy Lưu Trú'), findsOneWidget);
    expect(find.text('Quy định chung'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Các khoản phạt'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Các khoản phạt'), findsOneWidget);
    expect(find.text('Reset Wi-Fi'), findsOneWidget);
    expect(find.text('200.000đ/lần'), findsOneWidget);
  });

  testWidgets('property rules screen shows empty state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PropertyRulesScreen(
          ruleService: _FakePropertyRuleService(
            PropertyRulesResponse(
              updatedAt: null,
              bannerImageUrl: '',
              items: [],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có nội quy'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });
}

Map<String, dynamic> _rulesJson() {
  return {
    'updated_at': '2026-05-18T10:00:00',
    'items': [
      {
        'id': 1,
        'rule_code': 'GENERAL_001',
        'rule_category': 'GENERAL',
        'title': 'Mỗi phòng lưu trú đúng số lượng người đã đăng ký',
        'description': 'Mọi thay đổi phải báo cho quản lý.',
        'sort_order': 1,
        'status': 'ACTIVE',
      },
      {
        'id': 2,
        'rule_code': 'SECURITY_001',
        'rule_category': 'SECURITY',
        'title': 'Khóa cửa cẩn thận khi ra vào',
        'description': 'Không cung cấp mật mã cho người lạ.',
        'sort_order': 4,
        'status': 'ACTIVE',
      },
      {
        'id': 3,
        'rule_code': 'HYGIENE_001',
        'rule_category': 'HYGIENE',
        'title': 'Để rác đúng nơi quy định',
        'description': '',
        'sort_order': 7,
        'status': 'ACTIVE',
      },
      {
        'id': 4,
        'rule_code': 'UTILITY_001',
        'rule_category': 'UTILITY',
        'title': 'Sử dụng điện, nước tiết kiệm',
        'description': 'Tắt thiết bị khi ra khỏi phòng.',
        'sort_order': 10,
        'status': 'ACTIVE',
      },
      {
        'id': 5,
        'rule_code': 'FINE_WIFI_RESET',
        'rule_category': 'FINE',
        'title': 'Reset Wi-Fi',
        'description': 'Không tự ý reset modem.',
        'default_fine_amount': 200000,
        'fine_unit': 'lần',
        'sort_order': 12,
        'status': 'ACTIVE',
      },
    ],
  };
}
