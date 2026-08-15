import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/widgets/app_empty_state.dart';
import 'package:hdbhms_mobile/screens/notification/notification_list_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_request_screen.dart';

import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/models/contract/lease_contract_model.dart';
import 'package:hdbhms_mobile/models/profile_request/tenant_request_model.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/services/room_transfer/room_transfer_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/utils/currency_formatter.dart';
import 'package:hdbhms_mobile/utils/document_filename.dart';
import 'package:hdbhms_mobile/widgets/tenant_bottom_navigation.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/screens/payment/bill_selection_page.dart';
import 'package:hdbhms_mobile/screens/contract/contract_pdf_viewer_screen.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_list_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_profile_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/add_roommate_request_screen.dart';
import 'package:hdbhms_mobile/screens/room_transfer/create_room_transfer_screen.dart';
import 'package:hdbhms_mobile/screens/contract/renew_contract_request_screen.dart';
import 'package:hdbhms_mobile/screens/contract/terminate_contract_screen.dart';
import 'package:hdbhms_mobile/screens/contract/room_amenities_screen.dart';
import 'package:hdbhms_mobile/widgets/app_action_tile.dart';
import 'package:hdbhms_mobile/widgets/app_notification_bell.dart';

class LeaseContractScreen extends StatefulWidget {
  const LeaseContractScreen({
    super.key,
    this.contractId,
    this.contractService = const LeaseContractService(),
    this.roomTransferService = const RoomTransferService(),
  });

  final int? contractId;
  final LeaseContractService contractService;
  final RoomTransferService roomTransferService;

  @override
  State<LeaseContractScreen> createState() => _LeaseContractScreenState();
}

class _LeaseContractScreenState extends State<LeaseContractScreen> {
  late Future<LeaseContract> _contractFuture;
  int? _roomId;
  String _roomCode = '';
  int? _resolvedMaxOccupants;

  @override
  void initState() {
    super.initState();
    _contractFuture = _loadContract();
  }

  Future<LeaseContract> _loadContract() async {
    final id = widget.contractId;
    final contract = id != null
        ? await widget.contractService.getContractById(id)
        : await widget.contractService.getMyActiveContract();
    await _resolveRoomCapacity(contract);
    _syncRoomScope(contract);
    return contract;
  }

  Future<void> _resolveRoomCapacity(LeaseContract contract) async {
    final embeddedCapacity = contract.room.maxOccupants;
    if (embeddedCapacity != null && embeddedCapacity > 0) {
      _resolvedMaxOccupants = embeddedCapacity;
      return;
    }
    final propertyId = contract.room.propertyId;
    final roomId = contract.room.id;
    if (propertyId == null ||
        propertyId <= 0 ||
        roomId == null ||
        roomId <= 0) {
      _resolvedMaxOccupants = null;
      return;
    }
    try {
      final rooms = await widget.roomTransferService.fetchAvailableRooms(
        propertyId: propertyId,
        size: 100,
      );
      final room = rooms.where((item) => item.id == roomId).firstOrNull;
      _resolvedMaxOccupants = room != null && room.maxOccupants > 0
          ? room.maxOccupants
          : null;
    } catch (_) {
      // Capacity is a progressive enhancement. Leave the action enabled when
      // the existing read-only room catalog cannot be resolved.
      _resolvedMaxOccupants = null;
    }
  }

  void _syncRoomScope(LeaseContract contract) {
    final nextRoomId = contract.room.id;
    final nextRoomCode = contract.room.roomCode.trim();
    if (_roomId == nextRoomId && _roomCode == nextRoomCode) return;
    if (!mounted) {
      _roomId = nextRoomId;
      _roomCode = nextRoomCode;
      return;
    }
    setState(() {
      _roomId = nextRoomId;
      _roomCode = nextRoomCode;
    });
  }

  void _retry() {
    setState(() {
      _contractFuture = _loadContract();
    });
  }

