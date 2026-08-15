import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/change_request/change_request_model.dart';
import 'package:hdbhms_mobile/models/profile_request/tenant_request_model.dart';
import 'package:hdbhms_mobile/models/room_transfer/room_transfer_model.dart';
import 'package:hdbhms_mobile/services/change_request/change_request_service.dart';
import 'package:hdbhms_mobile/services/home/current_room_service.dart';
import 'package:hdbhms_mobile/services/room_transfer/room_transfer_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/utils/room_scope.dart';
import 'package:hdbhms_mobile/widgets/tenant_bottom_navigation.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';
import 'package:hdbhms_mobile/screens/payment/bill_selection_page.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_list_screen.dart';
import 'package:hdbhms_mobile/screens/notification/notification_list_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_profile_screen.dart';
import 'package:hdbhms_mobile/screens/room_transfer/room_transfer_detail_screen.dart';
import 'package:hdbhms_mobile/widgets/app_filter_chip.dart';
import 'package:hdbhms_mobile/widgets/app_notification_bell.dart';
import 'package:hdbhms_mobile/widgets/app_list_state.dart';

String _payloadEnumLabel(Object? value, Map<String, String> labels) {
  final normalized = value?.toString().trim().toUpperCase() ?? '';
  if (normalized.isEmpty) return 'Chưa có thông tin';
  return labels[normalized] ?? 'Chưa xác định';
}

/// Màn "Yêu cầu" – danh sách yêu cầu + filter theo loại
class TenantRequestScreen extends StatefulWidget {
  const TenantRequestScreen({
    super.key,
    this.changeRequestService = const ChangeRequestService(),
    this.roomTransferService = const RoomTransferService(),
    this.currentRoomService = const CurrentRoomService(),
    this.roomId,
    this.roomCode = '',
    this.previewRequests,
    this.previewChangeRequests,
    this.previewRoomTransfers = const {},
    this.previewTenantProfileId,
    this.initialFilterType,
  }) : assert(
         previewRequests == null || previewChangeRequests == null,
         'Only one local preview data source can be supplied.',
       );

  final ChangeRequestService changeRequestService;
  final RoomTransferService roomTransferService;
  final CurrentRoomService currentRoomService;
  final int? roomId;
  final String roomCode;

  /// Local-only data for the internal preview launcher. When supplied, no
  /// request is made to the backend and the regular list/detail UI is reused.
  final List<TenantRequest>? previewRequests;

  /// Local API-shaped data for previews that need the production detail
  /// component, such as the liquidation progress timeline.
  final List<ChangeRequest>? previewChangeRequests;

  /// Linked local transfer data for the internal preview launcher. This keeps
  /// the room-transfer preview on the same dedicated detail screen as the
  /// production flow without contacting the API.
  final Map<int, RoomTransferRequest> previewRoomTransfers;
  final int? previewTenantProfileId;
  final TenantRequestType? initialFilterType;

  @override
  State<TenantRequestScreen> createState() => _TenantRequestScreenState();
}

