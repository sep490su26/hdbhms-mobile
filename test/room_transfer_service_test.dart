import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/services/room_transfer/room_transfer_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'createTransferRequest sends selected transferred tenant profiles',
    () async {
      Map<String, dynamic>? sentBody;
      final service = RoomTransferService(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/occupant-transfer-requests');
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'data': 55}), 200);
        }),
      );

      final id = await service.createTransferRequest(
        sourceContractId: 7,
        targetRoomId: 9,
        requestedTransferDate: DateTime(2026, 8, 15),
        transferredTenantProfileIds: const [101, 102],
      );

      expect(id, 55);
      expect(sentBody?['transferredTenantProfileIds'], [101, 102]);
      expect(sentBody?['requestedTransferDate'], '2026-08-01');
      expect(sentBody?['expectedTransferDate'], '2026-08-01');
    },
  );
}