  Future<void> _refresh() async {
    final future = _loadContract();
    setState(() {
      _contractFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<LeaseContract>(
          future: _contractFuture,
          builder: (context, snapshot) {
            final contract = snapshot.data;
            final contractId = contract?.id ?? widget.contractId;
            return AppScreenShell(
              header: _ContractHeader(contractId: contractId),
              child: Builder(
                builder: (context) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _ContractLoadingState();
                  }

                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    if (error is LeaseContractNotFoundException) {
                      return _ContractEmptyState(onRetry: _retry);
                    }
                    return _ContractErrorState(
                      message: _messageForError(error),
                      onRetry: _retry,
                    );
                  }

                  if (contract == null) {
                    return _ContractEmptyState(onRetry: _retry);
                  }

                  return RefreshIndicator(
                    color: AppColors.deepBlue,
                    onRefresh: _refresh,
                    child: _ContractContent(
                      contract: contract,
                      contractService: widget.contractService,
                      resolvedMaxOccupants: _resolvedMaxOccupants,
                      onChanged: _refresh,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _ContractBottomNavigation(
        roomId: _roomId,
        roomCode: _roomCode,
      ),
    );
  }
}

class _ContractHeader extends StatelessWidget {
  const _ContractHeader({this.contractId});

  final int? contractId;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppColors.topBarHeight,
      padding: const EdgeInsets.fromLTRB(4, 0, 6, 0),
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
              'Thông tin hợp đồng',
              style: AppColors.topBarTitleStyle,
            ),
          ),
          // Nút tiện ích phòng
          if (contractId != null)
            IconButton(
              tooltip: 'Tiện ích phòng',
              constraints: const BoxConstraints.tightFor(
                width: AppColors.minimumTouchTarget,
                height: AppColors.minimumTouchTarget,
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      RoomAmenitiesScreen(contractId: contractId),
                ),
              ),
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.weekend_outlined,
                  color: AppColors.darkBlue,
                  size: 20,
                ),
              ),
            ),
          const SizedBox(width: 4),
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
}

class _ContractContent extends StatelessWidget {
  const _ContractContent({
    required this.contract,
    required this.contractService,
    required this.resolvedMaxOccupants,
    required this.onChanged,
  });

  final LeaseContract contract;
  final LeaseContractService contractService;
  final int? resolvedMaxOccupants;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ContractWarning(contract: contract),
          _RoomHeroCard(contract: contract),
          const SizedBox(height: 12),
          _ContractInfoGrid(contract: contract),
          const SizedBox(height: 12),
          _TermsSection(terms: contract.terms),
          const SizedBox(height: 12),
          _DocumentSection(
            contractFileUrl: contract.contractFileUrl,
            suggestedFilename: buildDocumentFilename(
              documentType: 'HDT',
              roomCode: contract.room.roomCode,
              date: contract.startDate,
            ),
          ),
          const SizedBox(height: 12),
          _CreateRequestGrid(
            contract: contract,
            contractService: contractService,
            resolvedMaxOccupants: resolvedMaxOccupants,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _CreateRequestGrid extends StatelessWidget {
  const _CreateRequestGrid({
    required this.contract,
    required this.contractService,
    required this.resolvedMaxOccupants,
    required this.onChanged,
  });

  final LeaseContract contract;
  final LeaseContractService contractService;
  final int? resolvedMaxOccupants;
  final Future<void> Function() onChanged;

  bool get _isCoOccupant =>
      contract.roleInContract.trim().toUpperCase() == 'CO_OCCUPANT';

  int get _activeOccupantCount =>
      contract.occupants.where((occupant) => occupant.isActive).length;

  int? get _maxOccupants {
    final capacity = resolvedMaxOccupants ?? contract.room.maxOccupants;
    return capacity != null && capacity > 0 ? capacity : null;
  }

  bool get _isRoomFull {
    final capacity = _maxOccupants;
    return capacity != null && _activeOccupantCount >= capacity;
  }

  Future<void> _submitOccupantIntention(
    BuildContext context,
    String intention,
  ) async {
    final contractId = contract.id;
    if (contractId == null) return;

    try {
      await contractService.recordOccupantIntention(
        contractId: contractId,
        intention: intention,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu ý định của bạn.')));
      await onChanged();
    } on LeaseContractException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openCreateForm(
    BuildContext context,
    TenantRequestType type,
  ) async {
    final contractId = contract.id;
    if (contractId == null) return;

    if (type == TenantRequestType.addRoommate) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AddRoommateRequestScreen(
            contractId: contractId,
            roomId: contract.room.id,
            roomCode: contract.room.roomCode,
            contractService: contractService,
          ),
        ),
      );
      return;
    }

    if (type == TenantRequestType.terminateContract) {
      final confirmed = await _confirmOpenTerminationForm(context);
      if (!context.mounted || !confirmed) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TerminateContractScreen(
            contract: contract,
            contractService: contractService,
          ),
        ),
      );
      if (context.mounted) await onChanged();
      return;
    }

