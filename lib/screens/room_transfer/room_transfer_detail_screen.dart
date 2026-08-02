import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/change_request/change_request_model.dart';
import 'package:hdbhms_mobile/models/payment/tenant_invoice_model.dart';
import 'package:hdbhms_mobile/models/room_transfer/room_transfer_model.dart';
import 'package:hdbhms_mobile/screens/payment/qr_payment_page.dart';
import 'package:hdbhms_mobile/screens/room_transfer/holder_nomination_screen.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/services/notification/notification_service.dart';
import 'package:hdbhms_mobile/services/payment/tenant_invoice_service.dart';
import 'package:hdbhms_mobile/services/profile_request/tenant_profile_service.dart';
import 'package:hdbhms_mobile/services/room_transfer/room_transfer_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';

/// Detail screen for a room-transfer change request.
/// Shows the change-request info, and if the linked transfer request is
/// available, shows transfer-specific status & contextual action buttons.
class RoomTransferDetailScreen extends StatefulWidget {
  const RoomTransferDetailScreen({
    super.key,
    required this.changeRequest,
    this.transferService = const RoomTransferService(),
    this.leaseContractService = const LeaseContractService(),
  });

  final ChangeRequest changeRequest;
  final RoomTransferService transferService;
  final LeaseContractService leaseContractService;

  @override
  State<RoomTransferDetailScreen> createState() =>
      _RoomTransferDetailScreenState();
}