class _TenantRequestScreenState extends State<TenantRequestScreen>
    with WidgetsBindingObserver {
  // null = Tất cả
  TenantRequestType? _filterType;

  final List<TenantRequest> _requests = [];

  // ChangeRequest objects keyed by their id, for navigating to detail screens
  final Map<int, ChangeRequest> _changeRequestMap = {};
  final Map<int, ChangeRequest> _holderNominationMap = {};
  RoomScope _roomScope = const RoomScope();

  bool _loadingApi = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.previewRequests != null ||
        widget.previewChangeRequests != null) {
      _filterType = widget.initialFilterType;
      if (widget.previewRequests != null) {
        _requests.addAll(widget.previewRequests!);
      }
      for (final request
          in widget.previewChangeRequests ?? const <ChangeRequest>[]) {
        _changeRequestMap[request.id] = request;
        _requests.add(_toTenantRequest(request));
      }
      return;
    }
    _loadApiRequests();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.previewRequests == null &&
        widget.previewChangeRequests == null &&
        state == AppLifecycleState.resumed &&
        mounted &&
        !_loadingApi) {
      _loadApiRequests();
    }
  }

  /// Fetches change requests from the backend API and converts them to
  /// [TenantRequest] objects for display in the unified list.
  Future<void> _loadApiRequests() async {
    if (widget.previewRequests != null ||
        widget.previewChangeRequests != null) {
      return;
    }
    setState(() => _loadingApi = true);
    var apiRequests = const <ChangeRequest>[];
    var holderNominations = const <RoomTransferRequest>[];
    var requestLoadFailed = false;
    final roomScope = await resolveRoomScope(
      roomId: widget.roomId,
      roomCode: widget.roomCode,
      currentRoomService: widget.currentRoomService,
    );

    if (!mounted) return;
    _roomScope = roomScope;

    try {
      final scopedRequests = await widget.changeRequestService.getMyRequests(
        roomId: roomScope.hasRoom ? roomScope.roomId : null,
        roomCode: roomScope.hasRoom ? roomScope.roomCode : null,
      );
      apiRequests = [
        ...scopedRequests.where(
          (request) => request.requestType != ChangeRequestType.roomTransfer,
        ),
      ];
      try {
        final transferRequests = await widget.changeRequestService
            .getMyRequests(type: ChangeRequestType.roomTransfer);
        apiRequests = [
          ...apiRequests,
          ...await _filterTransferRequestsByRoom(transferRequests, roomScope),
        ];
      } catch (_) {
        // Room-transfer details are optional for rendering other request types.
      }
    } catch (_) {
      requestLoadFailed = true;
    }

    try {
      holderNominations = await widget.roomTransferService
          .fetchPendingHolderNominations();
      holderNominations = holderNominations
          .where((transfer) => _transferMatchesRoom(transfer, roomScope))
          .toList(growable: false);
    } catch (_) {
      // Older backends may not expose nomination inbox yet.
    }

    if (!mounted) return;
    setState(() {
      _changeRequestMap.clear();
      _holderNominationMap.clear();

      for (final cr in apiRequests) {
        _changeRequestMap[cr.id] = cr;
      }
      for (final transfer in holderNominations) {
        _holderNominationMap[transfer.id] = _toHolderNominationChangeRequest(
          transfer,
        );
      }

      final holderNominationTransferIds = holderNominations
          .map((transfer) => transfer.id)
          .where((id) => id > 0)
          .toSet();
      final holderNominationCodes = holderNominations
          .map((transfer) => transfer.requestCode.trim())
          .where((code) => code.isNotEmpty)
          .toSet();
      final visibleApiRequests = apiRequests.where((cr) {
        if (cr.requestType != ChangeRequestType.roomTransfer) return true;
        final transferId = _extractTransferId(cr);
        if (transferId != null &&
            holderNominationTransferIds.contains(transferId)) {
          return false;
        }
        return !holderNominationCodes.contains(cr.requestCode.trim());
      });

      final converted = <TenantRequest>[
        ...visibleApiRequests.expand(
          (cr) => [
            _toTenantRequest(cr),
            if (_hasTenantRefundRequest(cr)) _toRefundTenantRequest(cr),
          ],
        ),
        ...holderNominations.map(_toHolderNominationRequest),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _requests
        ..removeWhere(
          (r) =>
              r.id.startsWith('API-') ||
              r.id.startsWith('REFUND-') ||
              r.id.startsWith('NOMINATION-'),
        )
        ..insertAll(0, converted);
      _loadingApi = false;
      _loadError = requestLoadFailed && converted.isEmpty
          ? 'Không tải được danh sách yêu cầu. Vui lòng thử lại.'
          : null;
    });
  }

  /// Maps a [ChangeRequest] to a [TenantRequest] for display.
  TenantRequest _toTenantRequest(ChangeRequest cr) {
    return TenantRequest(
      id: 'API-${cr.id}',
      type: _mapRequestType(cr.requestType),
      status: _mapRequestStatus(cr.status),
      note: _requestNote(cr),
      createdAt: cr.createdAt ?? DateTime.now(),
      details: _requestDetails(cr),
    );
  }

  bool _hasTenantRefundRequest(ChangeRequest cr) {
    if (cr.requestType != ChangeRequestType.contractLiquidation) return false;
    final payload = _payloadOf(cr);
    final amount = num.tryParse(
      payload['depositRefundAmount']?.toString() ?? '',
    );
    final status = payload['depositRefundStatus']?.toString() ?? '';
    return amount != null && amount > 0 && status != 'NOT_REQUIRED';
  }

  TenantRequest _toRefundTenantRequest(ChangeRequest cr) {
    final payload = _payloadOf(cr);
    final refundStatus = payload['depositRefundStatus']?.toString() ?? '';
    final amount = payload['depositRefundAmount'];
    final roomCode = payload['roomCode']?.toString() ?? '';
    return TenantRequest(
      id: 'REFUND-${cr.id}',
      type: TenantRequestType.depositRefundRequest,
      status: _mapRefundRequestStatus(refundStatus),
      note: _refundRequestNote(refundStatus, amount),
      createdAt: cr.createdAt ?? DateTime.now(),
      details: {
        if (roomCode.isNotEmpty) 'Phòng': roomCode,
        'Số tiền hoàn cọc': _formatRequestAmount(amount),
        'Trạng thái hoàn cọc': _refundStatusLabel(refundStatus),
      },
    );
  }

  TenantRequestStatus _mapRefundRequestStatus(String status) {
    if (status == 'TENANT_CONFIRMED') {
      return TenantRequestStatus.approved;
    }
    if (status == 'DISPUTED' ||
        status == 'OWNER_REJECTED' ||
        status == 'CANCELLED') {
      return TenantRequestStatus.rejected;
    }
    if (status == 'WAITING_OWNER_APPROVAL' || status == 'PENDING') {
      return TenantRequestStatus.pending;
    }
    return TenantRequestStatus.processing;
  }

  String _refundRequestNote(String status, Object? amount) {
    final amountText = _formatRequestAmount(amount);
    return switch (status) {
      'APPROVED_WAITING_TENANT_CONFIRMATION' || 'RECORDED_BY_MANAGER' =>
        'Khoản hoàn cọc đã được duyệt, vui lòng xác nhận đã nhận tiền · $amountText',
      'TENANT_CONFIRMED' =>
        'Bạn đã xác nhận đã nhận khoản hoàn cọc · $amountText',
      'WAITING_OWNER_APPROVAL' =>
        'Khoản hoàn cọc đang chờ chủ trọ duyệt · $amountText',
      'DISPUTED' => 'Bạn đã phản hồi về khoản hoàn cọc · $amountText',
      _ => 'Yêu cầu hoàn cọc · $amountText',
    };
  }

  String _refundStatusLabel(String status) {
    return switch (status) {
      'APPROVED_WAITING_TENANT_CONFIRMATION' ||
      'RECORDED_BY_MANAGER' => 'Chờ người thuê xác nhận',
      'TENANT_CONFIRMED' => 'Đã xác nhận',
      'WAITING_OWNER_APPROVAL' => 'Chờ chủ trọ duyệt',
      'DISPUTED' => 'Đang phản hồi',
      'NOT_REQUIRED' => 'Không cần hoàn cọc',
      _ => 'Đang xử lý',
    };
  }

  String _formatRequestAmount(Object? value) {
    final amount = num.tryParse(value?.toString() ?? '');
    if (amount == null) return value?.toString() ?? 'Chưa có thông tin';
    final digits = amount.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return '${buffer.toString()}đ';
  }

  Map<String, String> _requestDetails(ChangeRequest cr) {
    final payload = _payloadOf(cr);
    if (payload.isEmpty) return {};

    final details = <String, String>{};

    String? pick(List<String> keys) {
      for (final key in keys) {
        final value = payload[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    void add(String label, List<String> keys, {String suffix = ''}) {
      final value = pick(keys);
      if (value == null) return;
      details[label] = suffix.isEmpty ? value : '$value $suffix';
    }

    switch (cr.requestType) {
      case ChangeRequestType.roomTransfer:
        add('Phòng hiện tại', ['currentRoom', 'oldRoomCode', 'oldRoomName']);
        add('Phòng mong muốn', ['targetRoom', 'newRoomCode', 'newRoomName']);
        add('Tháng chuyển', ['expectedTransferDate', 'requestedTransferDate']);
        break;
      case ChangeRequestType.contractRenewal:
        add('Mã hợp đồng', ['contractCode']);
        add('Phòng', ['roomCode', 'room']);
        add('Thời gian gia hạn', ['renewalTermMonths'], suffix: 'tháng');
        add('Ngày kết thúc mới', ['newEndDate']);
        break;
      case ChangeRequestType.contractLiquidation:
        add('Mã hợp đồng', ['contractCode']);
        add('Phòng', ['roomCode', 'room']);
        add('Ngày thanh lý', ['liquidationDate']);
        final stage = pick(['liquidationStage']);
        if (stage != null) {
          details['Bước hiện tại'] = _liquidationStageLabel(stage);
        }
        break;
      case ChangeRequestType.moveOut:
        add('Phòng', ['roomCode', 'room']);
        add('Ngày trả phòng dự kiến', ['requestedMoveOutDate']);
        break;
      case ChangeRequestType.addCoOccupant:
        add('Họ và tên', ['fullName', 'name']);
        add('Số điện thoại', ['phone', 'phoneNumber']);
        add('Email', ['email']);
        add('Ngày bắt đầu ở', ['moveInDate']);
        add('Ghi chú', ['note']);
        break;
      case ChangeRequestType.meterReadingCorrection:
        final meterType = pick(['meterType']);
        if (meterType != null) {
          details['Loại đồng hồ'] = _payloadEnumLabel(meterType, const {
            'ELECTRICITY': 'Điện',
            'WATER': 'Nước',
          });
        }
        add('Phòng', ['roomCode', 'room']);
        break;
      case ChangeRequestType.invoiceAdjustment:
        add('Mã hóa đơn', ['invoiceCode']);
        add('Số tiền điều chỉnh', ['adjustmentAmount']);
        break;
      case ChangeRequestType.rentPriceAdjustment:
        add('Phòng', ['roomCode', 'room']);
        add('Giá mới', ['newPrice']);
        break;
      case ChangeRequestType.depositRefundRequest:
        add('Phòng', ['roomCode', 'room']);
        add('Số tiền cọc', ['depositAmount']);
        break;
      case ChangeRequestType.complaint:
        final category = pick(['category']);
        if (category != null) {
          details['Danh mục'] = _payloadEnumLabel(category, const {
            'ELECTRICITY': 'Điện',
            'WATER': 'Nước',
            'INTERNET': 'Internet',
            'FURNITURE': 'Nội thất',
            'AIR_CONDITIONER': 'Máy lạnh',
            'DOOR_LOCK': 'Khóa cửa',
            'CLEANING': 'Vệ sinh',
            'OTHER': 'Khác',
          });
        }
        final priority = pick(['priority']);
        if (priority != null) {
          details['Mức ưu tiên'] = _payloadEnumLabel(priority, const {
            'LOW': 'Thấp',
            'MEDIUM': 'Trung bình',
            'NORMAL': 'Bình thường',
            'HIGH': 'Cao',
            'URGENT': 'Khẩn cấp',
          });
        }
        break;
    }

    return details;
  }

  String _requestNote(ChangeRequest cr) {
    if (cr.requestType != ChangeRequestType.contractLiquidation) {
      return cr.description.isNotEmpty ? cr.description : cr.title;
    }
    final payload = _payloadOf(cr);
    final refundStatus = payload['depositRefundStatus']?.toString();
    final stage = payload['liquidationStage']?.toString();
    if (refundStatus == 'APPROVED_WAITING_TENANT_CONFIRMATION' ||
        refundStatus == 'RECORDED_BY_MANAGER') {
      return 'Khoản hoàn cọc đã được duyệt, vui lòng xác nhận đã nhận tiền.';
    }
    if (refundStatus == 'WAITING_OWNER_APPROVAL') {
      return 'Khoản hoàn cọc đang chờ chủ trọ duyệt.';
    }
    if (refundStatus == 'APPROVED_WAITING_REFUND') {
      return 'Khoản hoàn cọc đã được duyệt, đang chờ hoàn tiền.';
    }
    if (stage == 'WAITING_PAYMENT') {
      return 'Thanh lý hợp đồng · ${_liquidationStageLabel(stage!)}';
    }
    if (stage != null && stage.isNotEmpty) {
      return 'Thanh lý hợp đồng · ${_liquidationStageLabel(stage)}';
    }
    return cr.description.isNotEmpty ? cr.description : cr.title;
  }

  Map<String, dynamic> _payloadOf(ChangeRequest cr) {
    final rawPayload = cr.requestPayload;
    if (rawPayload == null || rawPayload.trim().isEmpty) return {};
    try {
      final payload = jsonDecode(rawPayload);
      return payload is Map<String, dynamic> ? payload : {};
    } catch (_) {
      return {};
    }
  }

  String _liquidationStageLabel(String value) {
    return switch (value) {
      'WAITING_APPROVAL' => 'Chờ duyệt',
      'WAITING_HANDOVER' => 'Chờ bàn giao phòng',
      'WAITING_FINAL_INVOICE' => 'Chờ hóa đơn tất toán',
      'WAITING_PAYMENT' => 'Chờ thanh toán tất toán',
      'WAITING_DEPOSIT_REFUND' => 'Chờ hoàn cọc',
      'WAITING_REPLACEMENT_CONTRACT' => 'Chờ hợp đồng thay thế',
      'WAITING_SIGNED_DOCUMENT' => 'Chờ ký biên bản',
      'READY_TO_CONFIRM' => 'Sẵn sàng xác nhận thanh lý',
      'CONFIRMED' => 'Đã thanh lý',
      _ => 'Chưa cập nhật',
    };
  }

  TenantRequest _toHolderNominationRequest(RoomTransferRequest transfer) {
    final roomName = transfer.oldRoomName.isNotEmpty
        ? transfer.oldRoomName
        : (transfer.oldRoomCode.isNotEmpty
              ? transfer.oldRoomCode
              : '#${transfer.oldRoomId}');
    return TenantRequest(
      id: 'NOMINATION-${transfer.id}',
      type: TenantRequestType.changeRoom,
      status: TenantRequestStatus.pending,
      note:
          'Bạn được đề cử làm người đứng tên hợp đồng mới cho phòng $roomName. Vui lòng xác nhận để yêu cầu chuyển phòng tiếp tục.',
      createdAt: transfer.updatedAt ?? transfer.createdAt ?? DateTime.now(),
      details: {
        'Mã yêu cầu': transfer.requestCode,
        'Phòng hiện tại': roomName,
        'Trạng thái': transfer.status.label,
      },
    );
  }

  ChangeRequest _toHolderNominationChangeRequest(RoomTransferRequest transfer) {
    final payload = jsonEncode({
      'transferRequestId': transfer.id,
      'transferRequestCode': transfer.requestCode,
      'source': 'holderNomination',
    });
    return ChangeRequest(
      id: transfer.id,
      requestCode: transfer.requestCode,
      requestType: ChangeRequestType.roomTransfer,
      title: 'Xác nhận người đứng tên hợp đồng mới',
      description:
          'Bạn được đề cử làm người đứng tên hợp đồng mới cho phòng cũ.',
      status: ChangeRequestStatus.processing,
      requesterId: transfer.requesterId,
      targetId: transfer.id,
      createdAt: transfer.createdAt,
      requestPayload: payload,
    );
  }

  int? _extractTransferId(ChangeRequest cr) {
    if (cr.targetId != null && cr.targetId! > 0) {
      return cr.targetId;
    }

    final rawPayload = cr.requestPayload;
    if (rawPayload == null || rawPayload.trim().isEmpty) return null;
    try {
      final payload = jsonDecode(rawPayload);
      if (payload is! Map<String, dynamic>) return null;
      return int.tryParse(payload['transferRequestId']?.toString() ?? '') ??
          int.tryParse(payload['targetId']?.toString() ?? '') ??
          int.tryParse(payload['id']?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  TenantRequestType _mapRequestType(ChangeRequestType type) {
    return switch (type) {
      ChangeRequestType.roomTransfer => TenantRequestType.changeRoom,
      ChangeRequestType.contractRenewal => TenantRequestType.renewContract,
      ChangeRequestType.contractLiquidation =>
        TenantRequestType.terminateContract,
      ChangeRequestType.moveOut => TenantRequestType.terminateContract,
      ChangeRequestType.addCoOccupant => TenantRequestType.addRoommate,
      ChangeRequestType.meterReadingCorrection =>
        TenantRequestType.utilityComplaint,
      _ => TenantRequestType.renewContract, // fallback for unmapped types
    };
  }

  TenantRequestStatus _mapRequestStatus(ChangeRequestStatus status) {
    return switch (status) {
      ChangeRequestStatus.pending ||
      ChangeRequestStatus.underReview => TenantRequestStatus.pending,
      ChangeRequestStatus.processing => TenantRequestStatus.processing,
      ChangeRequestStatus.approved ||
      ChangeRequestStatus.completed => TenantRequestStatus.approved,
      ChangeRequestStatus.rejected ||
      ChangeRequestStatus.cancelled => TenantRequestStatus.rejected,
    };
  }

  List<TenantRequest> get _filtered {
    if (_filterType == null) return _requests;
    return _requests.where((r) => r.type == _filterType).toList();
  }

  void _openDetail(TenantRequest req) {
    final apiId = req.id.startsWith('API-')
        ? int.tryParse(req.id.substring(4))
        : req.id.startsWith('REFUND-')
        ? int.tryParse(req.id.substring(7))
        : null;
    final nominationId = req.id.startsWith('NOMINATION-')
        ? int.tryParse(req.id.substring('NOMINATION-'.length))
        : null;
    final changeRequest = apiId != null
        ? _changeRequestMap[apiId]
        : (nominationId != null ? _holderNominationMap[nominationId] : null);

    if (changeRequest != null) {
      if (changeRequest.requestType == ChangeRequestType.roomTransfer) {
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) => RoomTransferDetailScreen(
                  changeRequest: changeRequest,
                  initialTransfer:
                      widget.previewRoomTransfers[changeRequest.id],
                  previewCurrentTenantProfileId: widget.previewTenantProfileId,
                ),
              ),
            )
            .then((refreshed) {
              if (refreshed == true) _loadApiRequests();
            });
        return;
      }

      Navigator.of(context)
          .push<bool>(
            MaterialPageRoute(
              builder: (_) => RequestDetailScreen(changeRequest: changeRequest),
            ),
          )
          .then((refreshed) {
            if (refreshed == true) _loadApiRequests();
          });
      return;
    }

    showDialog<void>(
      context: context,
      builder: (_) => _RequestDetailDialog(request: req),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: TenantBottomNavigation(
        activeTab: TenantBottomNavTab.requests,
        onHomeTap: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        onBillsTap: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (context) => BillSelectionPage(
                    roomId: _activeRoomId,
                    roomCode: _activeRoomCode,
                  ),
                ),
              )
              .then((_) => _loadApiRequests());
        },
        onSupportTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MaintenanceTicketListScreen(
                roomId: _activeRoomId,
                roomCode: _activeRoomCode,
              ),
            ),
          );
        },
        onRequestsTap: () {},
        onProfileTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const TenantProfileScreen(),
            ),
          );
        },
      ),
      body: SafeArea(
        child: AppScreenShell(
          header: _buildHeader(),
          child: RefreshIndicator(
            color: AppColors.deepBlue,
            onRefresh:
                widget.previewRequests == null &&
                    widget.previewChangeRequests == null
                ? _loadApiRequests
                : () async {},
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 96),
              children: [
                // ── Tiêu đề danh sách ─────────────────────
                Row(
                  children: [
                    Expanded(child: _sectionTitle('Danh sách yêu cầu')),
                    const SizedBox(width: 12),
                    _RequestCountBadge(count: filtered.length),
                  ],
                ),
                const SizedBox(height: 18),

                // ── Filter chips ───────────────────────────────────
                _FilterBar(
                  active: _filterType,
                  onChanged: (t) => setState(() => _filterType = t),
                ),
                const SizedBox(height: 20),

                // ── List items ────────────────────────────────────
                if (_loadingApi && _requests.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                        color: AppColors.deepBlue,
                      ),
                    ),
                  )
                else if (_loadError != null && _requests.isEmpty)
                  AppListState(
                    kind: AppListStateKind.error,
                    title: 'Không tải được danh sách yêu cầu',
                    description: _loadError!,
                    actionLabel: 'Thử lại',
                    actionIcon: Icons.refresh_rounded,
                    onAction: _loadApiRequests,
                  )
                else if (filtered.isEmpty)
                  _buildEmpty()
                else
                  ...filtered.map(
                    (req) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _RequestCard(
                        request: req,
                        onTap: () => _openDetail(req),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return AppListState(
      kind: AppListStateKind.empty,
      title: _filterType == null
          ? 'Chưa có yêu cầu nào'
          : 'Không có yêu cầu phù hợp',
      description: _filterType == null
          ? 'Các yêu cầu của bạn sẽ hiển thị tại đây.'
          : 'Thử thay đổi bộ lọc để xem các yêu cầu khác.',
      icon: Icons.inbox_outlined,
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
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
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.deepBlue,
              size: 24,
            ),
            tooltip: 'Trở về',
          ),
          const Expanded(
            child: Text('Yêu cầu', style: AppColors.topBarTitleStyle),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NotificationListScreen(),
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: const AppNotificationBell(
              color: AppColors.topBarIconColor,
              size: 24,
            ),
            tooltip: 'Thông báo',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AppTopBar(
      title: 'Yêu cầu',
      pageIcon: Icons.assignment_outlined,
      trailing: IconButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const NotificationListScreen(),
          ),
        ),
        icon: const AppNotificationBell(),
        tooltip: 'Thông báo',
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: AppTypography.sectionTitle);
  }

  int? get _activeRoomId => _roomScope.roomId ?? widget.roomId;

  String get _activeRoomCode =>
      _roomScope.roomCode.isNotEmpty ? _roomScope.roomCode : widget.roomCode;

  bool _transferMatchesRoom(RoomTransferRequest transfer, RoomScope scope) {
    final roomId = scope.roomId;
    if ((roomId ?? 0) > 0 && transfer.oldRoomId == roomId) {
      return true;
    }
    final roomCode = scope.roomCode.trim().toLowerCase();
    if (roomCode.isEmpty) return false;
    return transfer.oldRoomCode.trim().toLowerCase() == roomCode;
  }

  Future<List<ChangeRequest>> _filterTransferRequestsByRoom(
    List<ChangeRequest> requests,
    RoomScope scope,
  ) async {
    final filtered = <ChangeRequest>[];
    for (final request in requests) {
      final transferId = _extractTransferId(request);
      if (transferId == null || transferId <= 0) continue;
      try {
        final transfer = await widget.roomTransferService.getTransferRequest(
          transferId,
        );
        if (_transferMatchesRoom(transfer, scope)) {
          filtered.add(request);
        }
      } catch (_) {
        // Skip transfers that cannot be resolved for this room scope.
      }
    }
    return filtered;
  }
}