    if (type == TenantRequestType.changeRoom) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              CreateRoomTransferScreen(preloadedContractId: contractId),
        ),
      );
      return;
    }

    if (type == TenantRequestType.renewContract) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RenewContractRequestScreen(
            contract: contract,
            contractService: contractService,
          ),
        ),
      );
      if (context.mounted) await onChanged();
    }
  }

  Future<bool> _confirmOpenTerminationForm(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.dangerSurface,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.danger,
                size: 27,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Cảnh báo mất cọc',
                style: TextStyle(
                  color: AppColors.dangerText,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.dangerSurface,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
          ),
          child: const Text(
            'Nếu thực hiện thanh lý khi hợp đồng còn dưới 1 tháng trước ngày hết hạn, bạn sẽ mất toàn bộ tiền cọc. Vui lòng cân nhắc trước khi tiếp tục.',
            style: TextStyle(
              color: AppColors.dangerText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 20 / 14,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.neutral,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
              ),
            ),
            child: const Text('Tôi hiểu, tiếp tục'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    if (_isCoOccupant) {
      final currentIntention = switch (contract.occupantIntention) {
        'FOLLOW_PRIMARY_MOVE_OUT' => 'Rời phòng theo người đứng tên',
        'JOIN_RENEWAL' => 'Tiếp tục ở nếu tái ký',
        _ => 'Chưa phản hồi',
      };

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.deepBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.fact_check_outlined,
                      color: AppColors.deepBlue,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Text(
                    'Ý định của bạn',
                    style: TextStyle(
                      color: AppColors.inputText,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      height: 20 / 15,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              currentIntention,
              style: const TextStyle(
                color: AppColors.bodyText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (contract.canRecordOccupantIntention) ...[
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.45,
                children: [
                  AppActionTile(
                    icon: Icons.logout_rounded,
                    label: 'Rời phòng\ntheo người đứng tên',
                    accentColor: AppColors.actionRose,
                    onTap: () => _submitOccupantIntention(
                      context,
                      'FOLLOW_PRIMARY_MOVE_OUT',
                    ),
                  ),
                  AppActionTile(
                    icon: Icons.autorenew_rounded,
                    label: 'Tiếp tục ở\nnếu tái ký',
                    accentColor: AppColors.actionBlue,
                    onTap: () =>
                        _submitOccupantIntention(context, 'JOIN_RENEWAL'),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  ),
                  child: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 9),
                const Text(
                  'Tạo yêu cầu mới',
                  style: TextStyle(
                    color: AppColors.inputText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 20 / 15,
                  ),
                ),
              ],
            ),
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              if (contract.canRenew ||
                  contract.canRenewBlockedReason.trim().isEmpty)
                AppActionTile(
                  icon: Icons.autorenew_rounded,
                  label: 'Gia hạn hợp đồng',
                  accentColor: AppColors.actionBlue,
                  onTap: () =>
                      _openCreateForm(context, TenantRequestType.renewContract),
                ),
              AppActionTile(
                icon: Icons.cancel_outlined,
                label: 'Thanh lý hợp đồng',
                accentColor: AppColors.actionRose,
                onTap: () => _openCreateForm(
                  context,
                  TenantRequestType.terminateContract,
                ),
              ),
              AppActionTile(
                icon: Icons.swap_horiz_rounded,
                label: 'Chuyển phòng',
                accentColor: AppColors.actionCyan,
                onTap: () =>
                    _openCreateForm(context, TenantRequestType.changeRoom),
              ),
              AppActionTile(
                icon: Icons.person_add_outlined,
                label: 'Thêm người ở cùng',
                accentColor: AppColors.actionEmerald,
                enabled: !_isRoomFull,
                disabledReason: _isRoomFull
                    ? 'Phòng đã đủ số người tối đa${_maxOccupants == null ? '' : ' ($_activeOccupantCount/$_maxOccupants)'}.'
                    : null,
                onTap: _isRoomFull
                    ? null
                    : () => _openCreateForm(
                        context,
                        TenantRequestType.addRoommate,
                      ),
              ),
            ],
          ),
          if (!contract.canRenew &&
              contract.canRenewBlockedReason.trim().isNotEmpty)
            _RenewalBlockedNotice(reason: contract.canRenewBlockedReason),
        ],
      ),
    );
  }
}

