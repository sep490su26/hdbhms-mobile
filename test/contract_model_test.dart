import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/models/contract/contract_list_item_model.dart';
import 'package:hdbhms_mobile/models/contract/lease_contract_model.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';

void main() {
  test('ContractListItem reads camelCase deposit agreement id', () {
    final item = ContractListItem.fromJson({
      'depositAgreementId': 42,
      'depositCode': 'DC-2026-042',
      'roomCode': 'P.101',
      'signatureStatus': 'SIGNED',
      'signedAt': '2026-06-16T10:30:00',
    });

    expect(item.id, 42);
    expect(item.contractCode, 'DC-2026-042');
    expect(item.status, 'SIGNED');
  });

  test(
    'DepositContract uses signed file URL and does not expose unsigned draft',
    () {
      final signed = DepositContract.fromJson({
        'depositAgreementId': 42,
        'depositCode': 'DC-2026-042',
        'status': 'PAID',
        'roomCode': '101',
        'signedFileId': 9,
        'signedFileDownloadUrl': '/api/v1/deposit-agreements/42/signed-file',
        'contractDownloadUrl': '/api/v1/deposit-agreements/42/draft-pdf',
      });

      expect(signed.id, 42);
      expect(
        signed.contractFileUrl,
        '/api/v1/deposit-agreements/42/signed-file',
      );

      final pending = DepositContract.fromJson({
        'depositAgreementId': 43,
        'depositCode': 'DC-2026-043',
        'status': 'PAID',
        'roomCode': '102',
        'contractDownloadUrl': '/api/v1/deposit-agreements/43/draft-pdf',
      });

      expect(pending.contractFileUrl, isEmpty);
    },
  );

  test(
    'LeaseContract reads tenant scoped file URL from camelCase response',
    () {
      final lease = LeaseContract.fromJson({
        'id': 7,
        'contractCode': 'HD-2026-H101-7',
        'status': 'ACTIVE',
        'roomCode': '101',
        'contractFileDownloadUrl': '/api/v1/tenants/profiles/me/files/11',
      });

      expect(lease.contractFileUrl, '/api/v1/tenants/profiles/me/files/11');
    },
  );

  test(
    'LeaseContract reads current tenant and occupants from detail response',
    () {
      final lease = LeaseContract.fromJson({
        'id': 7,
        'contractCode': 'HD-2026-H101-7',
        'status': 'ACTIVE',
        'currentTenantProfileId': 101,
        'occupants': [
          {
            'tenantProfileId': 101,
            'fullName': 'Nguyen Van A',
            'phone': '0901',
            'occupantRole': 'PRIMARY',
            'status': 'ACTIVE',
          },
          {
            'tenantProfileId': 102,
            'fullName': 'Tran Thi B',
            'email': 'b@example.com',
            'occupantRole': 'CO_OCCUPANT',
            'status': 'ACTIVE',
          },
        ],
      });

      expect(lease.currentTenantProfileId, 101);
      expect(lease.occupants.map((item) => item.tenantProfileId), [101, 102]);
      expect(lease.occupants.first.isPrimary, isTrue);
      expect(lease.occupants.last.displayName, 'Tran Thi B');
    },
  );

  test(
    'ActiveRoomItem reads liquidation fields from active rooms response',
    () {
      final room = ActiveRoomItem.fromJson({
        'contractId': 403,
        'roomCode': '403',
        'roomName': 'Phòng 403',
        'contractStatus': 'TERMINATION_PENDING',
        'tenantIntention': 'MOVE_OUT',
        'expectedVacantDate': '2026-07-31',
        'endDate': '2026-09-30',
      });

      expect(room.contractStatus, 'TERMINATION_PENDING');
      expect(room.tenantIntention, 'MOVE_OUT');
      expect(room.expectedVacantDate, DateTime(2026, 7, 31));
      expect(room.endDate, DateTime(2026, 9, 30));
    },
  );
}
