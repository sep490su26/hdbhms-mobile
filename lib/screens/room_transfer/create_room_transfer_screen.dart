import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/contract/lease_contract_model.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_request_screen.dart';
import 'package:hdbhms_mobile/models/room_transfer/room_transfer_model.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/services/room_transfer/room_transfer_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/utils/currency_formatter.dart';
import 'package:hdbhms_mobile/utils/user_facing_error_message.dart';
import 'package:hdbhms_mobile/widgets/app_primary_gradient_button.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';
import 'package:hdbhms_mobile/widgets/request_form_widgets.dart';
import 'package:hdbhms_mobile/widgets/room_picker_sheet.dart';

DateTime firstDayOfNextMonth(DateTime now) => DateTime(now.year, now.month + 1);

class CreateRoomTransferScreen extends StatefulWidget {
  const CreateRoomTransferScreen({
    super.key,
    this.preloadedContractId,
    this.transferService = const RoomTransferService(),
    this.contractService = const LeaseContractService(),
  });

  final int? preloadedContractId;
  final RoomTransferService transferService;
  final LeaseContractService contractService;

  @override
  State<CreateRoomTransferScreen> createState() =>
      _CreateRoomTransferScreenState();
}

class _CreateRoomTransferScreenState extends State<CreateRoomTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  LeaseContract? _contract;
  List<AvailableRoom> _rooms = const [];
  AvailableRoom? _targetRoom;
  DateTime? _transferDate;
  bool _loading = true;
  bool _loadingRooms = false;
  bool _submitting = false;
  String? _error;
  String? _roomError;
  Set<int> _selectedTransferredProfileIds = {};
  int? _replacementPrimaryTenantProfileId;

  @override
  void initState() {
    super.initState();
    _transferDate = firstDayOfNextMonth(DateTime.now());
    _load();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final contract = widget.preloadedContractId == null
          ? await widget.contractService.getMyActiveContract()
          : await widget.contractService.getContractById(
              widget.preloadedContractId!,
            );
      if (!mounted) return;
      final selectedTransferredProfileIds = contract.mustTransferAllOccupants
          ? _allActiveProfileIds(contract)
          : _initialTransferredProfileIds(contract);
      setState(() {
        _contract = contract;
        _selectedTransferredProfileIds = selectedTransferredProfileIds;
        _replacementPrimaryTenantProfileId =
            _replacementPrimaryTenantForSelection(
              contract,
              selectedTransferredProfileIds,
            );
        _loading = false;
      });
      await _loadRooms(contract);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is LeaseContractException
            ? toUserFacingMessage(error.message)
            : 'Không thể tải thông tin hợp đồng.';
      });
    }
  }

  Future<void> _loadRooms(LeaseContract contract) async {
    final propertyId = contract.room.propertyId;
    if (propertyId == null || propertyId <= 0) {
      setState(() => _roomError = 'Không xác định được khu nhà của hợp đồng.');
      return;
    }
    setState(() {
      _loadingRooms = true;
      _roomError = null;
    });
    try {
      final rooms = await widget.transferService.fetchAvailableRooms(
        propertyId: propertyId,
        size: 100,
      );
      if (!mounted) return;
      setState(() {
        _rooms = rooms
            .where(
              (room) => room.currentStatus.trim().toUpperCase() == 'VACANT',
            )
            .toList(growable: false);
        _loadingRooms = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingRooms = false;
        _roomError = 'Không thể tải danh sách phòng.';
      });
    }
  }

  Future<void> _openPicker() async {
    final contract = _contract;
    if (contract == null) return;
    if (_loadingRooms) return;
    if (_roomError != null) {
      await _loadRooms(contract);
      return;
    }
    final selected = await showModalBottomSheet<AvailableRoom>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomPickerSheet(
        rooms: _rooms,
        currentRoomId: contract.room.id,
        initialSelection: _targetRoom,
      ),
    );
    if (selected != null && mounted) setState(() => _targetRoom = selected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final contractId = _contract?.id;
    final target = _targetRoom;
    final date = _transferDate ?? firstDayOfNextMonth(DateTime.now());
    if (contractId == null || target == null) return;
    if (_requiresReplacementPrimaryTenant &&
        _replacementPrimaryTenantProfileId == null) {
      setState(() {
        _error =
            'Vui lòng chọn người đứng tên mới cho những người tiếp tục ở phòng cũ.';
      });
      return;
    }
    if (target.maxOccupants > 0 &&
        _selectedTransferredProfileIds.length > target.maxOccupants) {
      setState(() {
        _error = 'Số người chuyển vượt quá sức chứa phòng muốn chuyển đến.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.transferService.createTransferRequest(
        sourceContractId: contractId,
        targetRoomId: target.id,
        requestedTransferDate: date,
        transferredTenantProfileIds: _selectedTransferredProfileIds.isEmpty
            ? null
            : _selectedTransferredProfileIds.toList(growable: false),
        nominatedHolderProfileId: _replacementPrimaryTenantProfileId,
        reason: _reasonController.text,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      await showRequestSuccessSheet(
        context,
        message:
            'Yêu cầu chuyển sang ${target.displayName} đã được gửi tới quản lý để xét duyệt.',
        onViewRequests: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TenantRequestScreen(
              roomId: _contract?.room.id,
              roomCode: _contract?.room.roomCode ?? '',
            ),
          ),
        ),
        onReturnToContract: () => Navigator.of(context).pop(),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error is RoomTransferException
            ? toUserFacingMessage(error.message)
            : 'Không thể gửi yêu cầu. Vui lòng thử lại.';
      });
    }
  }

  Set<int> _initialTransferredProfileIds(LeaseContract contract) {
    final currentId = contract.currentTenantProfileId;
    if (currentId != null) {
      return {currentId};
    }
    if (contract.isPrimary) {
      for (final occupant in contract.occupants) {
        final profileId = occupant.tenantProfileId;
        if (occupant.isPrimary && profileId != null) {
          return {profileId};
        }
      }
    }
    return {};
  }

  Set<int> _allActiveProfileIds(LeaseContract contract) => contract.occupants
      .where(
        (occupant) => occupant.isActive && occupant.tenantProfileId != null,
      )
      .map((occupant) => occupant.tenantProfileId!)
      .toSet();

  List<LeaseContractOccupant> get _transferableOccupants {
    final occupants = _contract?.occupants ?? const [];
    return occupants
        .where((item) => item.isActive && item.tenantProfileId != null)
        .toList(growable: false);
  }

  int? get _sourcePrimaryProfileId {
    for (final occupant in _transferableOccupants) {
      if (occupant.isPrimary) return occupant.tenantProfileId;
    }
    return null;
  }

  List<LeaseContractOccupant> get _remainingOccupants => _transferableOccupants
      .where(
        (occupant) =>
            !_selectedTransferredProfileIds.contains(occupant.tenantProfileId),
      )
      .toList(growable: false);

  bool get _requiresReplacementPrimaryTenant {
    final primaryProfileId = _sourcePrimaryProfileId;
    return primaryProfileId != null &&
        _selectedTransferredProfileIds.contains(primaryProfileId) &&
        _remainingOccupants.isNotEmpty;
  }

  int? _replacementPrimaryTenantForSelection(
    LeaseContract contract,
    Set<int> selectedProfileIds,
  ) {
    LeaseContractOccupant? primaryOccupant;
    for (final occupant in contract.occupants) {
      if (occupant.isActive && occupant.isPrimary) {
        primaryOccupant = occupant;
        break;
      }
    }
    final primaryProfileId = primaryOccupant?.tenantProfileId;
    if (primaryProfileId == null ||
        !selectedProfileIds.contains(primaryProfileId)) {
      return null;
    }
    final remaining = contract.occupants
        .where(
          (occupant) =>
              occupant.isActive &&
              occupant.tenantProfileId != null &&
              !selectedProfileIds.contains(occupant.tenantProfileId),
        )
        .toList(growable: false);
    return remaining.length == 1 ? remaining.single.tenantProfileId : null;
  }

  void _syncReplacementPrimaryTenant() {
    if (!_requiresReplacementPrimaryTenant) {
      _replacementPrimaryTenantProfileId = null;
      return;
    }
    final remainingIds = _remainingOccupants
        .map((occupant) => occupant.tenantProfileId)
        .whereType<int>()
        .toSet();
    if (remainingIds.length == 1) {
      _replacementPrimaryTenantProfileId = remainingIds.single;
    } else if (!remainingIds.contains(_replacementPrimaryTenantProfileId)) {
      _replacementPrimaryTenantProfileId = null;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: AppScreenShell(
        header: AppTopBar(
          title: 'Chuyển phòng',
          onBack: () => Navigator.of(context).maybePop(),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _contract == null
            ? _LoadError(message: _error!, onRetry: _load)
            : _buildForm(),
      ),
    ),
  );

  Widget _buildForm() {
    final contract = _contract!;
    return Form(
      key: _formKey,
      child: RequestFormScaffold(
        action: StickyRequestAction(
          label: 'Gửi yêu cầu chuyển phòng',
          onPressed: _submit,
          isLoading: _submitting,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RequestSectionHeader(
              title: 'Chọn phòng phù hợp',
              subtitle: 'So sánh thông tin trước khi gửi yêu cầu chuyển phòng.',
              icon: Icons.swap_horiz_rounded,
              accentColor: AppColors.actionCyan,
            ),
            const SizedBox(height: AppColors.space16),
            RequestContractSummaryCard(
              room: _roomLabel(contract),
              contractCode: _dash(contract.contractCode),
              expiry: _date(contract.endDate),
              monthlyRent: contract.monthlyRent == null
                  ? null
                  : '${CurrencyFormatter.vnd(contract.monthlyRent!)} / tháng',
            ),
            const SizedBox(height: AppColors.space24),
            RequestFormSection(
              icon: Icons.meeting_room_outlined,
              title: 'Phòng muốn chuyển đến',
              accentColor: AppColors.actionCyan,
              child: FormField<AvailableRoom>(
                validator: (_) => _targetRoom == null
                    ? 'Vui lòng chọn phòng muốn chuyển đến.'
                    : null,
                builder: (field) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RoomSelector(
                      room: _targetRoom,
                      loading: _loadingRooms,
                      error: _roomError,
                      onTap: () async {
                        await _openPicker();
                        field.didChange(_targetRoom);
                      },
                    ),
                    if (field.errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 12),
                        child: Text(
                          field.errorText!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_targetRoom != null && contract.monthlyRent != null) ...[
              const SizedBox(height: AppColors.space16),
              _PriceComparison(contract: contract, target: _targetRoom!),
            ],
            if (_transferableOccupants.length > 1) ...[
              const SizedBox(height: AppColors.space24),
              if (contract.mustTransferAllOccupants)
                const _TransferAllOccupantsNotice(),
              RequestFormSection(
                icon: Icons.groups_rounded,
                title: 'Người chuyển cùng',
                accentColor: AppColors.actionViolet,
                child: _OccupantTransferPicker(
                  occupants: _transferableOccupants,
                  currentTenantProfileId: contract.currentTenantProfileId,
                  selectedProfileIds: _selectedTransferredProfileIds,
                  forceAll: contract.mustTransferAllOccupants,
                  onChanged: (profileId, selected) {
                    setState(() {
                      if (selected) {
                        _selectedTransferredProfileIds.add(profileId);
                      } else {
                        _selectedTransferredProfileIds.remove(profileId);
                      }
                      _syncReplacementPrimaryTenant();
                    });
                  },
                ),
              ),
            ],
            if (_requiresReplacementPrimaryTenant) ...[
              const SizedBox(height: AppColors.space24),
              RequestFormSection(
                icon: Icons.person_outline_rounded,
                title: 'Người đứng tên mới tại phòng cũ',
                subtitle: 'Chọn người tiếp tục ở lại để đứng tên hợp đồng mới.',
                accentColor: AppColors.actionViolet,
                child: _ReplacementPrimaryTenantPicker(
                  occupants: _remainingOccupants,
                  selectedProfileId: _replacementPrimaryTenantProfileId,
                  onChanged: (profileId) {
                    setState(
                      () => _replacementPrimaryTenantProfileId = profileId,
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: AppColors.space24),
            RequestFormSection(
              icon: Icons.calendar_today_outlined,
              title: 'Tháng chuyển dự kiến',
              accentColor: AppColors.actionCyan,
              child: InputDecorator(
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: AppColors.inputFill,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 20),
                    const SizedBox(width: AppColors.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _monthWithStartDate(_transferDate),
                            style: AppTypography.label,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tự động chọn tháng kế tiếp, ngày chuyển là ngày 01.',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.lock_outline_rounded, size: 19),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppColors.space24),
            RequestFormSection(
              icon: Icons.notes_outlined,
              title: 'Lý do chuyển phòng',
              accentColor: AppColors.actionEmerald,
              child: TextFormField(
                controller: _reasonController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: AppColors.inputFill,
                  hintText: 'Nhập lý do (không bắt buộc)...',
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppColors.space16),
              RequestErrorBanner(message: _error!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReplacementPrimaryTenantPicker extends StatelessWidget {
  const _ReplacementPrimaryTenantPicker({
    required this.occupants,
    required this.selectedProfileId,
    required this.onChanged,
  });

  final List<LeaseContractOccupant> occupants;
  final int? selectedProfileId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (occupants.length == 1) {
      final occupant = occupants.single;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppColors.space12),
        decoration: BoxDecoration(
          color: AppColors.infoSurface,
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          border: Border.all(color: AppColors.actionCyan.withValues(alpha: .3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.actionCyan,
              size: 20,
            ),
            const SizedBox(width: AppColors.space8),
            Expanded(
              child: Text(
                'Hệ thống tự động chọn ${occupant.displayName} làm người đứng tên mới vì phòng cũ chỉ còn một người ở lại.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.bodyText,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<int>(
      initialValue: selectedProfileId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Người đứng tên hợp đồng mới của phòng cũ',
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(),
      ),
      items: occupants
          .map(
            (occupant) => DropdownMenuItem<int>(
              value: occupant.tenantProfileId,
              child: Text(occupant.displayName),
            ),
          )
          .toList(growable: false),
      validator: (_) => selectedProfileId == null
          ? 'Vui lòng chọn người đứng tên mới.'
          : null,
      onChanged: onChanged,
    );
  }
}

class _OccupantTransferPicker extends StatelessWidget {
  const _OccupantTransferPicker({
    required this.occupants,
    required this.currentTenantProfileId,
    required this.selectedProfileIds,
    required this.forceAll,
    required this.onChanged,
  });

  final List<LeaseContractOccupant> occupants;
  final int? currentTenantProfileId;
  final Set<int> selectedProfileIds;
  final bool forceAll;
  final void Function(int profileId, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < occupants.length; i++) ...[
          if (i > 0) const Divider(height: AppColors.space16),
          _buildTile(occupants[i]),
        ],
      ],
    );
  }

  Widget _buildTile(LeaseContractOccupant occupant) {
    final profileId = occupant.tenantProfileId!;
    final isCurrent = profileId == currentTenantProfileId;
    final selected =
        forceAll || selectedProfileIds.contains(profileId) || isCurrent;
    final subtitleParts = [
      if (occupant.isPrimary) 'Chủ hợp đồng' else 'Người ở cùng',
      if (isCurrent) 'Bạn',
      if (occupant.phone.trim().isNotEmpty) occupant.phone.trim(),
    ];

    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: selected,
      onChanged: isCurrent || forceAll
          ? null
          : (value) => onChanged(profileId, value ?? false),
      activeColor: AppColors.primary,
      title: Text(occupant.displayName, style: AppTypography.label),
      subtitle: Text(subtitleParts.join(' - '), style: AppTypography.caption),
    );
  }
}

class _TransferAllOccupantsNotice extends StatelessWidget {
  const _TransferAllOccupantsNotice();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: AppColors.space12),
    padding: const EdgeInsets.all(AppColors.space12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4E5),
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
      border: Border.all(color: const Color(0xFFF2B35D)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, color: Color(0xFFB96B00), size: 19),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Phòng đã có khách đặt trước nên bắt buộc chuyển toàn bộ người đang ở.',
            style: TextStyle(
              color: Color(0xFF7A4A00),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _RoomSelector extends StatelessWidget {
  const _RoomSelector({
    required this.room,
    required this.loading,
    required this.error,
    required this.onTap,
  });
  final AvailableRoom? room;
  final bool loading;
  final String? error;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: room == null
        ? 'Chọn phòng muốn chuyển đến'
        : 'Đổi phòng, đang chọn ${room!.displayName}',
    child: Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppColors.space12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepBlue.withValues(alpha: .04),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color:
                      (room == null ? AppColors.actionCyan : AppColors.success)
                          .withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: Icon(
                  room == null
                      ? Icons.meeting_room_outlined
                      : Icons.check_circle_rounded,
                  color: room == null
                      ? AppColors.actionCyan
                      : AppColors.successText,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppColors.space12),
              Expanded(
                child: room == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loading
                                ? 'Đang tải phòng...'
                                : error ?? 'Chọn phòng muốn chuyển đến',
                            style: AppTypography.cardTitle,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            error == null
                                ? 'Xem giá, tầng, diện tích và tình trạng'
                                : 'Chạm để thử lại',
                            style: AppTypography.caption,
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room!.displayName,
                            style: AppTypography.cardTitle,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${room!.statusLabel} · ${CurrencyFormatter.vnd(room!.listedPrice)} / tháng',
                            style: AppTypography.body,
                          ),
                        ],
                      ),
              ),
              if (room != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppColors.radiusPill),
                  ),
                  child: Text(
                    'Thay đổi',
                    style: AppTypography.metaLabel.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                )
              else
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PriceComparison extends StatelessWidget {
  const _PriceComparison({required this.contract, required this.target});
  final LeaseContract contract;
  final AvailableRoom target;
  @override
  Widget build(BuildContext context) {
    final difference = target.listedPrice - contract.monthlyRent!;
    final label = difference == 0
        ? 'Không thay đổi'
        : '${difference > 0 ? '+' : '-'}${CurrencyFormatter.vnd(difference.abs())} / tháng';
    return RequestFormSection(
      icon: Icons.compare_arrows_rounded,
      title: 'So sánh chi phí',
      child: Column(
        children: [
          RequestReadOnlyRow(
            label: 'Phòng hiện tại',
            value: _roomLabel(contract),
          ),
          const SizedBox(height: AppColors.space8),
          RequestReadOnlyRow(
            label: 'Giá phòng hiện tại',
            value: '${CurrencyFormatter.vnd(contract.monthlyRent!)} / tháng',
          ),
          const SizedBox(height: AppColors.space8),
          RequestReadOnlyRow(label: 'Phòng mới', value: target.displayName),
          const SizedBox(height: AppColors.space8),
          RequestReadOnlyRow(
            label: 'Giá phòng mới',
            value: '${CurrencyFormatter.vnd(target.listedPrice)} / tháng',
          ),
          const SizedBox(height: AppColors.space8),
          RequestReadOnlyRow(
            label: 'Chênh lệch mỗi tháng',
            value: label,
            valueColor: difference > 0
                ? AppColors.warningText
                : AppColors.successText,
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: AppTypography.body),
          const SizedBox(height: 16),
          AppPrimaryGradientButton(
            height: 48,
            onPressed: onRetry,
            child: Text(
              'Thử lại',
              style: AppTypography.button.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}

String _date(DateTime? date) => date == null
    ? '--'
    : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _monthWithStartDate(DateTime? date) => date == null
    ? '--'
    : 'Tháng ${date.month.toString().padLeft(2, '0')}/${date.year} (ngày 01)';
String _dash(String value) => value.trim().isEmpty ? '--' : value;
String _roomLabel(LeaseContract contract) => _dash(
  contract.room.roomName.isEmpty
      ? contract.room.roomCode
      : contract.room.roomName,
);