class _RenewalBlockedNotice extends StatelessWidget {
  const _RenewalBlockedNotice({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: const Color(0xFFF2B35D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFB96B00),
              size: 19,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reason,
              style: const TextStyle(
                color: Color(0xFF7A4A00),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 17 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContractWarning extends StatelessWidget {
  const _ContractWarning({required this.contract});

  final LeaseContract contract;

  @override
  Widget build(BuildContext context) {
    final endDate = contract.endDate;
    if (endDate == null) {
      return const SizedBox.shrink();
    }

    final today = _dateOnly(DateTime.now());
    final end = _dateOnly(endDate);
    final remainingDays = end.difference(today).inDays;
    final isExpired = remainingDays < 0;
    final isExpiringSoon = remainingDays >= 0 && remainingDays <= 90;

    if (!isExpired && !isExpiringSoon) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD8D5),
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          border: Border.all(color: const Color(0xFFFFA9A3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFB00020),
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isExpired
                        ? 'HĐ đã hết hạn, vui lòng liên hệ quản lý'
                        : 'HĐ sắp hết hạn, vui lòng phản hồi',
                    style: const TextStyle(
                      color: Color(0xFFB00020),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      height: 20 / 15,
                    ),
                  ),
                  if (!isExpired) ...[
                    const SizedBox(height: 7),
                    Text(
                      'Hợp đồng thuê phòng của bạn sẽ kết thúc vào ngày '
                      '${_formatDate(endDate)}. Vui lòng liên hệ ban quản lý '
                      'để gia hạn hoặc hoàn tất thủ tục trả phòng.',
                      style: const TextStyle(
                        color: Color(0xFFB00020),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 17 / 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomHeroCard extends StatelessWidget {
  const _RoomHeroCard({required this.contract});

  final LeaseContract contract;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveResourceUrl(contract.room.imageUrl);
    final roomName = _roomTitle(contract.room);
    final hasImage = imageUrl.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background: real photo or abstract gradient banner
            if (hasImage)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _ModernRoomBannerBg(),
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : const _ModernRoomBannerBg(),
              )
            else
              const _ModernRoomBannerBg(),
            // Gradient overlay
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withValues(alpha: hasImage ? 0.08 : 0.3),
                    Colors.black.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
            // Content
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatusBadge(status: contract.status),
                        const SizedBox(height: 8),
                        Text(
                          roomName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            AppColors.radiusPill,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          '${_formatMoney(contract.monthlyRent)}/tháng',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Abstract gradient background for when there is no room photo.
/// Inspired by Airbnb / Gen-Z card aesthetics.
class _ModernRoomBannerBg extends StatelessWidget {
  const _ModernRoomBannerBg();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.deepBlue, // deepBlue
            AppColors.darkBlue, // darkBlue
            Color(0xFF1A4A8A), // mid
            AppColors.primary, // primary
          ],
          stops: [0.0, 0.35, 0.65, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles (glassmorphism blobs)
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.22),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0891B2).withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 100,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          // Centre icon
          const Center(
            child: Icon(
              Icons.apartment_rounded,
              color: Colors.white24,
              size: 72,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFA7B4FF),
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
      ),
      child: Text(
        _statusLabel(status),
        style: const TextStyle(
          color: AppColors.deepBlue,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 13 / 10,
        ),
      ),
    );
  }
}

class _ContractInfoGrid extends StatelessWidget {
  const _ContractInfoGrid({required this.contract});

  final LeaseContract contract;

  @override
  Widget build(BuildContext context) {
    final items = [
      _InfoGridItem(
        label: 'Chu kỳ',
        value: contract.paymentCycleMonths == null
            ? ''
            : '${contract.paymentCycleMonths} tháng',
      ),
      _InfoGridItem(
        label: 'Diện tích',
        value: contract.room.area == null
            ? ''
            : '${_formatNumber(contract.room.area!)} m²',
      ),
      _InfoGridItem(label: 'Bắt đầu', value: _formatDate(contract.startDate)),
      _InfoGridItem(label: 'Kết thúc', value: _formatDate(contract.endDate)),
      _InfoGridItem(
        label: 'Bắt đầu tính tiền',
        value: _formatDate(contract.rentStartDate),
      ),
      _InfoGridItem(
        label: 'Tiền cọc',
        value: _formatMoney(contract.depositAmount),
      ),
      _InfoGridItem(label: 'Mã phòng', value: contract.room.roomCode),
      _InfoGridItem(
        label: 'Ngày ký',
        value: contract.signedAt != null
            ? _formatDate(contract.signedAt!)
            : '--',
      ),
      _InfoGridItem(label: 'Trạng thái', value: _statusLabel(contract.status)),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: GridView.builder(
        itemCount: items.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.9,
          crossAxisSpacing: 14,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, index) => items[index],
      ),
    );
  }
}

class _InfoGridItem extends StatelessWidget {
  const _InfoGridItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.bodyText,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            height: 13 / 10,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _display(value),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.inputText,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 17 / 13,
          ),
        ),
      ],
    );
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection({required this.terms});

