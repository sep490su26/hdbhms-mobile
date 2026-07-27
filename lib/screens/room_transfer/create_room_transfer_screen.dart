import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/contract/lease_contract_model.dart';
import 'package:hdbhms_mobile/models/room_transfer/room_transfer_model.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/services/room_transfer/room_transfer_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/utils/currency_formatter.dart';
import 'package:hdbhms_mobile/widgets/app_date_picker.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';
import 'package:hdbhms_mobile/widgets/request_form_widgets.dart';
import 'package:hdbhms_mobile/widgets/room_picker_sheet.dart';
import 'package:hdbhms_mobile/widgets/section_card.dart';

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

  @override
  void initState() {
    super.initState();
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
      setState(() {
        _contract = contract;
        _loading = false;
      });
      await _loadRooms(contract);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is LeaseContractException
            ? error.message
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
              (room) =>
                  room.currentStatus == 'VACANT' ||
                  room.currentStatus == 'SOON_VACANT',
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

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day);
    final picked = await AppDatePicker.show(
      context: context,
      initialDate: _transferDate ?? first,
      firstDate: first,
      lastDate: DateTime(first.year + 5),
    );
    if (picked != null && mounted) setState(() => _transferDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final contractId = _contract?.id;
    final target = _targetRoom;
    final date = _transferDate;
    if (contractId == null || target == null || date == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.transferService.createTransferRequest(
        sourceContractId: contractId,
        targetRoomId: target.id,
        requestedTransferDate: date,
        reason: _reasonController.text,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      await showRequestSuccessSheet(
        context,
        message:
            'Yêu cầu chuyển sang ${target.displayName} đã được gửi tới quản lý để xét duyệt.',
        onReturnToContract: () => Navigator.of(context).pop(),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error is RoomTransferException
            ? error.message
            : 'Không thể gửi yêu cầu. Vui lòng thử lại.';
      });
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
            const Text('HỢP ĐỒNG HIỆN TẠI', style: AppTypography.label),
            const SizedBox(height: AppColors.space8),
            RequestContractSummaryCard(
              room: _roomLabel(contract),
              contractCode: _dash(contract.contractCode),
              expiry: _date(contract.endDate),
              monthlyRent: contract.monthlyRent == null
                  ? null
                  : '${CurrencyFormatter.vnd(contract.monthlyRent!)} / tháng',
            ),
            const SizedBox(height: AppColors.space24),
            const Text('PHÒNG MUỐN CHUYỂN ĐẾN *', style: AppTypography.label),
            const SizedBox(height: AppColors.space8),
            FormField<AvailableRoom>(
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
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_targetRoom != null && contract.monthlyRent != null) ...[
              const SizedBox(height: AppColors.space16),
              const Text('SO SÁNH CHI PHÍ', style: AppTypography.label),
              const SizedBox(height: AppColors.space8),
              _PriceComparison(contract: contract, target: _targetRoom!),
            ],
            const SizedBox(height: AppColors.space24),
            const Text('NGÀY CHUYỂN DỰ KIẾN *', style: AppTypography.label),
            const SizedBox(height: AppColors.space8),
            FormField<DateTime>(
              validator: (_) => _transferDate == null
                  ? 'Vui lòng chọn ngày chuyển dự kiến.'
                  : null,
              builder: (field) => InkWell(
                onTap: _submitting
                    ? null
                    : () async {
                        await _pickDate();
                        field.didChange(_transferDate);
                      },
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                child: InputDecorator(
                  decoration: InputDecoration(errorText: field.errorText),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _transferDate == null
                              ? 'Chọn ngày'
                              : _date(_transferDate),
                          style: _transferDate == null
                              ? AppTypography.body
                              : AppTypography.label,
                        ),
                      ),
                      const Icon(Icons.calendar_today_outlined, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppColors.space24),
            const Text('LÝ DO CHUYỂN PHÒNG', style: AppTypography.label),
            const SizedBox(height: AppColors.space8),
            TextFormField(
              controller: _reasonController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Nhập lý do (không bắt buộc)...',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppColors.space16),
              Text(
                _error!,
                style: AppTypography.body.copyWith(color: AppColors.dangerText),
              ),
            ],
          ],
        ),
      ),
    );
  }
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
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        child: Container(
          padding: const EdgeInsets.all(AppColors.space12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.cardBorder),
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          child: Row(
            children: [
              Icon(
                room == null
                    ? Icons.meeting_room_outlined
                    : Icons.check_circle_rounded,
                color: room == null ? AppColors.primary : AppColors.successText,
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
                                : error ?? 'Chọn phòng phù hợp',
                            style: AppTypography.cardTitle,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            error == null
                                ? 'Xem giá, tầng và trạng thái'
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
                Text(
                  'Thay đổi',
                  style: AppTypography.label.copyWith(color: AppColors.primary),
                )
              else
                const Icon(Icons.chevron_right_rounded),
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
    return SectionCard(
      child: Column(
        children: [
          RequestReadOnlyRow(
            label: 'Phòng hiện tại',
            value: _roomLabel(contract),
          ),
          const Divider(),
          RequestReadOnlyRow(label: 'Phòng mới', value: target.displayName),
          const Divider(),
          RequestReadOnlyRow(
            label: 'Chênh lệch',
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
          ElevatedButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}

String _date(DateTime? date) => date == null
    ? '--'
    : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _dash(String value) => value.trim().isEmpty ? '--' : value;
String _roomLabel(LeaseContract contract) => _dash(
  contract.room.roomName.isEmpty
      ? contract.room.roomCode
      : contract.room.roomName,
);