class _RequestCountBadge extends StatelessWidget {
  const _RequestCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 11, 7),
      decoration: BoxDecoration(
        color: AppColors.deepBlue,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: 0.24),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 18 / 15,
            ),
          ),
          const SizedBox(width: 3),
          const Text(
            'yêu cầu',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 15 / 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.active, required this.onChanged});

  final TenantRequestType? active;
  final ValueChanged<TenantRequestType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          AppFilterChip(
            label: 'Tất cả',
            isActive: active == null,
            onTap: () => onChanged(null),
          ),
          const SizedBox(width: 8),
          ...TenantRequestType.values.map(
            (t) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppFilterChip(
                label: t.label,
                isActive: active == t,
                onTap: () => onChanged(t),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Request card ─────────────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onTap});

  final TenantRequest request;
  final VoidCallback onTap;

  Color get _accentColor => switch (request.type) {
    TenantRequestType.renewContract => AppColors.actionBlue,
    TenantRequestType.terminateContract => AppColors.danger,
    TenantRequestType.depositRefundRequest => AppColors.successText,
    TenantRequestType.changeRoom => const Color(0xFF0284C7),
    TenantRequestType.addRoommate => AppColors.successText,
    TenantRequestType.utilityComplaint => AppColors.actionAmber,
  };

  Color get _accentBg => switch (request.type) {
    TenantRequestType.renewContract => AppColors.infoSurface,
    TenantRequestType.terminateContract => const Color(0xFFFFF0F0),
    TenantRequestType.depositRefundRequest => const Color(0xFFF0FFF4),
    TenantRequestType.changeRoom => const Color(0xFFEFF8FF),
    TenantRequestType.addRoommate => const Color(0xFFF0FFF4),
    TenantRequestType.utilityComplaint => AppColors.amberSurface,
  };

  @override
  Widget build(BuildContext context) {
    final fields = _summaryFields();
    final note = request.note.trim();
    final showNote =
        request.type == TenantRequestType.depositRefundRequest &&
        note.isNotEmpty;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(
              color: AppColors.cardBorder.withValues(alpha: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: _accentColor.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RequestIconTile(
                    icon: _requestIcon(request.type),
                    color: _accentColor,
                    background: _accentBg,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.type.fullLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.inputText,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 19 / 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          request.type.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.bodyText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 16 / 12,
                          ),
                        ),
                        if (showNote) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              border: Border.all(
                                color: const Color(0xFFFCD34D),
                              ),
                              borderRadius: BorderRadius.circular(
                                AppColors.radiusSm,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.warning_amber_rounded,
                                    color: Color(0xFFD97706),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    note,
                                    style: const TextStyle(
                                      color: Color(0xFF92400E),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      height: 17 / 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(status: request.status),
                ],
              ),
              if (fields.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...fields.map(
                      (field) => _RequestInfoPill(
                        label: field.label,
                        value: field.value,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Spacer(),
                  Text(
                    'Xem chi tiết',
                    style: TextStyle(
                      color: _accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 16 / 12,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: _accentColor,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_RequestSummaryField> _summaryFields() {
    final createdAt = request.createdAt;
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');

    return [
      _RequestSummaryField('Ngày gửi', '$day/$month/${createdAt.year}'),
      _RequestSummaryField('Thời gian gửi', '$hour:$minute'),
    ];
  }
}

class _RequestSummaryField {
  const _RequestSummaryField(this.label, this.value);

  final String label;
  final String value;
}

IconData _requestIcon(TenantRequestType type) {
  return switch (type) {
    TenantRequestType.renewContract => Icons.autorenew_rounded,
    TenantRequestType.terminateContract => Icons.cancel_outlined,
    TenantRequestType.depositRefundRequest =>
      Icons.account_balance_wallet_outlined,
    TenantRequestType.changeRoom => Icons.swap_horiz_rounded,
    TenantRequestType.addRoommate => Icons.person_add_outlined,
    TenantRequestType.utilityComplaint => Icons.speed_outlined,
  };
}

class _TypeTag extends StatelessWidget {
  const _TypeTag({required this.type});

  final TenantRequestType type;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_requestIcon(type), size: 14, color: AppColors.deepBlue),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            type.fullLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.deepBlue,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              height: 15 / 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _RequestIconTile extends StatelessWidget {
  const _RequestIconTile({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _RequestInfoPill extends StatelessWidget {
  const _RequestInfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 128, maxWidth: 156),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.bodyText,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              height: 13 / 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.inputText,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 17 / 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final TenantRequestStatus status;

  Color get _bg => switch (status) {
    TenantRequestStatus.pending => const Color(0xFFFFF7ED),
    TenantRequestStatus.processing => AppColors.primarySurface,
    TenantRequestStatus.approved => const Color(0xFFD4F8DE),
    TenantRequestStatus.rejected => const Color(0xFFFFE4E4),
  };

  Color get _fg => switch (status) {
    TenantRequestStatus.pending => const Color(0xFFD97706),
    TenantRequestStatus.processing => AppColors.deepBlue,
    TenantRequestStatus.approved => AppColors.successText,
    TenantRequestStatus.rejected => AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: _fg,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 14 / 10,
        ),
      ),
    );
  }
}

// ── Request detail dialog ─────────────────────────────────────────────────────
class _RequestDetailDialog extends StatelessWidget {
  const _RequestDetailDialog({required this.request});

  final TenantRequest request;

  IconData get _icon => switch (request.type) {
    TenantRequestType.renewContract => Icons.autorenew_rounded,
    TenantRequestType.terminateContract => Icons.cancel_outlined,
    TenantRequestType.depositRefundRequest =>
      Icons.account_balance_wallet_outlined,
    TenantRequestType.changeRoom => Icons.swap_horiz_rounded,
    TenantRequestType.addRoommate => Icons.person_add_outlined,
    TenantRequestType.utilityComplaint => Icons.speed_outlined,
  };

  Color get _accentColor => switch (request.type) {
    TenantRequestType.renewContract => AppColors.actionBlue,
    TenantRequestType.terminateContract => AppColors.danger,
    TenantRequestType.depositRefundRequest => AppColors.successText,
    TenantRequestType.changeRoom => const Color(0xFF0284C7),
    TenantRequestType.addRoommate => AppColors.successText,
    TenantRequestType.utilityComplaint => AppColors.actionAmber,
  };

  Color get _accentBg => switch (request.type) {
    TenantRequestType.renewContract => AppColors.infoSurface,
    TenantRequestType.terminateContract => const Color(0xFFFFF0F0),
    TenantRequestType.depositRefundRequest => const Color(0xFFF0FFF4),
    TenantRequestType.changeRoom => const Color(0xFFEFF8FF),
    TenantRequestType.addRoommate => const Color(0xFFF0FFF4),
    TenantRequestType.utilityComplaint => AppColors.amberSurface,
  };

  Color get _statusColor => switch (request.status) {
    TenantRequestStatus.pending => const Color(0xFFD97706),
    TenantRequestStatus.processing => AppColors.deepBlue,
    TenantRequestStatus.approved => AppColors.successText,
    TenantRequestStatus.rejected => AppColors.danger,
  };

  String get _detailTitle => switch (request.type) {
    TenantRequestType.renewContract => 'Thông tin gia hạn',
    TenantRequestType.terminateContract => 'Thông tin thanh lý',
    TenantRequestType.depositRefundRequest => 'Thông tin hoàn cọc',
    TenantRequestType.changeRoom => 'Thông tin chuyển phòng',
    TenantRequestType.addRoommate => 'Thông tin người ở cùng',
    TenantRequestType.utilityComplaint => 'Thông tin khiếu nại',
  };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 48),
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _accentBg,
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    ),
                    child: Icon(_icon, color: _accentColor, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.type.fullLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.bodyText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Divider(height: 1, color: Color(0xFFEEECEE)),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _TypeTag(type: request.type),
                        const Spacer(),
                        _StatusBadge(status: request.status),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _DetailSection(
                      title: 'Tổng quan',
                      children: [
                        _DetailRow(label: 'Mã yêu cầu', value: request.id),
                        _DetailRow(
                          label: 'Ngày tạo',
                          value: _formatTime(request.createdAt),
                        ),
                        _DetailRow(
                          label: 'Trạng thái',
                          value: request.status.label,
                          valueColor: _statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _DetailSection(
                      title: _detailTitle,
                      children: _buildTypeDetails(),
                    ),
                    const SizedBox(height: 12),
                    _DetailSection(
                      title: 'Nội dung / ghi chú',
                      children: [
                        Text(
                          request.note,
                          style: const TextStyle(
                            color: AppColors.inputText,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            height: 20 / 13.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                  ),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} $h:$m';
  }

  List<Widget> _buildTypeDetails() {
    final d = request.details;

    return switch (request.type) {
      TenantRequestType.renewContract => [
        _DetailRow(
          label: 'Mã hợp đồng',
          value: d['Mã hợp đồng'] ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Thời gian gia hạn',
          value: d['Thời gian gia hạn'] ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Ngày bắt đầu dự kiến',
          value: d['Ngày bắt đầu dự kiến'] ?? 'Chưa có thông tin',
        ),
      ],
      TenantRequestType.terminateContract => [
        _DetailRow(
          label: 'Mã hợp đồng',
          value: d['Mã hợp đồng'] ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Ngày hết hạn',
          value: d['Ngày hết hạn'] ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Ngày trả phòng dự kiến',
          value: d['Ngày trả phòng dự kiến'] ?? 'Chưa có thông tin',
          valueColor: AppColors.danger,
        ),
      ],
      TenantRequestType.depositRefundRequest => [
        _DetailRow(label: 'Phòng', value: d['Phòng'] ?? 'Chưa có thông tin'),
        _DetailRow(
          label: 'Số tiền hoàn cọc',
          value: d['Số tiền hoàn cọc'] ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Trạng thái hoàn cọc',
          value: d['Trạng thái hoàn cọc'] ?? 'Chưa có thông tin',
        ),
      ],
      TenantRequestType.changeRoom => [
        _DetailRow(
          label: 'Phòng hiện tại',
          value: d['Phòng hiện tại'] ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Phòng mong muốn',
          value: d['Phòng mong muốn'] ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Tầng/khu vực',
          value: d['Tầng/khu vực'] ?? 'Chưa có thông tin',
        ),
      ],
      TenantRequestType.addRoommate => [
        _DetailRow(
          label: 'Họ và tên',
          value: d['Họ và tên'] ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Số điện thoại',
          value: d['Số điện thoại'] ?? 'Chưa có thông tin',
        ),
        _DetailRow(label: 'Email', value: d['Email'] ?? 'Chưa có thông tin'),
        _DetailRow(
          label: 'Ngày bắt đầu ở',
          value: d['Ngày bắt đầu ở'] ?? 'Chưa có thông tin',
        ),
      ],
      TenantRequestType.utilityComplaint => [
        _DetailRow(
          label: 'Loại yêu cầu',
          value: d['Loại yêu cầu'] ?? 'Khiếu nại số điện',
        ),
        _DetailRow(label: 'Phòng', value: d['Phòng'] ?? 'Xem chi tiết yêu cầu'),
      ],
    };
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.children,
    this.icon,
  });

  final String title;
  final List<Widget> children;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  child: Icon(icon, size: 15, color: AppColors.deepBlue),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.metaLabel.copyWith(
                    color: AppColors.deepBlue,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: Text(label, style: AppTypography.metaLabel)),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.metaValue.copyWith(
                color: valueColor ?? AppColors.inputText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiquidationProgressStep {
  const _LiquidationProgressStep({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

class _RequestDetailHero extends StatelessWidget {
  const _RequestDetailHero({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.type,
    required this.requestCode,
    required this.createdAt,
    required this.status,
    required this.statusColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String type;
  final String requestCode;
  final String createdAt;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  type,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cardTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                requestCode.isEmpty ? '--' : requestCode,
                style: AppTypography.metaValue,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: Text(
                  status,
                  style: AppTypography.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text('Tạo lúc $createdAt', style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _ProgressStepRow extends StatelessWidget {
  const _ProgressStepRow({
    required this.step,
    required this.isDone,
    required this.isActive,
    required this.isLast,
    required this.color,
  });

  final _LiquidationProgressStep step;
  final bool isDone;
  final bool isActive;
  final bool isLast;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final muted = !isDone && !isActive;
    final dotColor = isDone || isActive ? color : const Color(0xFFD8DEE9);
    final icon = isDone ? Icons.check_rounded : Icons.circle;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isDone || isActive ? dotColor : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: dotColor, width: 1.4),
                ),
                child: Icon(
                  icon,
                  size: isDone ? 15 : 7,
                  color: isDone || isActive ? Colors.white : dotColor,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 30,
                  color: isDone
                      ? color.withValues(alpha: 0.45)
                      : const Color(0xFFE5E7EB),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      color: muted ? AppColors.bodyText : AppColors.inputText,
                      fontSize: 13,
                      fontWeight: isActive || isDone
                          ? FontWeight.w900
                          : FontWeight.w700,
                      height: 18 / 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle,
                    style: TextStyle(
                      color: muted ? AppColors.bodyText : color,
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                      height: 17 / 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── API Request detail dialog ─────────────────────────────────────────────────────
class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.changeRequest});

  final ChangeRequest changeRequest;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  RoomTransferRequest? _roomTransferRequest;
  bool _loadingTransfer = false;
  bool _submittingRefund = false;

  @override
  void initState() {
    super.initState();
    if (widget.changeRequest.requestType == ChangeRequestType.roomTransfer) {
      _loadRoomTransferData();
    }
  }

  Future<void> _loadRoomTransferData() async {
    final p = widget.changeRequest.requestPayload;
    if (p == null) return;

    try {
      final payload = jsonDecode(p) as Map<String, dynamic>;
      final transferCode = payload['transferRequestCode'] as String?;
      if (transferCode != null && transferCode.isNotEmpty) {
        setState(() => _loadingTransfer = true);
        final service = const RoomTransferService();
        final transfer = await service.getTransferRequestByCode(transferCode);
        if (mounted) {
          setState(() {
            _roomTransferRequest = transfer;
            _loadingTransfer = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingTransfer = false);
      }
    }
  }

  IconData get _icon => switch (widget.changeRequest.requestType) {
    ChangeRequestType.roomTransfer => Icons.swap_horiz_rounded,
    ChangeRequestType.contractRenewal => Icons.autorenew_rounded,
    ChangeRequestType.contractLiquidation => Icons.cancel_outlined,
    ChangeRequestType.moveOut => Icons.cancel_outlined,
    ChangeRequestType.depositRefundRequest =>
      Icons.account_balance_wallet_outlined,
    ChangeRequestType.addCoOccupant => Icons.person_add_outlined,
    ChangeRequestType.complaint => Icons.report_problem_outlined,
    ChangeRequestType.meterReadingCorrection => Icons.speed_outlined,
    ChangeRequestType.invoiceAdjustment => Icons.receipt_long_outlined,
    ChangeRequestType.rentPriceAdjustment => Icons.attach_money_outlined,
  };

  Color get _accentColor => switch (widget.changeRequest.requestType) {
    ChangeRequestType.roomTransfer => const Color(0xFF0284C7),
    ChangeRequestType.contractRenewal => AppColors.actionBlue,
    ChangeRequestType.contractLiquidation => AppColors.danger,
    ChangeRequestType.moveOut => AppColors.danger,
    ChangeRequestType.depositRefundRequest => AppColors.successText,
    ChangeRequestType.addCoOccupant => AppColors.successText,
    ChangeRequestType.complaint => AppColors.actionAmber,
    ChangeRequestType.meterReadingCorrection => AppColors.actionAmber,
    ChangeRequestType.invoiceAdjustment => const Color(0xFF7C3AED),
    ChangeRequestType.rentPriceAdjustment => const Color(0xFF0891B2),
  };

  Color get _accentBg => switch (widget.changeRequest.requestType) {
    ChangeRequestType.roomTransfer => const Color(0xFFEFF8FF),
    ChangeRequestType.contractRenewal => AppColors.infoSurface,
    ChangeRequestType.contractLiquidation => const Color(0xFFFFF0F0),
    ChangeRequestType.moveOut => const Color(0xFFFFF0F0),
    ChangeRequestType.depositRefundRequest => const Color(0xFFF0FFF4),
    ChangeRequestType.addCoOccupant => const Color(0xFFF0FFF4),
    ChangeRequestType.complaint => AppColors.amberSurface,
    ChangeRequestType.meterReadingCorrection => AppColors.amberSurface,
    ChangeRequestType.invoiceAdjustment => const Color(0xFFF3E8FF),
    ChangeRequestType.rentPriceAdjustment => AppColors.primaryLight,
  };

  /// Request progress is semantic: normal progression is green regardless of
  /// the request category, while terminal failures remain danger-coloured.
  Color get _progressAccentColor =>
      widget.changeRequest.requestType == ChangeRequestType.roomTransfer
      ? _accentColor
      : AppColors.successText;

  Color get _statusColor => switch (widget.changeRequest.status) {
    ChangeRequestStatus.pending => const Color(0xFFD97706),
    ChangeRequestStatus.underReview => const Color(0xFF0284C7),
    ChangeRequestStatus.approved => AppColors.successText,
    ChangeRequestStatus.rejected => AppColors.danger,
    ChangeRequestStatus.processing => AppColors.deepBlue,
    ChangeRequestStatus.completed => AppColors.successText,
    ChangeRequestStatus.cancelled => const Color(0xFF9CA3AF),
  };

  Map<String, dynamic> get _payload {
    if (widget.changeRequest.requestPayload == null) return {};
    try {
      return jsonDecode(widget.changeRequest.requestPayload!)
          as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  bool get _canConfirmDepositRefund {
    return widget.changeRequest.requestType ==
            ChangeRequestType.contractLiquidation &&
        !_isHolderReplacementLiquidation &&
        (_payload['depositRefundStatus'] ==
                'APPROVED_WAITING_TENANT_CONFIRMATION' ||
            _payload['depositRefundStatus'] == 'RECORDED_BY_MANAGER');
  }

  bool get _isHolderReplacementLiquidation =>
      _payload['liquidationMode'] == 'PRIMARY_LEAVES_CO_OCCUPANT_STAYS';

  bool get _isLiquidationRequest =>
      widget.changeRequest.requestType == ChangeRequestType.contractLiquidation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              title: 'Chi tiết yêu cầu',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: AppColors.surface),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                      child: _RequestDetailHero(
                        icon: _icon,
                        iconColor: _accentColor,
                        iconBackground: _accentBg,
                        type: widget.changeRequest.requestType.label,
                        requestCode: widget.changeRequest.requestCode,
                        createdAt: _formatTime(widget.changeRequest.createdAt),
                        status: widget.changeRequest.status.label,
                        statusColor: _statusColor,
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isLiquidationRequest) ...[
                              _DetailSection(
                                title: 'Tiến trình thanh lý',
                                icon: Icons.account_tree_outlined,
                                children: _buildLiquidationProgress(_payload),
                              ),
                            ] else ...[
                              _DetailSection(
                                title: 'Tiến trình xử lý',
                                icon: Icons.account_tree_outlined,
                                children: _buildSimpleProgress(),
                              ),
                            ],
                            const SizedBox(height: 12),
                            if (_loadingTransfer)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(
                                    color: AppColors.deepBlue,
                                  ),
                                ),
                              )
                            else
                              ..._buildRequestDetailSections(),
                            if (widget
                                .changeRequest
                                .description
                                .isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _DetailSection(
                                title: 'Nội dung / ghi chú',
                                icon: Icons.notes_outlined,
                                children: [
                                  Text(
                                    widget.changeRequest.description,
                                    style: const TextStyle(
                                      color: AppColors.inputText,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      height: 20 / 13.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            _buildResolutionSection(),
                          ],
                        ),
                      ),
                    ),
                    if (_canConfirmDepositRefund)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton(
                                onPressed: _submittingRefund
                                    ? null
                                    : _confirmDepositRefund,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.successText,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppColors.radiusSm,
                                    ),
                                  ),
                                ),
                                child: _submittingRefund
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Đã nhận tiền cọc',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton(
                                onPressed: _submittingRefund
                                    ? null
                                    : _disputeDepositRefund,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side: const BorderSide(
                                    color: Color(0xFFFECACA),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppColors.radiusSm,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Chưa nhận / Sai số tiền',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'Chưa có thông tin';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} $h:$m';
  }

  Future<void> _confirmDepositRefund() async {
    setState(() => _submittingRefund = true);
    try {
      await const ChangeRequestService().confirmLiquidationDepositReceipt(
        widget.changeRequest.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xác nhận nhận tiền cọc.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(e))));
      setState(() => _submittingRefund = false);
    }
  }

  Future<void> _disputeDepositRefund() async {
    final reason = await _askDisputeReason();
    if (reason == null || reason.trim().isEmpty) return;
    setState(() => _submittingRefund = true);
    try {
      await const ChangeRequestService().disputeLiquidationDepositRefund(
        widget.changeRequest.id,
        reason.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi phản hồi về khoản hoàn cọc.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(e))));
      setState(() => _submittingRefund = false);
    }
  }

  Future<String?> _askDisputeReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Phản hồi hoàn cọc'),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Nhập lý do chưa nhận hoặc sai số tiền',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Gửi'),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  String _errorMessage(Object error) {
    if (error is ChangeRequestException) return error.message;
    return 'Không xử lý được yêu cầu.';
  }

  List<Widget> _buildSimpleProgress() {
    final status = widget.changeRequest.status;
    final finalStatus =
        status == ChangeRequestStatus.approved ||
        status == ChangeRequestStatus.completed ||
        status == ChangeRequestStatus.rejected ||
        status == ChangeRequestStatus.cancelled;
    final processing = status == ChangeRequestStatus.processing;
    final reviewing =
        status == ChangeRequestStatus.pending ||
        status == ChangeRequestStatus.underReview;
    final middleLabel = processing
        ? 'Đang xử lý'
        : status == ChangeRequestStatus.underReview
        ? 'Đang xem xét'
        : status == ChangeRequestStatus.cancelled
        ? 'Đã dừng xử lý'
        : 'Chờ xét duyệt';
    final resultLabel = switch (status) {
      ChangeRequestStatus.approved => 'Đã duyệt',
      ChangeRequestStatus.completed => 'Hoàn tất',
      ChangeRequestStatus.rejected => 'Bị từ chối',
      ChangeRequestStatus.cancelled => 'Đã hủy',
      _ => 'Chưa có kết quả',
    };
    final steps = [
      _LiquidationProgressStep(
        title: 'Đã gửi',
        subtitle: _formatTime(widget.changeRequest.createdAt),
      ),
      _LiquidationProgressStep(
        title: 'Xét duyệt / xử lý',
        subtitle: middleLabel,
      ),
      _LiquidationProgressStep(
        title: 'Kết quả',
        subtitle: finalStatus && widget.changeRequest.resolvedAt != null
            ? '$resultLabel • ${_formatTime(widget.changeRequest.resolvedAt)}'
            : resultLabel,
      ),
    ];
    final currentIndex = finalStatus ? 2 : (processing || reviewing ? 1 : 1);
    final color =
        status == ChangeRequestStatus.rejected ||
            status == ChangeRequestStatus.cancelled
        ? AppColors.danger
        : _progressAccentColor;
    return [
      for (var i = 0; i < steps.length; i++)
        _ProgressStepRow(
          step: steps[i],
          isDone:
              i == 0 ||
              (finalStatus && i < 2) ||
              (finalStatus &&
                  i == 2 &&
                  status != ChangeRequestStatus.rejected &&
                  status != ChangeRequestStatus.cancelled),
          isActive: i == currentIndex,
          isLast: i == steps.length - 1,
          color: color,
        ),
    ];
  }

  List<Widget> _buildLiquidationProgress(Map<String, dynamic> payload) {
    if (_isHolderReplacementLiquidation) {
      return _buildHolderReplacementProgress(payload);
    }
    final stage = payload['liquidationStage']?.toString() ?? '';
    final refundStatus = payload['depositRefundStatus']?.toString() ?? '';
    final currentIndex = _liquidationProgressIndex(stage, refundStatus);
    final rejected =
        widget.changeRequest.status == ChangeRequestStatus.rejected;
    final cancelled =
        widget.changeRequest.status == ChangeRequestStatus.cancelled ||
        refundStatus == 'CANCELLED';
    final disputed = refundStatus == 'DISPUTED';
    final steps = [
      _LiquidationProgressStep(
        title: 'Gửi yêu cầu',
        subtitle: _formatTime(widget.changeRequest.createdAt),
      ),
      _LiquidationProgressStep(
        title: 'Chủ trọ duyệt',
        subtitle: widget.changeRequest.status == ChangeRequestStatus.pending
            ? 'Đang chờ quyết định'
            : widget.changeRequest.status.label,
      ),
      _LiquidationProgressStep(
        title: 'Bàn giao & tất toán',
        subtitle: _stageGroupSubtitle(stage, const {
          'WAITING_HANDOVER',
          'WAITING_FINAL_INVOICE',
          'WAITING_PAYMENT',
        }),
      ),
      _LiquidationProgressStep(
        title: 'Hoàn cọc',
        subtitle: _refundProgressSubtitle(payload, refundStatus),
      ),
      _LiquidationProgressStep(
        title: 'Ký biên bản',
        subtitle: _stageGroupSubtitle(stage, const {
          'WAITING_SIGNED_DOCUMENT',
          'READY_TO_CONFIRM',
        }),
      ),
      _LiquidationProgressStep(
        title: 'Hoàn tất',
        subtitle:
            stage == 'CONFIRMED' ||
                widget.changeRequest.status == ChangeRequestStatus.completed
            ? 'Đã thanh lý hợp đồng'
            : 'Chưa hoàn tất',
      ),
    ];

    return [
      for (var i = 0; i < steps.length; i++)
        _ProgressStepRow(
          step: steps[i],
          isDone: !rejected && !cancelled && !disputed && currentIndex > i,
          isActive: rejected || cancelled || disputed
              ? currentIndex == i
              : currentIndex == i,
          isLast: i == steps.length - 1,
          color: rejected || cancelled || disputed
              ? const Color(0xFFDC2626)
              : _progressAccentColor,
        ),
    ];
  }

  List<Widget> _buildHolderReplacementProgress(Map<String, dynamic> payload) {
    final stage = payload['liquidationStage']?.toString() ?? '';
    final rejected =
        widget.changeRequest.status == ChangeRequestStatus.rejected;
    final cancelled =
        widget.changeRequest.status == ChangeRequestStatus.cancelled;
    final currentIndex = switch (stage) {
      'CONFIRMED' => 3,
      'WAITING_REPLACEMENT_CONTRACT' => 2,
      _ when widget.changeRequest.status == ChangeRequestStatus.completed => 3,
      _ => 1,
    };
    final steps = [
      _LiquidationProgressStep(
        title: 'Gửi yêu cầu',
        subtitle: _formatTime(widget.changeRequest.createdAt),
      ),
      _LiquidationProgressStep(
        title: 'Chủ trọ duyệt',
        subtitle: widget.changeRequest.status == ChangeRequestStatus.pending
            ? 'Đang chờ quyết định'
            : widget.changeRequest.status.label,
      ),
      _LiquidationProgressStep(
        title: 'Hợp đồng thay thế',
        subtitle: stage == 'WAITING_REPLACEMENT_CONTRACT'
            ? 'Đang chờ lập hợp đồng thay thế'
            : 'Chưa tới bước này',
      ),
      _LiquidationProgressStep(
        title: 'Hoàn tất',
        subtitle: currentIndex == 3
            ? 'Đã hoàn tất thay đổi người đứng tên'
            : 'Chưa hoàn tất',
      ),
    ];

    return [
      for (var i = 0; i < steps.length; i++)
        _ProgressStepRow(
          step: steps[i],
          isDone: !rejected && !cancelled && currentIndex > i,
          isActive: currentIndex == i,
          isLast: i == steps.length - 1,
          color: rejected || cancelled
              ? AppColors.danger
              : _progressAccentColor,
        ),
    ];
  }

  int _liquidationProgressIndex(String stage, String refundStatus) {
    if (widget.changeRequest.status == ChangeRequestStatus.rejected ||
        widget.changeRequest.status == ChangeRequestStatus.cancelled) {
      return 1;
    }
    if (widget.changeRequest.status == ChangeRequestStatus.completed) {
      return 5;
    }
    if (stage.isEmpty || stage == 'WAITING_APPROVAL') {
      return 1;
    }
    if (refundStatus == 'DISPUTED' ||
        refundStatus == 'WAITING_OWNER_APPROVAL' ||
        refundStatus == 'APPROVED_WAITING_REFUND' ||
        refundStatus == 'RECORDED_BY_MANAGER') {
      return 3;
    }
    if (refundStatus == 'TENANT_CONFIRMED' || refundStatus == 'NOT_REQUIRED') {
      return 4;
    }
    if (stage == 'WAITING_PAYMENT') {
      return 2;
    }
    return switch (stage) {
      'WAITING_APPROVAL' || '' => 1,
      'WAITING_HANDOVER' || 'WAITING_FINAL_INVOICE' || 'WAITING_PAYMENT' => 2,
      'WAITING_DEPOSIT_REFUND' =>
        refundStatus == 'TENANT_CONFIRMED' || refundStatus == 'NOT_REQUIRED'
            ? 4
            : 3,
      'WAITING_SIGNED_DOCUMENT' || 'READY_TO_CONFIRM' => 4,
      'CONFIRMED' => 5,
      _ => 1,
    };
  }

  String _stageGroupSubtitle(String stage, Set<String> activeStages) {
    if (activeStages.contains(stage)) return _stageLabel(stage);
    return 'Chưa tới bước này';
  }

  String _refundProgressSubtitle(
    Map<String, dynamic> payload,
    String refundStatus,
  ) {
    final amount = _firstPayloadValue(payload, ['depositRefundAmount']);
    final amountText = amount == null || amount.toString().trim().isEmpty
        ? ''
        : ' · ${_formatMoney(amount)}';
    if (refundStatus.isEmpty || refundStatus == 'PENDING') {
      return 'Chờ ghi nhận hoàn cọc$amountText';
    }
    return '${_refundStatusLabel(refundStatus)}$amountText';
  }

  List<Widget> _buildRequestDetailSections() {
    final p = _payload;
    _DetailSection section(String title, IconData icon, List<Widget> rows) =>
        _DetailSection(title: title, icon: icon, children: rows);

    switch (widget.changeRequest.requestType) {
      case ChangeRequestType.contractRenewal:
        return [
          section('Hợp đồng', Icons.description_outlined, [
            _DetailRow(
              label: 'Phòng hiện tại',
              value: _requiredPayloadText(p, ['roomCode']),
            ),
            _DetailRow(
              label: 'Mã hợp đồng',
              value: _requiredPayloadText(p, ['contractCode']),
            ),
            _DetailRow(
              label: 'Ngày bắt đầu',
              value: _payloadDate(p, ['startDate']),
            ),
            _DetailRow(
              label: 'Hết hạn cũ',
              value: _payloadDate(p, ['oldEndDate', 'endDate']),
            ),
          ]),
          const SizedBox(height: 12),
          section('Nội dung gia hạn', Icons.autorenew_rounded, [
            _DetailRow(
              label: 'Thời hạn',
              value: _monthValue(p, 'renewalTermMonths'),
            ),
            _DetailRow(
              label: 'Bắt đầu mới',
              value: _payloadDate(p, ['newStartDate']),
            ),
            _DetailRow(
              label: 'Kết thúc mới',
              value: _payloadDate(p, ['newEndDate']),
            ),
            _DetailRow(
              label: 'Giá thuê',
              value: _payloadMoney(p, ['monthlyRent']),
            ),
            _DetailRow(
              label: 'Chu kỳ thanh toán',
              value: _monthValue(p, 'paymentCycleMonths'),
            ),
            _DetailRow(
              label: 'Tiền cọc',
              value: _payloadMoney(p, ['depositAmount']),
            ),
            if (_hasPayloadValue(p, ['note']))
              _DetailRow(label: 'Ghi chú', value: _payloadText(p, ['note'])),
          ]),
        ];
      case ChangeRequestType.addCoOccupant:
        return [
          section('Hợp đồng', Icons.description_outlined, [
            _DetailRow(
              label: 'Mã hợp đồng',
              value: _requiredPayloadText(p, ['contractCode']),
            ),
            _DetailRow(
              label: 'Phòng',
              value: _requiredPayloadText(p, ['roomCode']),
            ),
          ]),
          const SizedBox(height: 12),
          section('Thông tin người ở cùng', Icons.person_outline_rounded, [
            _DetailRow(
              label: 'Họ và tên',
              value: _requiredPayloadText(p, ['fullName']),
            ),
            _DetailRow(
              label: 'Số điện thoại',
              value: _requiredPayloadText(p, ['phone', 'phoneNumber']),
            ),
            if (_hasPayloadValue(p, ['email']))
              _DetailRow(label: 'Email', value: _payloadText(p, ['email'])),
            if (_hasPayloadValue(p, ['moveInDate']))
              _DetailRow(
                label: 'Ngày bắt đầu ở',
                value: _payloadDate(p, ['moveInDate']),
              ),
            if (_hasPayloadValue(p, ['note']))
              _DetailRow(label: 'Ghi chú', value: _payloadText(p, ['note'])),
          ]),
        ];
      case ChangeRequestType.meterReadingCorrection:
        return [
          section('Hóa đơn', Icons.receipt_long_outlined, [
            _DetailRow(
              label: 'Mã hóa đơn',
              value: _requiredPayloadText(p, ['invoiceCode']),
            ),
            _DetailRow(
              label: 'Phòng',
              value: _requiredPayloadText(p, ['roomCode']),
            ),
            _DetailRow(
              label: 'Kỳ hóa đơn',
              value: _billingPeriod(p['billingPeriod']),
            ),
          ]),
          const SizedBox(height: 12),
          section('Chỉ số điện', Icons.bolt_outlined, [
            _DetailRow(
              label: 'Chỉ số tháng trước',
              value: _meterValue(p, 'previousValue', 'kWh'),
            ),
            _DetailRow(
              label: 'Chỉ số tháng này',
              value: _meterValue(p, 'currentValue', 'kWh'),
            ),
            _DetailRow(
              label: 'Chỉ số bạn báo',
              value: _meterValue(p, 'reportedCurrentValue', 'kWh'),
            ),
            _DetailRow(
              label: 'Lượng tiêu thụ',
              value: _meterValue(p, 'usageAmount', 'kWh'),
            ),
            _DetailRow(
              label: 'Đơn giá',
              value: _meterValue(p, 'unitPrice', 'đ/kWh'),
            ),
            _DetailRow(
              label: 'Thành tiền',
              value: _meterValue(p, 'lineAmount', 'đ'),
            ),
          ]),
          if (_hasPayloadValue(p, ['description'])) ...[
            const SizedBox(height: 12),
            section('Nội dung khiếu nại', Icons.notes_outlined, [
              Text(_payloadText(p, ['description']), style: AppTypography.body),
            ]),
          ],
        ];
      default:
        return [
          section('Chi tiết', Icons.info_outline_rounded, _buildTypeDetails()),
        ];
    }
  }

  Widget _buildResolutionSection() {
    final rejected =
        widget.changeRequest.status == ChangeRequestStatus.rejected;
    final note = widget.changeRequest.resolutionNote?.trim();
    final hasNote = note != null && note.isNotEmpty;
    final updatedAt = widget.changeRequest.resolvedAt;
    return _DetailSection(
      title: rejected ? 'Lý do từ chối' : 'Phản hồi quản lý',
      icon: rejected ? Icons.error_outline_rounded : Icons.chat_outlined,
      children: [
        Text(
          hasNote ? note : 'Chưa có phản hồi',
          style: AppTypography.body.copyWith(
            color: hasNote
                ? (rejected ? AppColors.danger : AppColors.inputText)
                : AppColors.bodyText,
          ),
        ),
        if (updatedAt != null) ...[
          const SizedBox(height: 6),
          Text(
            'Cập nhật ${_formatTime(updatedAt)}',
            style: AppTypography.caption,
          ),
        ],
      ],
    );
  }

  List<Widget> _buildTypeDetails() {
    // If room transfer data is available, use it
    if (widget.changeRequest.requestType == ChangeRequestType.roomTransfer &&
        _roomTransferRequest != null) {
      final tr = _roomTransferRequest!;
      return [
        _DetailRow(
          label: 'Phòng hiện tại',
          value: tr.oldRoomName.isNotEmpty
              ? tr.oldRoomName
              : 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Phòng đích',
          value: tr.targetRoomName.isNotEmpty
              ? tr.targetRoomName
              : 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Tháng chuyển dự kiến',
          value: _formatDate(tr.requestedTransferDate),
        ),
        if (tr.reason.isNotEmpty) _DetailRow(label: 'Lý do', value: tr.reason),
      ];
    }

    // Fallback to payload
    final p = _payload;

    return switch (widget.changeRequest.requestType) {
      ChangeRequestType.roomTransfer => [
        _DetailRow(
          label: 'Phòng hiện tại',
          value: p['currentRoom']?.toString() ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Phòng đích',
          value: p['targetRoom']?.toString() ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Tháng chuyển dự kiến',
          value:
              (p['expectedTransferDate'] ?? p['requestedTransferDate'])
                  ?.toString() ??
              'Chưa có thông tin',
        ),
      ],
      ChangeRequestType.contractRenewal => [
        _DetailRow(
          label: 'Mã hợp đồng',
          value: p['contractCode']?.toString() ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Phòng',
          value: p['roomCode']?.toString() ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Ngày hết hạn cũ',
          value: p['oldEndDate']?.toString() ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Ngày kết thúc sau gia hạn',
          value: p['newEndDate']?.toString() ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Thời hạn gia hạn',
          value: p['renewalTermMonths'] == null
              ? 'Chưa có thông tin'
              : '${p['renewalTermMonths']} tháng',
        ),
        _DetailRow(
          label: 'Tiền thuê',
          value: p['monthlyRent']?.toString() ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Tiền cọc',
          value: p['depositAmount']?.toString() ?? 'Chưa có thông tin',
        ),
        if (p['note'] != null && p['note'].toString().isNotEmpty)
          _DetailRow(label: 'Ghi chú', value: p['note'].toString()),
      ],
      ChangeRequestType.contractLiquidation => _buildLiquidationDetails(p),
      ChangeRequestType.moveOut => [
        _DetailRow(
          label: 'Phòng',
          value: p['room']?.toString() ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Ngày trả phòng dự kiến',
          value: p['requestedMoveOutDate']?.toString() ?? 'Chưa có thông tin',
        ),
      ],
      ChangeRequestType.depositRefundRequest => [
        _DetailRow(
          label: 'Phòng',
          value: p['room']?.toString() ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Số tiền cọc',
          value: p['depositAmount']?.toString() ?? 'Chưa có thông tin',
        ),
      ],
      ChangeRequestType.addCoOccupant => [
        _DetailRow(
          label: 'Họ tên',
          value: p['fullName']?.toString() ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Số điện thoại',
          value: _payloadText(p, ['phone', 'phoneNumber']),
        ),
        if (_payloadText(p, ['email']) != 'Chưa có thông tin')
          _DetailRow(label: 'Email', value: _payloadText(p, ['email'])),
        _DetailRow(
          label: 'Ngày bắt đầu ở',
          value: p['moveInDate']?.toString() ?? 'Chưa có thông tin',
        ),
        if (_payloadText(p, ['note']) != 'Chưa có thông tin')
          _DetailRow(label: 'Ghi chú', value: _payloadText(p, ['note'])),
      ],
      ChangeRequestType.complaint => [
        _DetailRow(
          label: 'Danh mục',
          value: _payloadEnumLabel(p['category'], const {
            'ELECTRICITY': 'Điện',
            'WATER': 'Nước',
            'INTERNET': 'Internet',
            'FURNITURE': 'Nội thất',
            'AIR_CONDITIONER': 'Máy lạnh',
            'DOOR_LOCK': 'Khóa cửa',
            'CLEANING': 'Vệ sinh',
            'OTHER': 'Khác',
          }),
        ),
        _DetailRow(
          label: 'Mức độ ưu tiên',
          value: _payloadEnumLabel(p['priority'], const {
            'LOW': 'Thấp',
            'MEDIUM': 'Trung bình',
            'NORMAL': 'Bình thường',
            'HIGH': 'Cao',
            'URGENT': 'Khẩn cấp',
          }),
        ),
      ],
      ChangeRequestType.meterReadingCorrection => [
        _DetailRow(
          label: 'Loại đồng hồ',
          value: _payloadEnumLabel(p['meterType'], const {
            'ELECTRICITY': 'Điện',
            'WATER': 'Nước',
          }),
        ),
        _DetailRow(
          label: 'Mã hóa đơn',
          value: _payloadText(p, ['invoiceCode']),
        ),
        _DetailRow(label: 'Phòng', value: _payloadText(p, ['roomCode'])),
        _DetailRow(
          label: 'Kỳ hóa đơn',
          value: _payloadText(p, ['billingPeriod']),
        ),
        _DetailRow(
          label: 'Chỉ số cũ',
          value: _meterValue(p, 'previousValue', 'kWh'),
        ),
        _DetailRow(
          label: 'Chỉ số trên hóa đơn',
          value: _meterValue(p, 'currentValue', 'kWh'),
        ),
        _DetailRow(
          label: 'Chỉ số bạn báo',
          value: _meterValue(p, 'reportedCurrentValue', 'kWh'),
        ),
        _DetailRow(
          label: 'Sản lượng',
          value: _meterValue(p, 'usageAmount', 'kWh'),
        ),
        _DetailRow(
          label: 'Đơn giá',
          value: _meterValue(p, 'unitPrice', 'đ/kWh'),
        ),
        _DetailRow(
          label: 'Thành tiền',
          value: _meterValue(p, 'lineAmount', 'đ'),
        ),
        if (_payloadText(p, ['description']) != 'Chưa có thông tin')
          _DetailRow(label: 'Mô tả', value: _payloadText(p, ['description'])),
      ],
      ChangeRequestType.invoiceAdjustment => [
        _DetailRow(
          label: 'Mã hóa đơn',
          value: p['invoiceCode']?.toString() ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Số tiền điều chỉnh',
          value: p['adjustmentAmount']?.toString() ?? 'Chưa có thông tin',
        ),
      ],
      ChangeRequestType.rentPriceAdjustment => [
        _DetailRow(
          label: 'Phòng',
          value: p['room']?.toString() ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Giá cũ',
          value: p['oldPrice']?.toString() ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Giá mới',
          value: p['newPrice']?.toString() ?? 'Chưa có thông tin',
        ),
      ],
    };
  }

  List<Widget> _buildLiquidationDetails(Map<String, dynamic> p) {
    final rows = <Widget>[
      _DetailRow(
        label: 'Mã hợp đồng',
        value: _payloadText(p, ['contractCode']),
      ),
      _DetailRow(label: 'Phòng', value: _payloadText(p, ['roomCode'])),
      _DetailRow(
        label: 'Ngày thanh lý',
        value: _payloadText(p, ['liquidationDate']),
      ),
    ];

    final stage = p['liquidationStage']?.toString();
    if (stage != null && stage.isNotEmpty) {
      rows.add(_DetailRow(label: 'Bước hiện tại', value: _stageLabel(stage)));
    }

    final refundStatus = p['depositRefundStatus']?.toString();
    if (refundStatus != null && refundStatus.isNotEmpty) {
      rows.add(
        _DetailRow(
          label: 'Trạng thái hoàn cọc',
          value: _refundStatusLabel(refundStatus),
          valueColor: _refundStatusColor(refundStatus),
        ),
      );
    }

    _addMoneyRow(rows, p, 'Cọc ban đầu', ['depositAmount']);
    _addMoneyRow(rows, p, 'Cấn trừ công nợ', ['depositOffsetAmount']);
    _addMoneyRow(rows, p, 'Cọc phải hoàn', ['depositRefundAmount']);
    _addMoneyRow(rows, p, 'Đã ghi nhận hoàn', ['depositRefundedAmount']);
    final refundMethod = _firstPayloadValue(p, ['depositRefundMethod']);
    if (refundMethod != null && refundMethod.toString().trim().isNotEmpty) {
      rows.add(
        _DetailRow(
          label: 'Phương thức hoàn',
          value: _refundMethodLabel(refundMethod.toString()),
        ),
      );
    }
    _addOptionalRow(rows, p, 'Ngày hoàn', ['depositRefundedAt']);
    _addOptionalRow(rows, p, 'Mã giao dịch', [
      'depositRefundTransactionRef',
      'depositRefundTransactionCode',
    ]);
    _addOptionalRow(rows, p, 'Chứng từ', ['depositRefundProofFileId']);
    _addOptionalRow(rows, p, 'Ghi chú hoàn cọc', ['depositRefundNote']);

    final reason = p['reason']?.toString();
    if (reason != null && reason.isNotEmpty) {
      rows.add(_DetailRow(label: 'Lý do', value: reason));
    }
    return rows;
  }

  void _addOptionalRow(
    List<Widget> rows,
    Map<String, dynamic> payload,
    String label,
    List<String> keys,
  ) {
    final value = _firstPayloadValue(payload, keys);
    if (value == null || value.toString().trim().isEmpty) return;
    rows.add(_DetailRow(label: label, value: value.toString()));
  }

  void _addMoneyRow(
    List<Widget> rows,
    Map<String, dynamic> payload,
    String label,
    List<String> keys,
  ) {
    final value = _firstPayloadValue(payload, keys);
    if (value == null || value.toString().trim().isEmpty) return;
    rows.add(_DetailRow(label: label, value: _formatMoney(value)));
  }

  Object? _firstPayloadValue(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = payload[key];
      if (value != null) return value;
    }
    return null;
  }

  String _payloadText(Map<String, dynamic> payload, List<String> keys) {
    final value = _firstPayloadValue(payload, keys);
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Chưa có thông tin' : text;
  }

  String _payloadEnumLabel(Object? value, Map<String, String> labels) {
    final normalized = value?.toString().trim().toUpperCase() ?? '';
    if (normalized.isEmpty) return 'Chưa có thông tin';
    return labels[normalized] ?? 'Chưa xác định';
  }

  String _requiredPayloadText(Map<String, dynamic> payload, List<String> keys) {
    final value = _firstPayloadValue(payload, keys)?.toString().trim() ?? '';
    return value.isEmpty ? '--' : value;
  }

  String _payloadDate(Map<String, dynamic> payload, List<String> keys) {
    final raw = _requiredPayloadText(payload, keys);
    if (raw == '--') return raw;
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? raw : _formatDate(parsed);
  }

  String _billingPeriod(Object? value) {
    final raw = value?.toString().trim() ?? '';
    final match = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(raw);
    if (match == null) return raw.isEmpty ? '--' : raw;
    return '${match.group(2)!.padLeft(2, '0')}/${match.group(1)}';
  }

  String _payloadMoney(Map<String, dynamic> payload, List<String> keys) {
    final value = _firstPayloadValue(payload, keys);
    if (value == null || value.toString().trim().isEmpty) return '--';
    return _formatMoney(value);
  }

  String _monthValue(Map<String, dynamic> payload, String key) {
    final value = _requiredPayloadText(payload, [key]);
    return value == '--' ? value : '$value tháng';
  }

  bool _hasPayloadValue(Map<String, dynamic> payload, List<String> keys) {
    final value = _firstPayloadValue(payload, keys)?.toString().trim() ?? '';
    return value.isNotEmpty;
  }

  String _meterValue(Map<String, dynamic> payload, String key, String unit) {
    final value = _payloadText(payload, [key]);
    return value == 'Chưa có thông tin' ? value : '$value $unit';
  }

  String _stageLabel(String value) {
    return switch (value) {
      'WAITING_APPROVAL' => 'Chờ duyệt',
      'WAITING_HANDOVER' => 'Chờ bàn giao phòng',
      'WAITING_FINAL_INVOICE' => 'Chờ hóa đơn tất toán',
      'WAITING_PAYMENT' => 'Chờ thanh toán tất toán',
      'WAITING_DEPOSIT_REFUND' => 'Chờ hoàn cọc',
      'WAITING_REPLACEMENT_CONTRACT' => 'Chờ hợp đồng thay thế',
      'WAITING_SIGNED_DOCUMENT' => 'Chờ ký biên bản',
      'READY_TO_CONFIRM' => 'Sẵn sàng xác nhận thanh lý',
      'CONFIRMED' => 'Đã thanh lý',
      _ => 'Chưa cập nhật',
    };
  }

  String _refundStatusLabel(String value) {
    return switch (value) {
      'NOT_REQUIRED' => 'Không cần hoàn cọc',
      'PENDING' => 'Chờ quản lý ghi nhận',
      'WAITING_OWNER_APPROVAL' => 'Chờ chủ trọ duyệt',
      'APPROVED_WAITING_REFUND' => 'Đã duyệt, chờ hoàn tiền',
      'APPROVED_WAITING_TENANT_CONFIRMATION' ||
      'RECORDED_BY_MANAGER' => 'Chờ bạn xác nhận đã nhận tiền',
      'TENANT_CONFIRMED' => 'Bạn đã xác nhận nhận tiền',
      'DISPUTED' => 'Đang phản hồi/tranh chấp',
      'OWNER_REJECTED' => 'Chủ trọ từ chối',
      'OVERRIDDEN' => 'Chủ sở hữu đã xác nhận',
      'CANCELLED' => 'Đã hủy',
      _ => 'Chưa cập nhật',
    };
  }

  String _refundMethodLabel(String value) {
    return switch (value.trim().toUpperCase()) {
      'BANK_TRANSFER' || 'TRANSFER' => 'Chuyển khoản',
      'CASH' => 'Tiền mặt',
      'WALLET' => 'Ví điện tử',
      _ => 'Chưa xác định',
    };
  }

  Color _refundStatusColor(String value) {
    if (value == 'TENANT_CONFIRMED' || value == 'NOT_REQUIRED') {
      return AppColors.successText;
    }
    if (value == 'RECORDED_BY_MANAGER' || value == 'APPROVED_WAITING_REFUND') {
      return AppColors.deepBlue;
    }
    if (value == 'WAITING_OWNER_APPROVAL') return const Color(0xFFD97706);
    if (value == 'DISPUTED') return AppColors.danger;
    if (value == 'OVERRIDDEN') return const Color(0xFF7C3AED);
    return AppColors.bodyText;
  }

  String _formatMoney(Object value) {
    final raw = value.toString();
    final amount = num.tryParse(raw.replaceAll(RegExp(r'[^0-9.-]'), ''));
    if (amount == null) return raw;
    final digits = amount.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return '${buffer.toString()}đ';
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Chưa có thông tin';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