  final List<String> terms;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Điều khoản chính',
      icon: Icons.gavel_rounded,
      child: terms.isEmpty
          ? const _MutedText('Chưa có điều khoản hợp đồng')
          : Column(
              children: [
                for (var i = 0; i < terms.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _TermTile(text: terms[i]),
                ],
              ],
            ),
    );
  }
}

class _TermTile extends StatelessWidget {
  const _TermTile({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F0F0),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.deepBlue,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.bodyText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 17 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentSection extends StatelessWidget {
  const _DocumentSection({
    required this.contractFileUrl,
    required this.suggestedFilename,
  });

  final String contractFileUrl;
  final String suggestedFilename;

  @override
  Widget build(BuildContext context) {
    final url = _resolveResourceUrl(contractFileUrl);

    return _SectionCard(
      title: 'Quản lý tài liệu',
      child: url.isEmpty
          ? const _MutedText('Chưa có tài liệu hợp đồng')
          : AppActionRowButton(
              icon: Icons.description_outlined,
              title: 'Xem hợp đồng',
              subtitle: 'Mở tài liệu hợp đồng đã ký',
              accentColor: AppColors.actionBlue,
              onTap: () => _showContractFile(context, url, suggestedFilename),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.icon});

  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.deepBlue, size: 19),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.inputText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 20 / 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.bodyText,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        height: 18 / 13,
      ),
    );
  }
}

class _ContractLoadingState extends StatelessWidget {
  const _ContractLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.deepBlue),
    );
  }
}

