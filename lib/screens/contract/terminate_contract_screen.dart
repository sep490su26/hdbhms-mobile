import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/contract/lease_contract_model.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/widgets/app_date_picker.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';
import 'package:hdbhms_mobile/widgets/request_form_widgets.dart';

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
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      await showRequestSuccessSheet(
        context,
        message:
            'Yêu cầu thanh lý hợp đồng đã được gửi tới quản lý để xét duyệt.',
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
                ),
                const SizedBox(height: AppColors.space24),
                const Text('HỢP ĐỒNG HIỆN TẠI', style: AppTypography.label),
                const SizedBox(height: AppColors.space8),
                RequestContractSummaryCard(
                  room: _roomLabel(widget.contract),
                  contractCode: _dash(widget.contract.contractCode),
                  expiry: _formatDate(widget.contract.endDate),
                ),
                const SizedBox(height: AppColors.space16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppColors.space12),
                  decoration: BoxDecoration(
                    color: AppColors.warningSurface,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: .28),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.warningText,
                      ),
                      SizedBox(width: AppColors.space8),
                      Expanded(
                        child: Text(
                          'Sau khi được duyệt, bạn có thể cần bàn giao phòng, hoàn tất hóa đơn cuối kỳ và xác nhận hoàn cọc.',
                          style: AppTypography.body,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppColors.space24),
                const Text('NGÀY THANH LÝ *', style: AppTypography.label),
                const SizedBox(height: AppColors.space8),
                FormField<DateTime>(
                  validator: (_) => _liquidationDate == null
                      ? 'Vui lòng chọn ngày thanh lý.'
                      : null,
                  builder: (field) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        button: true,
                        label: 'Chọn ngày thanh lý',
                        child: InkWell(
                          onTap: _submitting
                              ? null
                              : () async {
                                  await _pickDate();
                                  field.didChange(_liquidationDate);
                                },
                          borderRadius: BorderRadius.circular(
                            AppColors.radiusSm,
                          ),
                          child: InputDecorator(
                            isEmpty: _liquidationDate == null,
                            decoration: InputDecoration(
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
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppColors.space24),
                const Text('LÝ DO / GHI CHÚ', style: AppTypography.label),
                const SizedBox(height: AppColors.space8),
                TextFormField(
                  controller: _reasonController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Nhập lý do hoặc thông tin thêm...',
                  ),
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: AppColors.space16),
                  Text(
                    _submitError!,
                    style: AppTypography.body.copyWith(
                      color: AppColors.dangerText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
String _formatDate(DateTime? date) => date == null
    ? '--'
    : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _dash(String value) => value.trim().isEmpty ? '--' : value;
String _roomLabel(LeaseContract contract) => _dash(
  contract.room.roomName.isEmpty
      ? contract.room.roomCode
      : contract.room.roomName,
);
