import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/contract/lease_contract_model.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_request_screen.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/widgets/app_date_picker.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';
import 'package:hdbhms_mobile/widgets/request_form_widgets.dart';

const String _kHolderReplacementLiquidationMode =
    'PRIMARY_LEAVES_CO_OCCUPANT_STAYS';

class TerminateContractScreen extends StatefulWidget {
  const TerminateContractScreen({
    super.key,
    required this.contract,
    this.contractService = const LeaseContractService(),
  });

  final LeaseContract contract;
  final LeaseContractService contractService;

  @override
  State<TerminateContractScreen> createState() =>
      _TerminateContractScreenState();
}

class _TerminateContractScreenState extends State<TerminateContractScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  DateTime? _liquidationDate;
  bool _submitting = false;
  String? _submitError;
  bool _roommatesStay = false;
  final Set<int> _stayingProfileIds = <int>{};
  int? _replacementPrimaryTenantProfileId;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = _dateOnly(DateTime.now());
    final selected = await AppDatePicker.show(
      context: context,
      initialDate: _liquidationDate ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 5),
    );
    if (selected != null && mounted) {
      setState(() => _liquidationDate = selected);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final id = widget.contract.id;
    if (id == null) {
      setState(
        () => _submitError = 'Không xác định được hợp đồng để gửi yêu cầu.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await widget.contractService.submitLiquidationRequest(
        contractId: id,
        liquidationDate: _liquidationDate,
        reason: _reasonController.text,
        liquidationMode: _roommatesStay
            ? _kHolderReplacementLiquidationMode
            : null,
        // leavingProfileIds: _leavingProfileIds(),
        // stayingProfileIds: _roommatesStay
        //     ? _stayingProfileIds.toList(growable: false)
        //     : const [],
        // replacementPrimaryTenantProfileId: _roommatesStay
        //     ? _replacementPrimaryTenantProfileId
        //     : null,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      await showRequestSuccessSheet(
        context,
        message:
            'Yêu cầu thanh lý hợp đồng đã được gửi tới quản lý để xét duyệt.',
        onViewRequests: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TenantRequestScreen(
              roomId: widget.contract.room.id,
              roomCode: widget.contract.room.roomCode,
            ),
          ),
        ),
        onReturnToContract: () => Navigator.of(context).pop(),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = error is LeaseContractException
            ? error.message
            : 'Không thể gửi yêu cầu. Vui lòng thử lại.';
      });
    }
  }

  List<LeaseContractOccupant> get _activeOccupants => widget.contract.occupants
      .where(
        (occupant) => occupant.isActive && occupant.tenantProfileId != null,
      )
      .toList(growable: false);

  List<LeaseContractOccupant> get _activeCoOccupants => _activeOccupants
      .where((occupant) => !occupant.isPrimary)
      .toList(growable: false);

  List<int> _leavingProfileIds() {
    final stayingIds = _roommatesStay ? _stayingProfileIds : const <int>{};
    return _activeOccupants
        .where((occupant) {
          final profileId = occupant.tenantProfileId;
          return profileId != null && !stayingIds.contains(profileId);
        })
        .map((occupant) => occupant.tenantProfileId!)
        .toList(growable: false);
  }

  void _syncStayingSelection() {
    final validIds = _activeCoOccupants
        .map((occupant) => occupant.tenantProfileId)
        .whereType<int>()
        .toSet();
    _stayingProfileIds.removeWhere(
      (profileId) => !validIds.contains(profileId),
    );
    if (_stayingProfileIds.isEmpty) {
      _replacementPrimaryTenantProfileId = null;
      return;
    }
    if (_replacementPrimaryTenantProfileId == null ||
        !_stayingProfileIds.contains(_replacementPrimaryTenantProfileId)) {
      _replacementPrimaryTenantProfileId = _stayingProfileIds.first;
    }
  }

  void _toggleStayingProfile(int profileId, bool selected) {
    setState(() {
      if (selected) {
        _stayingProfileIds.add(profileId);
      } else {
        _stayingProfileIds.remove(profileId);
      }
      _syncStayingSelection();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: AppScreenShell(
        header: AppTopBar(
          title: 'Thanh lý hợp đồng',
          onBack: () => Navigator.of(context).maybePop(),
        ),
        child: Form(
          key: _formKey,
          child: RequestFormScaffold(
            action: StickyRequestAction(
              label: 'Gửi yêu cầu thanh lý',
              onPressed: _submit,
              isLoading: _submitting,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RequestSectionHeader(
                  title: 'Yêu cầu kết thúc hợp đồng',
                  subtitle: 'Quản lý sẽ kiểm tra trước khi xử lý.',
                  icon: Icons.event_busy_outlined,
                  accentColor: AppColors.actionRose,
                ),
                const SizedBox(height: AppColors.space16),
                RequestContractSummaryCard(
                  room: _roomLabel(widget.contract),
                  contractCode: _dash(widget.contract.contractCode),
                  expiry: _formatDate(widget.contract.endDate),
                  startDate: _formatDate(widget.contract.startDate),
                ),
                const SizedBox(height: AppColors.space16),
                const RequestNoticeCard(
                  icon: Icons.info_outline_rounded,
                  title: 'Lưu ý trước khi gửi',
                  message:
                      'Sau khi được duyệt, bạn có thể cần bàn giao phòng, hoàn tất hóa đơn cuối kỳ và xác nhận hoàn cọc.',
                  accentColor: AppColors.actionOrange,
                  surfaceColor: AppColors.warningSurface,
                ),
                const SizedBox(height: AppColors.space16),
                RequestFormSection(
                  icon: Icons.calendar_today_outlined,
                  title: 'Ngày thanh lý',
                  accentColor: AppColors.actionCyan,
                  child: FormField<DateTime>(
                    validator: (_) => _liquidationDate == null
                        ? 'Vui lòng chọn ngày thanh lý.'
                        : null,
                    builder: (field) => InkWell(
                      onTap: _submitting
                          ? null
                          : () async {
                              await _pickDate();
                              field.didChange(_liquidationDate);
                            },
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      child: InputDecorator(
                        isEmpty: _liquidationDate == null,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.inputFill,
                          errorText: field.errorText,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _liquidationDate == null
                                    ? 'Chọn ngày thanh lý'
                                    : _formatDate(_liquidationDate),
                                style: _liquidationDate == null
                                    ? AppTypography.body
                                    : AppTypography.label,
                              ),
                            ),
                            const Icon(
                              Icons.calendar_today_outlined,
                              color: AppColors.bodyText,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppColors.space16),
                RequestFormSection(
                  icon: Icons.notes_outlined,
                  title: 'Lý do hoặc ghi chú',
                  accentColor: AppColors.actionEmerald,
                  child: TextFormField(
                    controller: _reasonController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: AppColors.inputFill,
                      hintText: 'Nhập lý do hoặc thông tin thêm...',
                    ),
                  ),
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: AppColors.space16),
                  RequestErrorBanner(message: _submitError!),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _OccupantSubtitle extends StatelessWidget {
  const _OccupantSubtitle({required this.occupant});

  final LeaseContractOccupant occupant;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (occupant.phone.trim().isNotEmpty) occupant.phone.trim(),
      if (occupant.email.trim().isNotEmpty) occupant.email.trim(),
    ];
    if (details.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(details.join(' | '), style: AppTypography.caption);
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
String _formatDate(DateTime? date) => date == null
    ? '--'
    : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _dash(String value) => value.trim().isEmpty ? '--' : value;
String _roomLabel(LeaseContract contract) => _dash(
  contract.room.roomName.isEmpty
      ? contract.room.roomCode
      : contract.room.roomName,
);