class _ContractEmptyState extends StatelessWidget {
  const _ContractEmptyState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => AppEmptyState(
    icon: Icons.description_outlined,
    title:
        'B\u1EA1n ch\u01B0a c\u00F3 h\u1EE3p \u0111\u1ED3ng thu\u00EA ph\u00F2ng \u0111ang hi\u1EC7u l\u1EF1c',
    actionLabel: 'Th\u1EED l\u1EA1i',
    actionIcon: Icons.refresh_rounded,
    onAction: onRetry,
    scrollable: true,
    onRefresh: () async => onRetry(),
    topSpacing: 120,
  );
}

class _ContractErrorState extends StatelessWidget {
  const _ContractErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateMessage(
      icon: Icons.error_outline_rounded,
      title: message,
      buttonLabel: 'Thử lại',
      onRetry: onRetry,
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.buttonLabel,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String buttonLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.deepBlue,
      onRefresh: () async => onRetry(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          Icon(icon, color: AppColors.deepBlue, size: 46),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.inputText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 20 / 15,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(buttonLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContractBottomNavigation extends StatelessWidget {
  const _ContractBottomNavigation({this.roomId, this.roomCode = ''});

  final int? roomId;
  final String roomCode;

  @override
  Widget build(BuildContext context) {
    return TenantBottomNavigation(
      activeTab: TenantBottomNavTab.home,
      onHomeTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
      onSupportTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                MaintenanceTicketListScreen(roomId: roomId, roomCode: roomCode),
          ),
        );
      },
      onBillsTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                BillSelectionPage(roomId: roomId, roomCode: roomCode),
          ),
        );
      },
      onProfileTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const TenantProfileScreen()),
        );
      },
      onRequestsTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              TenantRequestScreen(roomId: roomId, roomCode: roomCode),
        ),
      ),
    );
  }
}

void _showContractFile(
  BuildContext context,
  String url,
  String suggestedFilename,
) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => ContractPdfViewerScreen(
        pdfUrl: url,
        title: 'Hợp đồng thuê phòng',
        suggestedFilename: suggestedFilename,
      ),
    ),
  );
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _roomTitle(LeaseRoom room) {
  if (room.roomName.trim().isNotEmpty) {
    return room.roomName.trim();
  }
  if (room.roomCode.trim().isNotEmpty) {
    return 'Phòng ${room.roomCode.trim()}';
  }
  return 'Phòng thuê';
}

String _display(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? 'Chưa cập nhật' : trimmed;
}

String _formatDate(DateTime? date) {
  if (date == null) {
    return 'Chưa cập nhật';
  }
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String _formatMoney(num? amount) {
  if (amount == null) {
    return 'Chưa cập nhật';
  }
  return CurrencyFormatter.vnd(amount).replaceAll(' đ', 'đ');
}

String _formatNumber(num value) {
  if (value % 1 == 0) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}

String _statusLabel(String status) {
  return switch (status.trim().toUpperCase()) {
    'ACTIVE' => 'Đang hiệu lực',
    'EXPIRING_SOON' => 'Sắp hết hạn',
    'EXPIRED' => 'Đã hết hạn',
    'TERMINATED' => 'Đã chấm dứt',
    'DRAFT' => 'Bản nháp',
    'PENDING_SIGNATURE' => 'Chờ ký',
    _ => 'Chưa cập nhật',
  };
}

String _resolveResourceUrl(String value) {
  final url = value.trim();
  if (url.isEmpty) {
    return '';
  }
  final uri = Uri.tryParse(url);
  if (uri != null && uri.hasScheme) {
    return url;
  }

  final baseUri = Uri.parse(ApiConfig.baseUrl);
  if (url.startsWith('/')) {
    return baseUri.replace(path: url).toString();
  }
  final base = ApiConfig.baseUrl.endsWith('/')
      ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
      : ApiConfig.baseUrl;
  return '$base/$url';
}

String _messageForError(Object? error) {
  if (error is LeaseContractException) {
    return error.message;
  }
  return 'Không tải được dữ liệu hợp đồng';
}