class _RoomTransferDetailScreenState extends State<RoomTransferDetailScreen>
    with WidgetsBindingObserver {
  RoomTransferRequest? _transfer;
  bool _loadingTransfer = false;
  bool _transferLoadAttempted = false;
  String? _transferLoadError;
  bool _actionInProgress = false;
  bool _checkingTargetHolderAccess = false;
  bool _isVerifiedTargetHolder = false;
  bool _checkingHolderNominationAccess = false;
  bool _isVerifiedNominatedHolder = false;
  final TenantInvoiceService _tenantInvoiceService =
      const TenantInvoiceService();
  final TenantProfileService _tenantProfileService =
      const TenantProfileService();
  final NotificationService _notificationService = const NotificationService();
  int? _currentTenantProfileId;

  ChangeRequest get _req => widget.changeRequest;

  bool get _isResolvingScreenState =>
      _loadingTransfer ||
      (_transfer != null &&
          (_checkingTargetHolderAccess || _checkingHolderNominationAccess));

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentTenantProfile();
    _tryLoadTransfer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_loadingTransfer) {
      _tryLoadTransfer();
    }
  }

  Future<void> _loadCurrentTenantProfile() async {
    try {
      final profile = await _tenantProfileService.getMyProfile();
      if (!mounted) return;
      setState(() {
        _currentTenantProfileId =
            profile.tenantProfileId != null && profile.tenantProfileId! > 0
            ? profile.tenantProfileId
            : null;
        final transfer = _transfer;
        if (transfer != null &&
            transfer.status == TransferRequestStatus.waitingHolderResponse) {
          _isVerifiedNominatedHolder = _isCurrentTenantNominatedHolder(
            transfer,
          );
        }
      });
    } catch (_) {
      // Ignore; self option filtering will gracefully fall back.
    }
  }

  Future<void> _tryLoadTransfer() async {
    final transferId = _extractTransferId();
    final transferCode = _extractTransferCode();
    if (transferId == null && transferCode == null) {
      setState(() {
        _transferLoadAttempted = true;
        _loadingTransfer = false;
        _transferLoadError = 'Không tìm thấy liên kết yêu cầu chuyển phòng.';
      });
      return;
    }

    setState(() {
      _loadingTransfer = true;
      _transferLoadAttempted = true;
      _transferLoadError = null;
    });

    try {
      RoomTransferRequest? transfer;
      if (transferId != null) {
        try {
          transfer = await widget.transferService.getTransferRequest(
            transferId,
          );
        } on RoomTransferException {
          if (transferCode == null) rethrow;
        }
      }

      transfer ??= await widget.transferService.getTransferRequestByCode(
        transferCode!,
      );

      if (!mounted) return;
      setState(() {
        _transfer = transfer;
        _loadingTransfer = false;
        _transferLoadError = null;
      });
      unawaited(_markRoomTransferNotificationsRead(transfer.id));
      await _resolveTargetHolderAccess(transfer);
      await _resolveHolderNominationAccess(transfer);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingTransfer = false;
          _transferLoadError =
              'Chưa tải được thông tin liên quan đến yêu cầu này. Vui lòng thử lại.';
        });
      }
    }
  }

  Future<void> _markRoomTransferNotificationsRead(int transferId) async {
    if (transferId <= 0) return;
    for (final targetType in const ['ROOM_TRANSFER', 'ROOM_TRANSFER_REQUEST']) {
      try {
        await _notificationService.markTargetAsRead(
          targetType: targetType,
          targetId: transferId,
        );
      } catch (_) {
        // Best-effort read sync; detail loading must stay usable.
      }
    }
  }

  int? _extractTransferId() {
    if (_req.targetId != null && _req.targetId! > 0) {
      return _req.targetId;
    }

    final rawPayload = _req.requestPayload;
    if (rawPayload != null && rawPayload.trim().isNotEmpty) {
      try {
        final payload = jsonDecode(rawPayload);
        if (payload is Map<String, dynamic>) {
          final fromPayload =
              int.tryParse(payload['transferRequestId']?.toString() ?? '') ??
              int.tryParse(payload['targetId']?.toString() ?? '') ??
              int.tryParse(payload['id']?.toString() ?? '');
          if (fromPayload != null && fromPayload > 0) {
            return fromPayload;
          }
        }
      } catch (_) {
        // Ignore malformed payload and continue with legacy fallback.
      }
    }

    // Legacy fallback only when structured linkage is absent.
    final textToSearch = '${_req.title} ${_req.description}';

    final match = RegExp(
      r'(?:transfer.*id|id)[:\s]*(\d+)',
      caseSensitive: false,
    ).firstMatch(textToSearch);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }

    final numbers = RegExp(r'\b(\d{8,})\b').allMatches(textToSearch);
    for (final m in numbers) {
      final num = int.tryParse(m.group(1)!);
      if (num != null && num > 0) return num;
    }

    return null;
  }

  String? _extractTransferCode() {
    if (_req.requestCode.trim().isNotEmpty) {
      return _req.requestCode.trim();
    }

    final rawPayload = _req.requestPayload;
    if (rawPayload != null && rawPayload.trim().isNotEmpty) {
      try {
        final payload = jsonDecode(rawPayload);
        if (payload is Map<String, dynamic>) {
          final code =
              payload['transferRequestCode'] ??
              payload['roomTransferRequestCode'] ??
              payload['requestCode'] ??
              payload['code'];
          final value = code?.toString().trim();
          if (value != null && value.isNotEmpty) return value;
        }
      } catch (_) {
        // Ignore malformed payload; requestCode fallback above is enough.
      }
    }

    return null;
  }

  Future<void> _resolveTargetHolderAccess(RoomTransferRequest transfer) async {
    if (!mounted) return;
    if (transfer.status != TransferRequestStatus.waitingTargetHolderApproval ||
        !_isExistingTargetContractFlow(transfer)) {
      setState(() {
        _checkingTargetHolderAccess = false;
        _isVerifiedTargetHolder = false;
      });
      return;
    }

    setState(() {
      _checkingTargetHolderAccess = true;
      _isVerifiedTargetHolder = false;
    });

    try {
      final pendingApprovals = await widget.transferService
          .fetchPendingTargetHolderApprovals();
      final isPendingForCurrentUser = pendingApprovals.any(
        (item) => item.id == transfer.id,
      );
      if (!mounted) return;

      if (isPendingForCurrentUser) {
        setState(() {
          _checkingTargetHolderAccess = false;
          _isVerifiedTargetHolder = true;
        });
        return;
      }
    } catch (_) {
      // Fall back to contract-role check below when pending list is unavailable.
    }

    if (transfer.targetContractId == null || transfer.targetContractId! <= 0) {
      if (!mounted) return;
      setState(() {
        _checkingTargetHolderAccess = false;
        _isVerifiedTargetHolder = false;
      });
      return;
    }

    try {
      final contract = await widget.leaseContractService.getContractById(
        transfer.targetContractId!,
      );
      if (!mounted) return;
      setState(() {
        _checkingTargetHolderAccess = false;
        _isVerifiedTargetHolder =
            contract.isPrimary ||
            contract.roleInContract.toUpperCase() == 'PRIMARY';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingTargetHolderAccess = false;
        _isVerifiedTargetHolder = false;
      });
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _cancelTransfer() async {
    if (_transfer == null) return;
    final confirmed = await _confirmDialog(
      title: 'Hủy yêu cầu chuyển phòng',
      content:
          'Bạn có chắc muốn hủy yêu cầu chuyển phòng này? Hành động này không thể hoàn tác.',
      confirmLabel: 'Hủy yêu cầu',
      isDestructive: true,
    );
    if (!confirmed) return;

    setState(() => _actionInProgress = true);
    try {
      await widget.transferService.cancelTransferRequest(_transfer!.id);
      if (!mounted) return;
      _snack('Đã hủy yêu cầu chuyển phòng.');
      Navigator.of(context).pop(true); // signal refresh
    } on RoomTransferException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      _snack('Không thể hủy yêu cầu. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _confirmTenantSettlement() async {
    if (_transfer == null) return;

    final transfer = _transfer!;
    if (!_canConfirmTenantTransfer(transfer)) {
      _snack(
        'Yêu cầu chưa đủ điều kiện xác nhận. Kiểm tra lý do chặn bên dưới.',
      );
      return;
    }

    final rentDifference = _rentDifference(transfer);
    SettlementType? selectedSettlement = SettlementType.noDifference;

    if (rentDifference != 0) {
      selectedSettlement = await _showSettlementTypeDialog(rentDifference);
      if (selectedSettlement == null) return;
      if (!mounted) return;
    }

    setState(() => _actionInProgress = true);
    final navigator = Navigator.of(context);
    try {
      await widget.transferService.confirmTenantTransfer(
        requestId: transfer.id,
        settlementType: selectedSettlement,
      );
      if (!mounted) return;
      await _tryLoadTransfer();
      if (!mounted) return;

      if (selectedSettlement == SettlementType.tenantPayMore) {
        _snack('Đã tạo hóa đơn chênh lệch. Đang chuyển sang màn thanh toán.');
        await _openTransferDifferencePayment();
        return;
      }

      _snack('Đã xác nhận yêu cầu chuyển phòng.');
      navigator.pop(true);
    } on RoomTransferException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      _snack('Không thể xác nhận. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  int _rentDifference(RoomTransferRequest transfer) {
    return transfer.priceDifferenceAmount ?? transfer.priceDifferenceToPay ?? 0;
  }

  bool _requiresHolderSelectionForConfirmation(RoomTransferRequest transfer) {
    if (transfer.targetTransferType != TargetTransferType.newContract) {
      return false;
    }
    if (transfer.canConfirmTenantTransfer) {
      return false;
    }
    if (transfer.canNominateSourceHolder) {
      return true;
    }
    if (transfer.sourceRoomWillBeEmptyAfterTransfer == true) {
      return false;
    }
    final remainingOccupants = transfer.remainingOccupantCountAfterTransfer;
    if (remainingOccupants != null && remainingOccupants <= 0) {
      return false;
    }
    return transfer.sourceHolderCandidateProfileIds.any((id) => id > 0);
  }

  bool _canNominateSourceHolder(RoomTransferRequest transfer) {
    if (!_isCurrentTenantTransferring(transfer)) return false;
    if (transfer.canNominateSourceHolder) return true;
    final isOpenStatus =
        transfer.status == TransferRequestStatus.managerApproved ||
        transfer.status == TransferRequestStatus.waitingNewContract;
    final hasCandidate = transfer.sourceHolderCandidateProfileIds.any(
      (id) => id > 0,
    );
    return isOpenStatus &&
        hasCandidate &&
        (transfer.nominatedHolderProfileId == null ||
            transfer.nominatedHolderProfileId! <= 0);
  }

  bool _canEditConfirmationHolder(RoomTransferRequest transfer) {
    return _requiresHolderSelectionForConfirmation(transfer) &&
        _canNominateSourceHolder(transfer);
  }

  bool _canConfirmWithSelectedHolder(RoomTransferRequest transfer) {
    if (!_requiresHolderSelectionForConfirmation(transfer)) {
      return true;
    }
    final holderId = transfer.nominatedHolderProfileId;
    return holderId != null && holderId > 0;
  }

  bool _isCurrentTenantNominatedHolder(RoomTransferRequest transfer) {
    return _currentTenantProfileId != null &&
        _currentTenantProfileId == transfer.nominatedHolderProfileId;
  }

  bool _isCurrentTenantTransferring(RoomTransferRequest transfer) {
    final profileId = _currentTenantProfileId;
    return profileId != null &&
        transfer.transferringTenantProfileIds.contains(profileId);
  }

  Future<void> _resolveHolderNominationAccess(
    RoomTransferRequest transfer,
  ) async {
    if (!mounted) return;
    if (transfer.status != TransferRequestStatus.waitingHolderResponse ||
        transfer.nominatedHolderProfileId == null ||
        transfer.nominatedHolderProfileId! <= 0) {
      setState(() {
        _checkingHolderNominationAccess = false;
        _isVerifiedNominatedHolder = false;
      });
      return;
    }

    setState(() {
      _checkingHolderNominationAccess = true;
      _isVerifiedNominatedHolder = false;
    });

    try {
      final pendingNominations = await widget.transferService
          .fetchPendingHolderNominations();
      final isPendingForCurrentUser = pendingNominations.any(
        (item) => item.id == transfer.id,
      );
      if (!mounted) return;
      setState(() {
        _checkingHolderNominationAccess = false;
        _isVerifiedNominatedHolder =
            isPendingForCurrentUser ||
            _isCurrentTenantNominatedHolder(transfer);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingHolderNominationAccess = false;
        _isVerifiedNominatedHolder = _isCurrentTenantNominatedHolder(transfer);
      });
    }
  }

  bool _canConfirmTenantTransfer(RoomTransferRequest transfer) {
    if (!_isCurrentTenantTransferring(transfer)) return false;
    if (_isImmediateDifferencePaymentPending(transfer)) return false;
    if (transfer.hasBackendActions && !transfer.canConfirmTenantTransfer) {
      return false;
    }
    return _canConfirmWithSelectedHolder(transfer);
  }

  bool _isImmediateDifferencePaymentPending(RoomTransferRequest transfer) {
    if ((transfer.priceDifferenceToPay ?? 0) <= 0) {
      return false;
    }
    if (transfer.canPayTransferDifference) return true;
    return transfer.priceDifferenceSettlementType.trim().toUpperCase() ==
        SettlementType.tenantPayMore.backendValue;
  }

  bool _canActOnTransferContract(RoomTransferRequest transfer) {
    if (transfer.status == TransferRequestStatus.waitingSigning ||
        transfer.status == TransferRequestStatus.waitingContractSigning) {
      return false;
    }
    return _isCurrentTenantTransferring(transfer);
  }

  Future<void> _pickConfirmationHolder() async {
    final transfer = _transfer;
    if (transfer == null || !_canEditConfirmationHolder(transfer)) return;

    final selectedProfileId = await _showHolderSelectionDialog(transfer);
    if (!mounted || selectedProfileId == null) return;

    setState(() => _actionInProgress = true);
    try {
      await widget.transferService.nominateHolder(
        requestId: transfer.id,
        nominatedHolderProfileId: selectedProfileId,
      );
      if (!mounted) return;
      await _tryLoadTransfer();
      if (!mounted) return;
      _snack('Đã lưu người đứng tên hợp đồng mới cho phòng cũ.');
    } on RoomTransferException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      _snack('Không thể lưu người đứng tên hợp đồng mới. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Map<int, String> _extractSourceHolderCandidateNames(
    RoomTransferRequest transfer,
  ) {
    final result = <int, String>{...transfer.sourceHolderCandidateNames};
    transfer.transferringTenantNames.forEach((profileId, name) {
      result.putIfAbsent(profileId, () => name);
    });

    void addCandidate(int? profileId, Object? rawName) {
      if (profileId == null || profileId <= 0) return;
      final name = rawName?.toString().trim() ?? '';
      if (name.isEmpty || name == 'null') return;
      result.putIfAbsent(profileId, () => name);
    }

    final rawPayload = _req.requestPayload;
    if (rawPayload == null || rawPayload.trim().isEmpty) {
      return result;
    }

    try {
      final payload = jsonDecode(rawPayload);
      if (payload is! Map<String, dynamic>) {
        return result;
      }

      List<dynamic> collectList(List<String> keys) {
        for (final key in keys) {
          final value = payload[key];
          if (value is List) return value;
        }
        return const [];
      }

      int? profileIdFromMap(Map<String, dynamic> item) {
        final candidates = [
          item['tenantProfileId'],
          item['profileId'],
          item['id'],
          item['occupantProfileId'],
        ];
        for (final candidate in candidates) {
          final parsed = int.tryParse(candidate?.toString() ?? '');
          if (parsed != null && parsed > 0) return parsed;
        }
        return null;
      }

      String? nameFromMap(Map<String, dynamic> item) {
        final directKeys = [
          'fullName',
          'tenantName',
          'name',
          'occupantName',
          'profileName',
        ];
        for (final key in directKeys) {
          final value = item[key]?.toString().trim();
          if (value != null && value.isNotEmpty && value != 'null') {
            return value;
          }
        }
        final person = item['person'];
        if (person is Map<String, dynamic>) {
          final value = person['fullName']?.toString().trim();
          if (value != null && value.isNotEmpty && value != 'null') {
            return value;
          }
        }
        return null;
      }

      final listCandidates = [
        ...collectList([
          'sourceHolderCandidates',
          'sourceHolderCandidateProfiles',
          'remainingTenants',
          'remainingTenantProfiles',
          'remainingOccupants',
          'sourceOccupants',
          'transferringTenants',
          'transferringTenantProfiles',
          'tenantProfiles',
          'occupants',
          'members',
          'roommates',
        ]),
        ...collectList(['transferredTenants', 'selectedTenants']),
      ];

      for (final item in listCandidates.whereType<Map<String, dynamic>>()) {
        addCandidate(profileIdFromMap(item), nameFromMap(item));
      }
    } catch (_) {
      // Ignore malformed payload and use fallback labels.
    }

    return result;
  }

  String _holderDisplayName(int profileId, Map<int, String> tenantNames) {
    final name = tenantNames[profileId]?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return 'Người thuê #$profileId';
  }

  String? _selectedHolderDisplayName(RoomTransferRequest transfer) {
    final holderId = transfer.nominatedHolderProfileId;
    if (holderId == null || holderId <= 0) {
      return null;
    }
    return _holderDisplayName(
      holderId,
      _extractSourceHolderCandidateNames(transfer),
    );
  }

  Future<int?> _showHolderSelectionDialog(RoomTransferRequest transfer) async {
    final tenantNames = _extractSourceHolderCandidateNames(transfer);
    final options =
        transfer.sourceHolderCandidateProfileIds
            .where((id) => id > 0)
            .toSet()
            .toList()
          ..sort(
            (a, b) => _holderDisplayName(a, tenantNames)
                .toLowerCase()
                .compareTo(_holderDisplayName(b, tenantNames).toLowerCase()),
          );

    if (options.isEmpty) {
      _snack(
        _currentTenantProfileId != null
            ? 'Không còn người ở cùng nào khác để chọn làm người đứng tên hợp đồng mới.'
            : 'Không tìm thấy người thuê phù hợp để chọn làm người đứng tên hợp đồng mới.',
      );
      return null;
    }

    int selectedProfileId = options.first;
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusLg),
              ),
              title: const Text(
                'Chọn người đứng tên hợp đồng mới',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vui lòng chọn người ở lại phòng cũ sẽ trở thành người đứng tên hợp đồng mới sau khi bạn chuyển phòng.',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: AppColors.bodyText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: selectedProfileId,
                    decoration: const InputDecoration(
                      labelText: 'Người đứng tên hợp đồng mới',
                      border: OutlineInputBorder(),
                    ),
                    items: options
                        .map(
                          (profileId) => DropdownMenuItem<int>(
                            value: profileId,
                            child: Text(
                              _holderDisplayName(profileId, tenantNames),
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedProfileId = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(selectedProfileId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Xác nhận'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openTransferDifferencePayment() async {
    if (_transfer == null) return;

    final invoiceId = _transfer!.transferDifferenceInvoiceId;
    if (invoiceId == null || invoiceId <= 0) {
      _snack('Chưa tìm thấy hóa đơn chênh lệch để thanh toán.');
      return;
    }

    setState(() => _actionInProgress = true);
    try {
      final invoices = await _tenantInvoiceService.fetchMyInvoices();
      if (!mounted) return;

      TenantInvoice? invoice;
      for (final item in invoices) {
        if (item.id == invoiceId) {
          invoice = item;
          break;
        }
      }

      if (invoice == null) {
        _snack('Không tìm thấy hóa đơn chênh lệch trong danh sách hóa đơn.');
        return;
      }

      if (!invoice.canPay ||
          (!invoice.hasPayosQr && invoice.transferDescription.isEmpty)) {
        _snack('Hóa đơn chênh lệch chưa sẵn sàng để thanh toán.');
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => QrPaymentPage(
            invoice: invoice!,
            onPaymentConfirmed: _tryLoadTransfer,
          ),
        ),
      );

      if (!mounted) return;
      await _tryLoadTransfer();
    } on TenantInvoiceException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      _snack('Không thể mở thanh toán hóa đơn. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _openTransferOutUtilityPayment() async {
    if (_transfer == null) return;

    final invoiceId = _transfer!.oldRoomFinalInvoiceId;
    if (invoiceId == null || invoiceId <= 0) {
      _snack(
        'Ch\u01b0a t\u00ecm th\u1ea5y h\u00f3a \u0111\u01a1n \u0111i\u1ec7n/n\u01b0\u1edbc chuy\u1ec3n ph\u00f2ng.',
      );
      return;
    }

    setState(() => _actionInProgress = true);
    try {
      final invoices = await _tenantInvoiceService.fetchMyInvoices();
      if (!mounted) return;

      TenantInvoice? invoice;
      for (final item in invoices) {
        if (item.id == invoiceId) {
          invoice = item;
          break;
        }
      }

      if (invoice == null) {
        _snack(
          'Kh\u00f4ng t\u00ecm th\u1ea5y h\u00f3a \u0111\u01a1n chuy\u1ec3n ph\u00f2ng trong danh s\u00e1ch h\u00f3a \u0111\u01a1n.',
        );
        return;
      }

      if (!invoice.canPay ||
          (!invoice.hasPayosQr && invoice.transferDescription.isEmpty)) {
        _snack(
          'H\u00f3a \u0111\u01a1n chuy\u1ec3n ph\u00f2ng ch\u01b0a s\u1eb5n s\u00e0ng \u0111\u1ec3 thanh to\u00e1n.',
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => QrPaymentPage(
            invoice: invoice!,
            onPaymentConfirmed: _tryLoadTransfer,
          ),
        ),
      );

      if (!mounted) return;
      await _tryLoadTransfer();
    } on TenantInvoiceException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      _snack(
        'Kh\u00f4ng th\u1ec3 m\u1edf thanh to\u00e1n h\u00f3a \u0111\u01a1n. Vui l\u00f2ng th\u1eed l\u1ea1i.',
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _openHolderNomination() async {
    final current = _transfer;
    if (current == null) return;
    setState(() => _actionInProgress = true);
    RoomTransferRequest transfer;
    try {
      transfer = await widget.transferService.getTransferRequest(current.id);
      if (!mounted) return;
      setState(() => _transfer = transfer);
    } catch (_) {
      if (!mounted) return;
      _snack('Không tải được trạng thái mới nhất. Vui lòng thử lại.');
      return;
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => HolderNominationScreen(
          transferRequest: transfer,
          transferService: widget.transferService,
        ),
      ),
    );

    if (changed == true && mounted) {
      await _tryLoadTransfer();
      if (!mounted) return;
      _snack('Đã cập nhật đề cử người giữ hợp đồng.');
    }
  }

  Future<SettlementType?> _showSettlementTypeDialog(int difference) {
    final isPositive = difference > 0;
    final formattedDiff = _formatCurrency(difference.abs());
    final choices = isPositive
        ? const [SettlementType.tenantPayMore, SettlementType.addToNextInvoice]
        : const [SettlementType.creditNextContract];
    return showModalBottomSheet<SettlementType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isPositive
                      ? 'Chọn phương thức thanh toán'
                      : 'Chọn phương thức xử lý chênh lệch',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.inputText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isPositive
                      ? 'Phòng mới có giá cao hơn, chênh lệch cần trả: $formattedDiff.'
                      : 'Phòng mới có giá thấp hơn, chênh lệch cần xử lý: $formattedDiff.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.bodyText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                for (final choice in choices) ...[
                  _SettlementChoiceTile(
                    icon: _settlementIcon(choice),
                    title: _settlementTitle(choice),
                    subtitle: _settlementSubtitle(choice),
                    onTap: () => Navigator.of(ctx).pop(choice),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.deepBlue,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text('Đóng'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _settlementIcon(SettlementType type) {
    switch (type) {
      case SettlementType.tenantPayMore:
        return Icons.payment;
      case SettlementType.addToNextInvoice:
        return Icons.schedule;
      case SettlementType.refundNow:
        return Icons.account_balance_wallet_outlined;
      case SettlementType.creditNextContract:
        return Icons.receipt_long_outlined;
      case SettlementType.noDifference:
        return Icons.check_circle_outline;
    }
  }

  String _settlementTitle(SettlementType type) {
    switch (type) {
      case SettlementType.tenantPayMore:
        return 'Thanh toán ngay';
      case SettlementType.addToNextInvoice:
        return 'Cộng vào kỳ kế tiếp';
      case SettlementType.refundNow:
        return 'Hoàn tiền ngay';
      case SettlementType.creditNextContract:
        return 'Cấn trừ hợp đồng mới';
      case SettlementType.noDifference:
        return 'Không có chênh lệch';
    }
  }

  String _settlementSubtitle(SettlementType type) {
    switch (type) {
      case SettlementType.tenantPayMore:
        return 'Hệ thống tạo hóa đơn chênh lệch và tự chuyển tiếp sau khi thanh toán thành công.';
      case SettlementType.addToNextInvoice:
        return 'Xác nhận yêu cầu ngay và cộng khoản chênh lệch vào hóa đơn kỳ sau.';
      case SettlementType.refundNow:
        return 'Khoản chênh lệch giảm sẽ được hoàn tiền theo quy trình xử lý của quản lý.';
      case SettlementType.creditNextContract:
        return 'Khoản chênh lệch giảm sẽ được cấn trừ vào hợp đồng mới hoặc hóa đơn kỳ sau.';
      case SettlementType.noDifference:
        return 'Không phát sinh khoản chênh lệch cần xử lý.';
    }
  }

  String _formatCurrency(int amount) {
    final s = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return '$bufferđ';
  }

  Future<void> _rejectContract() async {
    if (_transfer == null) return;
    final isTenantConfirmation =
        _transfer!.status == TransferRequestStatus.waitingTenantConfirmation;
    final confirmed = await _confirmDialog(
      title: isTenantConfirmation ? 'Từ chối yêu cầu' : 'Từ chối hợp đồng',
      content: isTenantConfirmation
          ? 'Bạn có chắc muốn từ chối yêu cầu chuyển phòng này?'
          : 'Bạn có chắc muốn từ chối hợp đồng chuyển phòng này?',
      confirmLabel: 'Từ chối',
      isDestructive: true,
    );
    if (!confirmed) return;

    setState(() => _actionInProgress = true);
    try {
      await widget.transferService.rejectTransferContract(_transfer!.id);
      if (!mounted) return;
      _snack(
        isTenantConfirmation
            ? 'Đã từ chối yêu cầu chuyển phòng.'
            : 'Đã từ chối hợp đồng chuyển phòng.',
      );
      Navigator.of(context).pop(true);
    } on RoomTransferException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      _snack('Không thể từ chối. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  // ── Target Holder Approval Actions ─────────────────────────────────────

  Future<void> _approveTargetHolderTransfer() async {
    if (_transfer == null) return;
    final confirmed = await _confirmDialog(
      title: 'Đồng ý chuyển phòng',
      content:
          'Bạn có chắc muốn chấp nhận yêu cầu chuyển phòng này vào phòng của bạn? Sau khi đồng ý, hợp đồng thỏa thuận sẽ được tạo.',
      confirmLabel: 'Đồng ý',
      isDestructive: false,
    );
    if (!confirmed) return;

    setState(() => _actionInProgress = true);
    try {
      await widget.transferService.approveTargetHolderTransfer(_transfer!.id);
      if (!mounted) return;
      _snack('Đã đồng ý yêu cầu chuyển phòng.');
      Navigator.of(context).pop(true);
    } on RoomTransferException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      _snack('Không thể phê duyệt. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _rejectTargetHolderTransfer() async {
    if (_transfer == null) return;
    final confirmed = await _confirmDialog(
      title: 'Từ chối chuyển phòng',
      content: 'Bạn có chắc muốn từ chối yêu cầu chuyển phòng này?',
      confirmLabel: 'Từ chối',
      isDestructive: true,
    );
    if (!confirmed) return;

    setState(() => _actionInProgress = true);
    try {
      await widget.transferService.rejectTargetHolderTransfer(_transfer!.id);
      if (!mounted) return;
      _snack('Đã từ chối yêu cầu chuyển phòng.');
      Navigator.of(context).pop(true);
    } on RoomTransferException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      _snack('Không thể từ chối. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _acceptHolderNomination() async {
    if (_transfer == null) return;
    final confirmed = await _confirmDialog(
      title: 'Xác nhận người đứng tên hợp đồng mới',
      content:
          'Bạn có chắc muốn trở thành người đứng tên hợp đồng mới của phòng cũ cho yêu cầu chuyển phòng này?',
      confirmLabel: 'Xác nhận',
      isDestructive: false,
    );
    if (!confirmed) return;

    setState(() => _actionInProgress = true);
    try {
      await widget.transferService.acceptHolderNomination(_transfer!.id);
      if (!mounted) return;
      _snack('Đã xác nhận trở thành người đứng tên hợp đồng mới.');
      Navigator.of(context).pop(true);
    } on RoomTransferException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      _snack('Không thể xác nhận đề cử. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _rejectHolderNomination() async {
    if (_transfer == null) return;
    final confirmed = await _confirmDialog(
      title: 'Từ chối người đứng tên hợp đồng mới',
      content:
          'Bạn có chắc muốn từ chối đề cử người đứng tên hợp đồng mới này?',
      confirmLabel: 'Từ chối',
      isDestructive: true,
    );
    if (!confirmed) return;

    setState(() => _actionInProgress = true);
    try {
      await widget.transferService.rejectHolderNomination(_transfer!.id);
      if (!mounted) return;
      _snack('Đã từ chối đề cử người đứng tên hợp đồng mới.');
      Navigator.of(context).pop(true);
    } on RoomTransferException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      _snack('Không thể từ chối đề cử. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  bool _isExistingTargetContractFlow(RoomTransferRequest transfer) {
    return transfer.targetTransferType == TargetTransferType.ownContract ||
        transfer.targetTransferType == TargetTransferType.otherContract;
  }

  bool get _isTargetHolder {
    if (_transfer == null) return false;
    return !_checkingTargetHolderAccess &&
        _isVerifiedTargetHolder &&
        _transfer!.status ==
            TransferRequestStatus.waitingTargetHolderApproval &&
        _isExistingTargetContractFlow(_transfer!);
  }

  bool get _isNominatedHolder {
    if (_transfer == null) return false;
    return !_checkingHolderNominationAccess &&
        (_isVerifiedNominatedHolder ||
            _isCurrentTenantNominatedHolder(_transfer!)) &&
        _transfer!.status == TransferRequestStatus.waitingHolderResponse;
  }

  Future<bool> _confirmDialog({
    required String title,
    required String content,
    required String confirmLabel,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy bỏ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive
                  ? AppColors.danger
                  : AppColors.deepBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
              ),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(header: _buildHeader(), child: _buildBody()),
      ),
    );
  }

  String _formatMoney(num? value) {
    if (value == null) return '—';
    final amount = value.round();
    final normalized = amount.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < normalized.length; i++) {
      final remaining = normalized.length - i;
      buffer.write(normalized[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write('.');
      }
    }
    return '${amount < 0 ? '-' : ''}${buffer.toString()} đ';
  }

  bool _canViewFullTransferFlow(RoomTransferRequest transfer) {
    return _isCurrentTenantTransferring(transfer) || _isTargetHolder;
  }

  bool _canViewDestinationInfo(RoomTransferRequest transfer) {
    return _isCurrentTenantTransferring(transfer) || _isTargetHolder;
  }

  bool _canViewTransferFinancials(RoomTransferRequest transfer) {
    return _isCurrentTenantTransferring(transfer);
  }

  bool _canViewTransferEligibility(RoomTransferRequest transfer) {
    return _isCurrentTenantTransferring(transfer);
  }

  bool _shouldMaskOperationalStatus(RoomTransferRequest transfer) {
    if (_canViewFullTransferFlow(transfer) ||
        _isNominatedHolder ||
        _isTargetHolder) {
      return false;
    }
    return switch (transfer.status) {
      TransferRequestStatus.waitingTenantConfirmation ||
      TransferRequestStatus.waitingPayment ||
      TransferRequestStatus.waitingContractConfirmation ||
      TransferRequestStatus.waitingSigning ||
      TransferRequestStatus.waitingContractSigning => true,
      _ => false,
    };
  }

  String _displayTransferStatusLabel(RoomTransferRequest transfer) {
    if (_shouldMaskOperationalStatus(transfer)) {
      return 'Đang xử lý chuyển phòng';
    }
    return transfer.status.label;
  }

  String? _displayTransferStatusSubtitle(RoomTransferRequest transfer) {
    if (!_shouldMaskOperationalStatus(transfer)) return null;
    return 'Người chuyển phòng và quản lý đang hoàn tất các bước liên quan. '
        'Bạn không cần thao tác thêm.';
  }

  String _formatProfileNames(Map<int, String> names) {
    final values = names.values
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    if (values.isEmpty) return '—';
    return values.join(', ');
  }

  List<Widget> _withInfoDividers(List<Widget> rows) {
    final result = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        result.add(const SizedBox(height: 8));
        result.add(const Divider(height: 1, color: Color(0xFFEEECEE)));
        result.add(const SizedBox(height: 8));
      }
      result.add(rows[i]);
    }
    return result;
  }

  String _formatEligibilityResult(bool? value) {
    if (value == true) return 'Đủ điều kiện';
    if (value == false) return 'Không đủ điều kiện';
    return 'Chưa có dữ liệu';
  }

  Widget _messagePanel({
    required String title,
    required List<String> items,
    required Color borderColor,
    required Color backgroundColor,
    required Color textColor,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '• $item',
                style: TextStyle(
                  color: textColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _transferEligibilityChildren(RoomTransferRequest transfer) {
    final debt = transfer.debtSummary;
    final violation = transfer.violationSummary;
    final rows = <Widget>[
      _InfoRow(
        label: 'Kết quả lúc tạo',
        value: _formatEligibilityResult(transfer.eligibleAtCreation),
        valueColor: transfer.eligibleAtCreation == false
            ? AppColors.danger
            : transfer.eligibleAtCreation == true
            ? AppColors.successText
            : null,
      ),
      _InfoRow(
        label: 'Kiểm tra lúc',
        value: _formatDateTime(transfer.eligibilityCheckedAt),
      ),
      _InfoRow(
        label: 'Tổng nợ',
        value: _formatMoney(debt?.totalDebtAmount ?? 0),
        valueColor: debt?.overLimit == true ? AppColors.danger : null,
      ),
      _InfoRow(
        label: 'Nợ thuê / điện nước',
        value:
            '${_formatMoney(debt?.rentDebtAmount ?? 0)} / ${_formatMoney(debt?.utilityDebtAmount ?? 0)}',
      ),
      _InfoRow(
        label: 'Vi phạm',
        value: '${violation?.totalCount ?? 0} ghi nhận',
        valueColor: (violation?.totalCount ?? 0) > 0
            ? const Color(0xFFD97706)
            : null,
      ),
      _InfoRow(
        label: 'Chuyển trong năm',
        value: '${transfer.transferCountThisYear ?? 0} lần',
      ),
    ];

    final children = <Widget>[..._withInfoDividers(rows)];

    if ((violation?.latestDescriptions ?? const []).isNotEmpty) {
      children.addAll([
        const SizedBox(height: 12),
        _messagePanel(
          title: 'Vi phạm gần nhất',
          items: violation!.latestDescriptions.take(3).toList(growable: false),
          borderColor: const Color(0xFFFDE68A),
          backgroundColor: AppColors.warningSurface,
          textColor: AppColors.warningText,
        ),
      ]);
    }

    return children;
  }

  List<Widget> _transferInfoRows(RoomTransferRequest transfer) {
    String roomLabel(String code, String name, int id) {
      final codeText = code.trim();
      final nameText = name.trim();
      if (codeText.isNotEmpty && nameText.isNotEmpty) {
        return '$codeText - $nameText';
      }
      if (codeText.isNotEmpty) return codeText;
      if (nameText.isNotEmpty) return nameText;
      return '#$id';
    }

    bool hasValue(String value) {
      final normalized = value.trim();
      return normalized.isNotEmpty && normalized != '—';
    }

    void addRow(
      List<Widget> target, {
      required String label,
      required String value,
      Color? valueColor,
    }) {
      if (!hasValue(value)) return;
      target.add(_InfoRow(label: label, value: value, valueColor: valueColor));
    }

    final rows = <Widget>[
      _InfoRow(label: 'Mã yêu cầu', value: transfer.requestCode),
    ];

    rows.add(
      _InfoRow(
        label: 'Phòng cũ',
        value: roomLabel(
          transfer.oldRoomCode,
          transfer.oldRoomName,
          transfer.oldRoomId,
        ),
      ),
    );

    if (_canViewDestinationInfo(transfer)) {
      rows.add(
        _InfoRow(
          label: 'Phòng đến',
          value: roomLabel(
            transfer.targetRoomCode,
            transfer.targetRoomName,
            transfer.targetRoomId,
          ),
        ),
      );
    }

    addRow(
      rows,
      label: 'Người chuyển',
      value: _formatProfileNames(transfer.transferringTenantNames),
    );

    final nominatedHolderId = transfer.nominatedHolderProfileId;
    if (nominatedHolderId != null && nominatedHolderId > 0) {
      final holderName = transfer.sourceHolderCandidateNames[nominatedHolderId]
          ?.trim();
      addRow(
        rows,
        label: 'Người ở lại đứng tên',
        value: holderName == null || holderName.isEmpty
            ? 'Đã chọn'
            : holderName,
      );
    }

    if (_canViewTransferFinancials(transfer)) {
      rows.add(
        _InfoRow(
          label: 'Chênh lệch',
          value: _formatMoney(
            transfer.priceDifferenceAmount ?? transfer.priceDifferenceToPay,
          ),
          valueColor: AppColors.primary,
        ),
      );
      addRow(rows, label: 'Cách xử lý', value: transfer.paymentBranchLabel);
    }

    if (_canViewFullTransferFlow(transfer)) {
      final remainingCount = transfer.remainingOccupantCountAfterTransfer;
      final hasRemainingHolder =
          nominatedHolderId != null && nominatedHolderId > 0;
      final afterTransfer = hasRemainingHolder
          ? 'Phòng cũ còn người ở'
          : remainingCount != null && remainingCount > 0
          ? 'Phòng cũ còn $remainingCount người'
          : transfer.sourceRoomWillBeEmptyAfterTransfer == null
          ? ''
          : transfer.sourceRoomWillBeEmptyAfterTransfer == true
          ? 'Phòng cũ trống'
          : 'Phòng cũ còn người ở';
      addRow(rows, label: 'Sau chuyển', value: afterTransfer);
    }

    rows.addAll([
      _InfoRow(
        label: 'Ngày chuyển',
        value: _formatDate(transfer.requestedTransferDate),
      ),
      _InfoRow(
        label: 'Trạng thái',
        value: _displayTransferStatusLabel(transfer),
      ),
    ]);

    return _withInfoDividers(rows);
  }

  // ignore: unused_element
  Widget _buildLegacyHeader() {
    return Container(
      height: AppColors.topBarHeight,
      padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.cardBorder.withValues(alpha: 0.65),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.deepBlue,
              size: 24,
            ),
            tooltip: 'Trở về',
          ),
          const Expanded(
            child: Text(
              'Chi tiết chuyển phòng',
              style: AppColors.topBarTitleStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AppTopBar(
      title: 'Chi tiết chuyển phòng',
      onBack: () => Navigator.of(context).maybePop(),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
      children: [
        // ── Status banner ──────────────────────────────────────────────
        _StatusBanner(
          requestStatus: _req.status,
          transferStatus: _transfer?.status,
          displayLabel: _transfer == null
              ? null
              : _displayTransferStatusLabel(_transfer!),
          displaySubtitle: _transfer == null
              ? null
              : _displayTransferStatusSubtitle(_transfer!),
          neutral:
              _transfer != null && _shouldMaskOperationalStatus(_transfer!),
        ),

        const SizedBox(height: 14),

        // ── Transfer Status Timeline / loading state ───────────────────
        if (_isResolvingScreenState)
          _TransferLoadingCard(
            message: _loadingTransfer
                ? 'Đang tải chi tiết chuyển phòng...'
                : 'Đang xác định quyền phê duyệt và hành động khả dụng...',
          )
        else if (_transfer != null && _canViewFullTransferFlow(_transfer!))
          _StatusTimeline(
            currentStatus: _transfer!.status,
            targetTransferType: _transfer!.targetTransferType,
            usesExistingTargetContract: _isExistingTargetContractFlow(
              _transfer!,
            ),
            remainingOccupantCountAfterTransfer:
                _transfer!.remainingOccupantCountAfterTransfer,
            nominatedHolderProfileId: _transfer!.nominatedHolderProfileId,
          )
        else if (_transfer == null && _transferLoadAttempted)
          _TransferLoadStateCard(
            message: _transferLoadError ?? 'Không có dữ liệu chuyển phòng.',
            onRetry: _tryLoadTransfer,
          ),

        const SizedBox(height: 14),

        // ── Change request info ────────────────────────────────────────
        _SectionCard(
          title: 'Thông tin yêu cầu',
          icon: Icons.info_outline_rounded,
          children: [
            _InfoRow(
              label: 'Mã yêu cầu',
              value: _req.requestCode.isNotEmpty ? _req.requestCode : '--',
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFEEECEE)),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Trạng thái',
              value: _transfer == null
                  ? _req.status.label
                  : _displayTransferStatusLabel(_transfer!),
              valueColor: _effectiveStatusColor,
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFEEECEE)),
            const SizedBox(height: 8),
            _InfoRow(label: 'Ngày tạo', value: _formatDate(_req.createdAt)),
            if (_req.resolvedAt != null) ...[
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFEEECEE)),
              const SizedBox(height: 8),
              _InfoRow(
                label: 'Ngày xử lý',
                value: _formatDate(_req.resolvedAt),
              ),
            ],
          ],
        ),

        // ── Description ────────────────────────────────────────────────
        if (_req.description.isNotEmpty &&
            (_transfer == null || _canViewFullTransferFlow(_transfer!))) ...[
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Mô tả / Lý do',
            icon: Icons.notes_outlined,
            children: [
              Text(
                _req.description,
                style: const TextStyle(
                  color: AppColors.inputText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ],

        // ── Resolution note ────────────────────────────────────────────
        if (_req.resolutionNote != null &&
            _req.resolutionNote!.isNotEmpty &&
            (_transfer == null || _canViewFullTransferFlow(_transfer!))) ...[
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Ghi chú từ quản lý',
            icon: Icons.comment_outlined,
            children: [
              Text(
                _req.resolutionNote!,
                style: const TextStyle(
                  color: AppColors.inputText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ],

        // ── Transfer-specific info (when linked transfer is loaded) ────
        if (_transfer != null) ...[
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Thông tin chuyển phòng',
            icon: Icons.swap_horiz_rounded,
            children: _transferInfoRows(_transfer!),
          ),
        ],

        if (_transfer != null && _canViewTransferEligibility(_transfer!)) ...[
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Điều kiện chuyển phòng',
            icon: Icons.rule_folder_outlined,
            children: _transferEligibilityChildren(_transfer!),
          ),
        ],

        if (_transfer != null && _canEditConfirmationHolder(_transfer!)) ...[
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Người đứng tên hợp đồng mới',
            icon: Icons.person_outline_rounded,
            children: [
              Text(
                _transfer!.nominatedHolderProfileId != null &&
                        _transfer!.nominatedHolderProfileId! > 0
                    ? 'Người đứng tên hợp đồng đã chọn: ${_selectedHolderDisplayName(_transfer!) ?? 'Người thuê #${_transfer!.nominatedHolderProfileId}'}. Sau bước này bạn mới xác nhận yêu cầu và chọn phương thức thanh toán.'
                    : 'Bạn cần chọn người đứng tên hợp đồng trước. Sau khi chọn xong, mới được xác nhận yêu cầu và chọn phương thức thanh toán.',
                style: const TextStyle(
                  color: AppColors.bodyText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              _ActionButton(
                label:
                    _transfer!.nominatedHolderProfileId != null &&
                        _transfer!.nominatedHolderProfileId! > 0
                    ? 'Đổi người đứng tên hợp đồng mới'
                    : 'Chọn người đứng tên hợp đồng mới',
                icon: Icons.person_search_outlined,
                color: AppColors.deepBlue,
                busy: _actionInProgress,
                onTap: _pickConfirmationHolder,
              ),
            ],
          ),
        ],

        if (_transfer != null &&
            _canActOnTransferContract(_transfer!) &&
            _transfer!.status ==
                TransferRequestStatus.waitingTenantConfirmation &&
            (_transfer!.priceDifferenceToPay ?? 0) > 0 &&
            _transfer!.transferDifferenceInvoiceId == null &&
            _transfer!.priceDifferenceSettlementType.isEmpty) ...[
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Phương thức thanh toán',
            icon: Icons.payments_outlined,
            children: [
              Text(
                'Khi bấm xác nhận yêu cầu, hệ thống sẽ cho bạn chọn cách xử lý khoản chênh lệch ${_formatCurrency(_transfer!.priceDifferenceToPay ?? 0)}.',
                style: const TextStyle(
                  color: AppColors.bodyText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ],

        // ── Target Holder Approval Section ─────────────────────────────
        if (_transfer != null && _isTargetHolder) ...[
          const SizedBox(height: 14),
          _TargetHolderApprovalCard(
            transfer: _transfer!,
            onApprove: _approveTargetHolderTransfer,
            onReject: _rejectTargetHolderTransfer,
            busy: _actionInProgress,
          ),
        ],

        // ── Action buttons ─────────────────────────────────────────────
        const SizedBox(height: 24),
        ..._buildActions(),
      ],
    );
  }

  List<Widget> _buildActions() {
    final actions = <Widget>[];
    final busy = _actionInProgress;

    if (_isResolvingScreenState) {
      actions.add(
        _TransferActionLoadingCard(
          message: _loadingTransfer
              ? 'Đang tải chi tiết yêu cầu...'
              : 'Đang xác định hành động khả dụng...',
        ),
      );
      return actions;
    }

    // Cancel: available when pending and transfer exists
    if (_req.status == ChangeRequestStatus.pending && _transfer != null) {
      actions.add(
        _ActionButton(
          label: 'Hủy yêu cầu chuyển phòng',
          icon: Icons.cancel_outlined,
          color: AppColors.danger,
          busy: busy,
          onTap: _cancelTransfer,
        ),
      );
    }

    // Transfer-specific contract actions
    if (_transfer != null) {
      switch (_transfer!.status) {
        case TransferRequestStatus.waitingTenantConfirmation:
          if (!_canActOnTransferContract(_transfer!)) {
            break;
          }
          if (_isImmediateDifferencePaymentPending(_transfer!)) {
            _addTransferDifferencePaymentActions(actions, busy);
            break;
          }
          actions.add(
            _ActionButton(
              label: 'Xác nhận yêu cầu',
              icon: Icons.check_circle_outline,
              color: AppColors.successText,
              busy: busy,
              enabled: _canConfirmTenantTransfer(_transfer!),
              onTap: _confirmTenantSettlement,
            ),
          );
          actions.add(const SizedBox(height: 10));
          actions.add(
            _ActionButton(
              label: 'Từ chối yêu cầu',
              icon: Icons.cancel_outlined,
              color: AppColors.danger,
              busy: busy,
              onTap: _rejectContract,
            ),
          );
          break;
        case TransferRequestStatus.waitingPayment:
          if (!_canActOnTransferContract(_transfer!)) {
            break;
          }
          _addTransferDifferencePaymentActions(actions, busy);
          break;
        case TransferRequestStatus.waitingContractConfirmation:
          break;
        case TransferRequestStatus.waitingSigning:
        case TransferRequestStatus.waitingContractSigning:
          break;
        case TransferRequestStatus.managerApproved:
        case TransferRequestStatus.waitingNewContract:
          if (_canEditConfirmationHolder(_transfer!)) {
            break;
          }
          if (!_canNominateSourceHolder(_transfer!)) {
            break;
          }
          actions.add(
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.infoSurface,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.deepBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sau khi quản lý duyệt, nếu người gửi yêu cầu đang là người đứng tên hợp đồng thì cần đề cử người đứng tên hợp đồng mới của phòng cũ trước khi hệ thống đi tiếp sang các bước hợp đồng.',
                      style: TextStyle(
                        color: AppColors.deepBlue,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
          actions.add(const SizedBox(height: 10));
          actions.add(
            _ActionButton(
              label: 'Đề cử người đứng tên hợp đồng mới',
              icon: Icons.person_outline_rounded,
              color: AppColors.deepBlue,
              busy: busy,
              onTap: _openHolderNomination,
            ),
          );
          break;
        case TransferRequestStatus.waitingHolderResponse:
          if (_isNominatedHolder) {
            actions.add(
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warningSurface,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  border: Border.all(color: AppColors.warning),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFFD97706),
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bạn được đề cử làm người đứng tên hợp đồng mới của phòng cũ. Vui lòng xác nhận để yêu cầu chuyển phòng tiếp tục.',
                        style: TextStyle(
                          color: AppColors.warningText,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
            actions.add(const SizedBox(height: 10));
            actions.add(
              _ActionButton(
                label: 'Xác nhận làm người đứng tên hợp đồng mới',
                icon: Icons.how_to_reg_outlined,
                color: AppColors.successText,
                busy: busy,
                onTap: _acceptHolderNomination,
              ),
            );
            actions.add(const SizedBox(height: 10));
            actions.add(
              _ActionButton(
                label: 'Từ chối đề cử',
                icon: Icons.cancel_outlined,
                color: AppColors.danger,
                busy: busy,
                onTap: _rejectHolderNomination,
              ),
            );
          } else {
            actions.add(
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warningSurface,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  border: Border.all(color: AppColors.warning),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      color: Color(0xFFD97706),
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Đã đề cử người đứng tên hợp đồng mới cho phòng cũ. Hệ thống đang chờ người được đề cử phản hồi trước khi đi tiếp.',
                        style: TextStyle(
                          color: AppColors.warningText,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
            actions.add(const SizedBox(height: 10));
            actions.add(
              _ActionButton(
                label: 'Kiểm tra lại trạng thái',
                icon: Icons.refresh_rounded,
                color: AppColors.deepBlue,
                busy: busy || _loadingTransfer,
                onTap: () {
                  _tryLoadTransfer();
                },
              ),
            );
          }
          break;
        case TransferRequestStatus.waitingTargetHolderApproval:
          // Target holder approval is handled by the embedded card
          // No action button needed here
          break;
        case TransferRequestStatus.waitingExecution:
          final message = _transfer!.canPayTransferOutUtility
              ? 'Cần thanh toán hóa đơn điện/nước chuyển phòng #${_transfer!.oldRoomFinalInvoiceId ?? ''} trước khi quản lý hoàn tất chuyển phòng.'
              : 'Phiên chuyển phòng đang diễn ra. Quản lý hoàn tất check-in phòng mới rồi execute giao dịch.';
          actions.add(
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.infoSurface,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.deepBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
          if (_transfer!.canPayTransferOutUtility) {
            actions.add(const SizedBox(height: 10));
            actions.add(
              _ActionButton(
                label:
                    'Thanh to\u00e1n h\u00f3a \u0111\u01a1n \u0111i\u1ec7n/n\u01b0\u1edbc',
                icon: Icons.payments_outlined,
                color: const Color(0xFFD97706),
                busy: busy,
                enabled: (_transfer?.oldRoomFinalInvoiceId ?? 0) > 0,
                onTap: _openTransferOutUtilityPayment,
              ),
            );
          }
          break;
        default:
          break;
      }
    }

    // If no transfer-specific actions, show generic close
    if (actions.isEmpty &&
        !_isTargetHolder &&
        !_isNominatedHolder &&
        (!_transferLoadAttempted || _transferLoadError == null)) {
      actions.add(
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepBlue,
              side: const BorderSide(color: AppColors.deepBlue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
              ),
            ),
            child: const Text(
              'Đóng',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );
    }

    return actions;
  }

  void _addTransferDifferencePaymentActions(List<Widget> actions, bool busy) {
    actions.add(
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warningSurface,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: AppColors.warning),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              color: Color(0xFFD97706),
              size: 20,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bạn đã chọn thanh toán ngay. Yêu cầu chỉ được xác nhận sau khi hóa đơn chênh lệch thanh toán thành công.',
                style: TextStyle(
                  color: AppColors.warningText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    actions.add(const SizedBox(height: 10));
    actions.add(
      _ActionButton(
        label: 'Thanh toán hóa đơn',
        icon: Icons.payments_outlined,
        color: const Color(0xFFD97706),
        busy: busy,
        enabled: (_transfer?.transferDifferenceInvoiceId ?? 0) > 0,
        onTap: _openTransferDifferencePayment,
      ),
    );
  }

  Color get _effectiveStatusColor {
    final transferStatus = _transfer?.status;
    if (transferStatus != null) {
      if (_shouldMaskOperationalStatus(_transfer!)) {
        return AppColors.deepBlue;
      }
      return switch (transferStatus) {
        TransferRequestStatus.requested => const Color(0xFFD97706),
        TransferRequestStatus.waitingManagerApproval => const Color(0xFFD97706),
        TransferRequestStatus.managerApproved => AppColors.deepBlue,
        TransferRequestStatus.waitingHolderResponse => const Color(0xFFD97706),
        TransferRequestStatus.waitingApproval => const Color(0xFFD97706),
        TransferRequestStatus.waitingNewContract => AppColors.deepBlue,
        TransferRequestStatus.waitingTargetHolderApproval => const Color(
          0xFFD97706,
        ),
        TransferRequestStatus.waitingTenantConfirmation => AppColors.deepBlue,
        TransferRequestStatus.waitingContractConfirmation => AppColors.deepBlue,
        TransferRequestStatus.waitingPayment => const Color(0xFFD97706),
        TransferRequestStatus.waitingSigning => AppColors.deepBlue,
        TransferRequestStatus.waitingContractSigning => AppColors.deepBlue,
        TransferRequestStatus.waitingTransferDate => AppColors.primary,
        TransferRequestStatus.readyForHandover => AppColors.primary,
        TransferRequestStatus.waitingExecution => AppColors.primary,
        TransferRequestStatus.executed => AppColors.successText,
        TransferRequestStatus.completed => AppColors.successText,
        TransferRequestStatus.rejected => AppColors.danger,
        TransferRequestStatus.cancelled => AppColors.neutral,
        TransferRequestStatus.expired => AppColors.neutral,
      };
    }

    return switch (_req.status) {
      ChangeRequestStatus.pending => const Color(0xFFD97706),
      ChangeRequestStatus.underReview => AppColors.deepBlue,
      ChangeRequestStatus.approved => AppColors.successText,
      ChangeRequestStatus.rejected => AppColors.danger,
      ChangeRequestStatus.processing => AppColors.primary,
      ChangeRequestStatus.completed => AppColors.successText,
      ChangeRequestStatus.cancelled => AppColors.neutral,
    };
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '--';
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '--';
    return '${_formatDate(dt)} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.requestStatus,
    this.transferStatus,
    this.displayLabel,
    this.displaySubtitle,
    this.neutral = false,
  });

  final ChangeRequestStatus requestStatus;
  final TransferRequestStatus? transferStatus;
  final String? displayLabel;
  final String? displaySubtitle;
  final bool neutral;

  IconData get _icon {
    if (neutral) return Icons.info_outline_rounded;
    final status = transferStatus;
    if (status != null) {
      return switch (status) {
        TransferRequestStatus.requested => Icons.edit_note_outlined,
        TransferRequestStatus.waitingManagerApproval => Icons.hourglass_empty,
        TransferRequestStatus.managerApproved => Icons.verified_outlined,
        TransferRequestStatus.waitingHolderResponse =>
          Icons.person_outline_rounded,
        TransferRequestStatus.waitingApproval => Icons.hourglass_empty,
        TransferRequestStatus.waitingNewContract => Icons.description_outlined,
        TransferRequestStatus.waitingTargetHolderApproval =>
          Icons.how_to_reg_outlined,
        TransferRequestStatus.waitingTenantConfirmation => Icons.task_outlined,
        TransferRequestStatus.waitingContractConfirmation =>
          Icons.task_outlined,
        TransferRequestStatus.waitingPayment => Icons.payments_outlined,
        TransferRequestStatus.waitingSigning => Icons.draw_outlined,
        TransferRequestStatus.waitingContractSigning => Icons.draw_outlined,
        TransferRequestStatus.waitingTransferDate => Icons.event_outlined,
        TransferRequestStatus.readyForHandover => Icons.move_up_outlined,
        TransferRequestStatus.waitingExecution => Icons.swap_horiz_outlined,
        TransferRequestStatus.executed => Icons.check_circle,
        TransferRequestStatus.completed => Icons.check_circle,
        TransferRequestStatus.rejected => Icons.cancel,
        TransferRequestStatus.cancelled => Icons.block,
        TransferRequestStatus.expired => Icons.schedule_outlined,
      };
    }

    return switch (requestStatus) {
      ChangeRequestStatus.pending => Icons.hourglass_empty,
      ChangeRequestStatus.underReview => Icons.search,
      ChangeRequestStatus.approved => Icons.check_circle,
      ChangeRequestStatus.rejected => Icons.cancel,
      ChangeRequestStatus.processing => Icons.sync,
      ChangeRequestStatus.completed => Icons.check_circle,
      ChangeRequestStatus.cancelled => Icons.block,
    };
  }

  Color get _color {
    if (neutral) return AppColors.deepBlue;
    final status = transferStatus;
    if (status != null) {
      return switch (status) {
        TransferRequestStatus.requested => const Color(0xFFD97706),
        TransferRequestStatus.waitingManagerApproval => const Color(0xFFD97706),
        TransferRequestStatus.managerApproved => AppColors.deepBlue,
        TransferRequestStatus.waitingHolderResponse => const Color(0xFFD97706),
        TransferRequestStatus.waitingApproval => const Color(0xFFD97706),
        TransferRequestStatus.waitingNewContract => AppColors.deepBlue,
        TransferRequestStatus.waitingTargetHolderApproval => const Color(
          0xFFD97706,
        ),
        TransferRequestStatus.waitingTenantConfirmation => AppColors.deepBlue,
        TransferRequestStatus.waitingContractConfirmation => AppColors.deepBlue,
        TransferRequestStatus.waitingPayment => const Color(0xFFD97706),
        TransferRequestStatus.waitingSigning => AppColors.deepBlue,
        TransferRequestStatus.waitingContractSigning => AppColors.deepBlue,
        TransferRequestStatus.waitingTransferDate => AppColors.primary,
        TransferRequestStatus.readyForHandover => AppColors.primary,
        TransferRequestStatus.waitingExecution => AppColors.primary,
        TransferRequestStatus.executed => AppColors.successText,
        TransferRequestStatus.completed => AppColors.successText,
        TransferRequestStatus.rejected => AppColors.danger,
        TransferRequestStatus.cancelled => AppColors.neutral,
        TransferRequestStatus.expired => AppColors.neutral,
      };
    }

    return switch (requestStatus) {
      ChangeRequestStatus.pending => const Color(0xFFD97706),
      ChangeRequestStatus.underReview => AppColors.deepBlue,
      ChangeRequestStatus.approved => AppColors.successText,
      ChangeRequestStatus.rejected => AppColors.danger,
      ChangeRequestStatus.processing => AppColors.primary,
      ChangeRequestStatus.completed => AppColors.successText,
      ChangeRequestStatus.cancelled => AppColors.neutral,
    };
  }

  Color get _bg {
    if (neutral) return AppColors.primarySurface;
    final status = transferStatus;
    if (status != null) {
      return switch (status) {
        TransferRequestStatus.requested => const Color(0xFFFFF7ED),
        TransferRequestStatus.waitingManagerApproval => const Color(0xFFFFF7ED),
        TransferRequestStatus.managerApproved => AppColors.primarySurface,
        TransferRequestStatus.waitingHolderResponse => const Color(0xFFFFF7ED),
        TransferRequestStatus.waitingApproval => const Color(0xFFFFF7ED),
        TransferRequestStatus.waitingNewContract => AppColors.primarySurface,
        TransferRequestStatus.waitingTargetHolderApproval => const Color(
          0xFFFFF7ED,
        ),
        TransferRequestStatus.waitingTenantConfirmation => const Color(
          0xFFEFF1FF,
        ),
        TransferRequestStatus.waitingContractConfirmation => const Color(
          0xFFEFF1FF,
        ),
        TransferRequestStatus.waitingPayment => const Color(0xFFFFF7ED),
        TransferRequestStatus.waitingSigning => AppColors.primarySurface,
        TransferRequestStatus.waitingContractSigning => AppColors.primarySurface,
        TransferRequestStatus.waitingTransferDate => AppColors.infoSurface,
        TransferRequestStatus.readyForHandover => AppColors.infoSurface,
        TransferRequestStatus.waitingExecution => AppColors.infoSurface,
        TransferRequestStatus.executed => const Color(0xFFD4F8DE),
        TransferRequestStatus.completed => const Color(0xFFD4F8DE),
        TransferRequestStatus.rejected => const Color(0xFFFFE4E4),
        TransferRequestStatus.cancelled => const Color(0xFFF5F5F5),
        TransferRequestStatus.expired => const Color(0xFFF5F5F5),
      };
    }

    return switch (requestStatus) {
      ChangeRequestStatus.pending => const Color(0xFFFFF7ED),
      ChangeRequestStatus.underReview => AppColors.primarySurface,
      ChangeRequestStatus.approved => const Color(0xFFD4F8DE),
      ChangeRequestStatus.rejected => const Color(0xFFFFE4E4),
      ChangeRequestStatus.processing => AppColors.primarySurface,
      ChangeRequestStatus.completed => const Color(0xFFD4F8DE),
      ChangeRequestStatus.cancelled => const Color(0xFFF5F5F5),
    };
  }

  String get _label =>
      displayLabel ?? transferStatus?.label ?? requestStatus.label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
      ),
      child: Row(
        children: [
          Icon(_icon, color: _color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label,
                  style: TextStyle(
                    color: _color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle,
                  style: TextStyle(
                    color: _color.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _subtitle {
    if (displaySubtitle != null) return displaySubtitle!;
    final status = transferStatus;
    if (status != null) {
      return switch (status) {
        TransferRequestStatus.requested => 'Yêu cầu chuyển phòng đã được tạo.',
        TransferRequestStatus.waitingManagerApproval =>
          'Yêu cầu đang chờ quản lý phê duyệt.',
        TransferRequestStatus.managerApproved =>
          'Quản lý đã duyệt, chờ bước tiếp theo.',
        TransferRequestStatus.waitingHolderResponse =>
          'Đang chờ người đứng tên hợp đồng mới của phòng cũ phản hồi đề cử.',
        TransferRequestStatus.waitingApproval =>
          'Yêu cầu đang chờ quản lý phê duyệt.',
        TransferRequestStatus.waitingNewContract =>
          'Chờ chọn người đứng tên hoặc tạo hợp đồng mới.',
        TransferRequestStatus.waitingTargetHolderApproval =>
          'Đang chờ chủ phòng đích phê duyệt yêu cầu chuyển vào.',
        TransferRequestStatus.waitingTenantConfirmation =>
          'Chờ người thuê xác nhận phương án chuyển phòng.',
        TransferRequestStatus.waitingContractConfirmation =>
          'Chờ quản lý xác nhận hợp đồng.',
        TransferRequestStatus.waitingPayment =>
          'Cần thanh toán hóa đơn chênh lệch.',
        TransferRequestStatus.waitingSigning =>
          'Chờ quản lý upload hợp đồng đã ký.',
        TransferRequestStatus.waitingContractSigning =>
          'Chờ quản lý upload hợp đồng đã ký.',
        TransferRequestStatus.waitingTransferDate =>
          'Hồ sơ đã sẵn sàng, chờ ngày chuyển.',
        TransferRequestStatus.readyForHandover =>
          'Chờ bàn giao phòng cũ và nhận phòng mới.',
        TransferRequestStatus.waitingExecution =>
          'Phiên chuyển phòng đang diễn ra.',
        TransferRequestStatus.executed =>
          'Việc chuyển phòng đã được thực hiện thành công.',
        TransferRequestStatus.completed => 'Yêu cầu chuyển phòng đã hoàn tất.',
        TransferRequestStatus.rejected => 'Yêu cầu chuyển phòng đã bị từ chối.',
        TransferRequestStatus.cancelled => 'Yêu cầu chuyển phòng đã bị hủy.',
        TransferRequestStatus.expired =>
          'Yêu cầu chuyển phòng đã hết hiệu lực.',
      };
    }

    return switch (requestStatus) {
      ChangeRequestStatus.pending => 'Yêu cầu đang chờ quản lý xem xét.',
      ChangeRequestStatus.underReview =>
        'Quản lý đang xem xét yêu cầu của bạn.',
      ChangeRequestStatus.approved => 'Yêu cầu đã được chấp thuận.',
      ChangeRequestStatus.rejected => 'Yêu cầu đã bị từ chối.',
      ChangeRequestStatus.processing => 'Yêu cầu đang được xử lý.',
      ChangeRequestStatus.completed => 'Yêu cầu đã hoàn tất.',
      ChangeRequestStatus.cancelled => 'Yêu cầu đã bị hủy.',
    };
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.deepBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF000666),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.bodyText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: valueColor ?? AppColors.inputText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.busy = false,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool busy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: busy || !enabled ? null : onTap,
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
        ),
      ),
    );
  }
}

class _TransferLoadingCard extends StatelessWidget {
  const _TransferLoadingCard({
    this.message = 'Đang tải chi tiết chuyển phòng...',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.deepBlue,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.inputText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferLoadStateCard extends StatelessWidget {
  const _TransferLoadStateCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFD97706),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Chưa tải được thông tin',
                style: TextStyle(
                  color: Color(0xFF000666),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.bodyText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Tải lại',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.deepBlue,
                side: const BorderSide(color: AppColors.deepBlue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferActionLoadingCard extends StatelessWidget {
  const _TransferActionLoadingCard({
    this.message = 'Đang xác định hành động khả dụng...',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: const Color(0xFFD7DCFF)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.deepBlue,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.deepBlue,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Target Holder Approval Card ────────────────────────────────────────────

class _TargetHolderApprovalCard extends StatelessWidget {
  const _TargetHolderApprovalCard({
    required this.transfer,
    required this.onApprove,
    required this.onReject,
    this.busy = false,
  });

  final RoomTransferRequest transfer;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.warning, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_add_outlined,
                color: const Color(0xFFD97706),
                size: 22,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Yêu cầu chuyển vào phòng bạn',
                  style: TextStyle(
                    color: AppColors.warningText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Một người dùng đang yêu cầu chuyển vào phòng của bạn. Vui lòng xem xét và phê duyệt hoặc từ chối yêu cầu này.',
            style: TextStyle(
              color: AppColors.warningText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ApprovalButton(
                  label: 'Từ chối',
                  icon: Icons.close_outlined,
                  color: AppColors.danger,
                  busy: busy,
                  onTap: onReject,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ApprovalButton(
                  label: 'Đồng ý',
                  icon: Icons.check_outlined,
                  color: AppColors.successText,
                  busy: busy,
                  onTap: onApprove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovalButton extends StatelessWidget {
  const _ApprovalButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: busy ? null : onTap,
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
        ),
      ),
    );
  }
}

// ── Status Timeline ────────────────────────────────────────────────────────

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({
    required this.currentStatus,
    required this.targetTransferType,
    required this.usesExistingTargetContract,
    required this.remainingOccupantCountAfterTransfer,
    required this.nominatedHolderProfileId,
  });

  final TransferRequestStatus currentStatus;
  final TargetTransferType targetTransferType;
  final bool usesExistingTargetContract;
  final int? remainingOccupantCountAfterTransfer;
  final int? nominatedHolderProfileId;

  bool get _needsSourceHolderNomination {
    return (remainingOccupantCountAfterTransfer ?? 0) > 0;
  }

  List<_TimelineStep> get _steps {
    final steps = <_TimelineStep>[
      _TimelineStep(
        status: TransferRequestStatus.waitingApproval,
        aliases: const [
          TransferRequestStatus.requested,
          TransferRequestStatus.waitingManagerApproval,
          TransferRequestStatus.waitingApproval,
        ],
        label: 'Yêu cầu được tạo',
        icon: Icons.edit_note_outlined,
      ),
      _TimelineStep(
        status: TransferRequestStatus.managerApproved,
        aliases: const [TransferRequestStatus.managerApproved],
        label: 'Quản lý phê duyệt',
        icon: Icons.verified_outlined,
      ),
    ];

    if (_needsSourceHolderNomination) {
      steps.add(
        _TimelineStep(
          status: TransferRequestStatus.waitingNewContract,
          aliases: const [
            TransferRequestStatus.managerApproved,
            TransferRequestStatus.waitingNewContract,
          ],
          label: 'Chọn người đứng tên hợp đồng của phòng cũ',
          icon: Icons.person_outline_rounded,
        ),
      );
      steps.add(
        _TimelineStep(
          status: TransferRequestStatus.waitingHolderResponse,
          aliases: const [TransferRequestStatus.waitingHolderResponse],
          label: 'Chờ người đứng tên hợp đồng của phòng cũ phản hồi',
          icon: Icons.schedule_outlined,
        ),
      );
    }

    if (usesExistingTargetContract) {
      steps.add(
        _TimelineStep(
          status: TransferRequestStatus.waitingTargetHolderApproval,
          aliases: const [TransferRequestStatus.waitingTargetHolderApproval],
          label: 'Chủ phòng đích phê duyệt',
          icon: Icons.how_to_reg_outlined,
        ),
      );
    }

    steps.add(
      _TimelineStep(
        status: TransferRequestStatus.waitingTenantConfirmation,
        aliases: const [
          TransferRequestStatus.waitingTenantConfirmation,
          TransferRequestStatus.waitingPayment,
          TransferRequestStatus.waitingContractConfirmation,
        ],
        label: 'Chờ xác nhận yêu cầu',
        icon: Icons.task_outlined,
      ),
    );

    steps.add(
      _TimelineStep(
        status: TransferRequestStatus.waitingSigning,
        aliases: const [
          TransferRequestStatus.waitingSigning,
          TransferRequestStatus.waitingContractSigning,
        ],
        label: 'Quản lý xử lý ký',
        icon: Icons.draw_outlined,
      ),
    );

    steps.addAll([
      _TimelineStep(
        status: TransferRequestStatus.waitingExecution,
        aliases: const [
          TransferRequestStatus.waitingTransferDate,
          TransferRequestStatus.readyForHandover,
          TransferRequestStatus.waitingExecution,
        ],
        label: 'Chờ thực hiện',
        icon: Icons.swap_horiz_outlined,
      ),
      _TimelineStep(
        status: TransferRequestStatus.executed,
        aliases: const [
          TransferRequestStatus.executed,
          TransferRequestStatus.completed,
        ],
        label: 'Hoàn thành',
        icon: Icons.check_circle_outlined,
      ),
    ]);

    return steps;
  }

  List<TransferRequestStatus> get _statusOrder {
    final statuses = <TransferRequestStatus>[
      TransferRequestStatus.requested,
      TransferRequestStatus.waitingManagerApproval,
      TransferRequestStatus.waitingApproval,
      TransferRequestStatus.managerApproved,
    ];

    if (_needsSourceHolderNomination) {
      statuses.addAll([
        TransferRequestStatus.waitingNewContract,
        TransferRequestStatus.waitingHolderResponse,
      ]);
    }

    if (usesExistingTargetContract) {
      statuses.add(TransferRequestStatus.waitingTargetHolderApproval);
    }

    statuses.addAll([
      TransferRequestStatus.waitingTenantConfirmation,
      TransferRequestStatus.waitingPayment,
      TransferRequestStatus.waitingContractConfirmation,
    ]);

    statuses.addAll([
      TransferRequestStatus.waitingSigning,
      TransferRequestStatus.waitingContractSigning,
    ]);

    statuses.addAll([
      TransferRequestStatus.waitingTransferDate,
      TransferRequestStatus.readyForHandover,
      TransferRequestStatus.waitingExecution,
      TransferRequestStatus.executed,
      TransferRequestStatus.completed,
    ]);

    return statuses;
  }

  int _stepIndex(_TimelineStep step) {
    final statusOrder = _statusOrder;
    final indexes = step.aliases
        .map(statusOrder.indexOf)
        .where((index) => index >= 0)
        .toList(growable: false);
    if (indexes.isEmpty) return -1;
    indexes.sort();
    return indexes.first;
  }

  bool _isCompleted(_TimelineStep step) {
    final statusOrder = _statusOrder;
    final currentIndex = statusOrder.indexWhere((s) => s == currentStatus);
    final stepIndex = _stepIndex(step);

    if (currentStatus == TransferRequestStatus.cancelled ||
        currentStatus == TransferRequestStatus.rejected ||
        currentStatus == TransferRequestStatus.expired ||
        currentIndex < 0 ||
        stepIndex < 0) {
      return false;
    }

    if (step.aliases.contains(currentStatus)) {
      return currentStatus == TransferRequestStatus.executed ||
          currentStatus == TransferRequestStatus.completed;
    }

    return stepIndex < currentIndex;
  }

  bool _isCurrent(_TimelineStep step) {
    if (currentStatus == TransferRequestStatus.executed ||
        currentStatus == TransferRequestStatus.completed) {
      return false;
    }
    return step.aliases.contains(currentStatus);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.timeline_outlined,
                color: AppColors.deepBlue,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Tiến trình xử lý',
                style: TextStyle(
                  color: Color(0xFF000666),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._buildTimelineItems(),
        ],
      ),
    );
  }

  List<Widget> _buildTimelineItems() {
    final widgets = <Widget>[];

    for (int i = 0; i < _steps.length; i++) {
      final step = _steps[i];
      final isCompleted = _isCompleted(step);
      final isCurrent = _isCurrent(step);

      widgets.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.successText
                        : isCurrent
                        ? AppColors.deepBlue
                        : AppColors.neutralBorder,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    step.icon,
                    size: 18,
                    color: isCompleted || isCurrent
                        ? Colors.white
                        : AppColors.bodyText,
                  ),
                ),
                if (i < _steps.length - 1)
                  Container(
                    width: 2,
                    height: 24,
                    color: isCompleted
                        ? AppColors.successText
                        : AppColors.neutralBorder,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  step.label,
                  style: TextStyle(
                    color: isCompleted
                        ? AppColors.successText
                        : isCurrent
                        ? AppColors.deepBlue
                        : AppColors.bodyText,
                    fontSize: 13,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return widgets;
  }
}

class _TimelineStep {
  const _TimelineStep({
    required this.status,
    required this.aliases,
    required this.label,
    required this.icon,
  });

  final TransferRequestStatus status;
  final List<TransferRequestStatus> aliases;
  final String label;
  final IconData icon;
}

// ── Settlement Option Tile ─────────────────────────────────────────────────

class _SettlementChoiceTile extends StatelessWidget {
  const _SettlementChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD1D5DB)),
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
                child: Icon(icon, color: AppColors.deepBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutralStrong,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}
