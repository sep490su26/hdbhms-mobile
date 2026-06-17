import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/models/contract/contract_list_item_model.dart';
import 'package:hdbhms_mobile/models/contract/lease_contract_model.dart';

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
}
