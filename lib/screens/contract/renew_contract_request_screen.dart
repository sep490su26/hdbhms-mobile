import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hdbhms_mobile/models/contract/lease_contract_model.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/utils/currency_formatter.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';
import 'package:hdbhms_mobile/widgets/request_form_widgets.dart';
import 'package:hdbhms_mobile/widgets/section_card.dart';

class RenewContractRequestScreen extends StatefulWidget {
  const RenewContractRequestScreen({
    super.key,
    required this.contract,
    required this.contractService,
  });

  final LeaseContract contract;
  final LeaseContractService contractService;

  @override
  State<RenewContractRequestScreen> createState() =>
      _RenewContractRequestScreenState();
}

class _RenewContractRequestScreenState
    extends State<RenewContractRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _monthsController = TextEditingController(text: '12');
  final _noteController = TextEditingController();
  bool _submitting = false;
  String? _submitError;

  int get _months => int.tryParse(_monthsController.text) ?? 0;

  @override
  void dispose() {
    _monthsController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  DateTime? get _newStartDate {
    final end = widget.contract.endDate;
    if (end == null) return null;
    return DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
  }

  DateTime? get _newEndDate {
    final start = _newStartDate;
    if (start == null || _months < 1) return null;
    return _addMonthsClamped(start, _months).subtract(const Duration(days: 1));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final id = widget.contract.id;
    final start = _newStartDate;
    final end = _newEndDate;
    if (id == null || start == null || end == null) {
      setState(
        () => _submitError = 'Không đủ thông tin hợp đồng để gửi yêu cầu.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await widget.contractService.submitRenewalRequest(
        contractId: id,
        newStartDate: start,
        newEndDate: end,
        renewalTermMonths: _months,
        monthlyRent: widget.contract.monthlyRent ?? 0,
        paymentCycleMonths: widget.contract.paymentCycleMonths ?? 1,
        depositAmount: widget.contract.depositAmount ?? 0,
        note: _noteController.text,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      await showRequestSuccessSheet(
        context,
        message:
            'Yêu cầu gia hạn hợp đồng đã được gửi tới quản lý để xét duyệt.',
        onReturnToContract: () => Navigator.of(context).pop(),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = _errorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: AppScreenShell(
        header: AppTopBar(
          title: 'Gia hạn hợp đồng',
          onBack: () => Navigator.of(context).maybePop(),
        ),
        child: Form(
          key: _formKey,
          child: RequestFormScaffold(
            action: StickyRequestAction(
              label: 'Gửi yêu cầu gia hạn',
              onPressed: _submit,
              isLoading: _submitting,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RequestSectionHeader(
                  title: 'Gia hạn thời gian thuê',
                  subtitle: 'Kiểm tra thông tin trước khi gửi yêu cầu.',
                ),
                const SizedBox(height: AppColors.space24),
                const Text('HỢP ĐỒNG HIỆN TẠI', style: AppTypography.label),
                const SizedBox(height: AppColors.space8),
                RequestContractSummaryCard(
                  room: _roomLabel(widget.contract),
                  contractCode: _orDash(widget.contract.contractCode),
                  expiry: _date(widget.contract.endDate),
                ),
                const SizedBox(height: AppColors.space24),
                const Text('THỜI HẠN GIA HẠN *', style: AppTypography.label),
                const SizedBox(height: AppColors.space8),
                Wrap(
                  spacing: AppColors.space8,
                  runSpacing: AppColors.space8,
                  children: [6, 12, 18, 24]
                      .map(
                        (value) => ChoiceChip(
                          label: Text('$value tháng'),
                          selected: _months == value,
                          onSelected: (_) =>
                              setState(() => _monthsController.text = '$value'),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: AppColors.space12),
                TextFormField(
                  controller: _monthsController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    final months = int.tryParse(value ?? '');
                    if (months == null || months < 6) {
                      return 'Thời hạn gia hạn tối thiểu 6 tháng.';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    hintText: 'Nhập số tháng khác',
                    helperText: 'Tối thiểu 6 tháng',
                  ),
                ),
                const SizedBox(height: AppColors.space24),
                const Text('THỜI GIAN DỰ KIẾN', style: AppTypography.label),
                const SizedBox(height: AppColors.space8),
                SectionCard(
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: RequestReadOnlyRow(
                          key: ValueKey('start-${_date(_newStartDate)}'),
                          label: 'Bắt đầu',
                          value: _date(_newStartDate),
                        ),
                      ),
                      const Divider(),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: RequestReadOnlyRow(
                          key: ValueKey('end-${_date(_newEndDate)}'),
                          label: 'Kết thúc',
                          value: _date(_newEndDate),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppColors.space24),
                const Text('ĐIỀU KHOẢN TÀI CHÍNH', style: AppTypography.label),
                const SizedBox(height: AppColors.space8),
                SectionCard(
                  child: Column(
                    children: [
                      RequestReadOnlyRow(
                        label: 'Giá thuê',
                        value: widget.contract.monthlyRent == null
                            ? '--'
                            : '${CurrencyFormatter.vnd(widget.contract.monthlyRent!)} / tháng',
                      ),
                      const Divider(),
                      RequestReadOnlyRow(
                        label: 'Chu kỳ thanh toán',
                        value: widget.contract.paymentCycleMonths == null
                            ? '--'
                            : '${widget.contract.paymentCycleMonths} tháng',
                      ),
                      const Divider(),
                      RequestReadOnlyRow(
                        label: 'Tiền cọc',
                        value: widget.contract.depositAmount == null
                            ? '--'
                            : CurrencyFormatter.vnd(
                                widget.contract.depositAmount!,
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppColors.space24),
                const Text('GHI CHÚ', style: AppTypography.label),
                const SizedBox(height: AppColors.space8),
                TextFormField(
                  controller: _noteController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Nhập ghi chú cho quản lý...',
                  ),
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: AppColors.space16),
                  _ErrorBanner(message: _submitError!),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppColors.space12),
    decoration: BoxDecoration(
      color: AppColors.dangerSurface,
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
    ),
    child: Text(
      message,
      style: AppTypography.body.copyWith(color: AppColors.dangerText),
    ),
  );
}

DateTime _addMonthsClamped(DateTime date, int months) {
  final monthIndex = date.month - 1 + months;
  final year = date.year + monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, date.day.clamp(1, lastDay));
}

String _date(DateTime? date) => date == null
    ? '--'
    : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _orDash(String value) => value.trim().isEmpty ? '--' : value;
String _roomLabel(LeaseContract contract) {
  final room = contract.room;
  return _orDash(room.roomName.isNotEmpty ? room.roomName : room.roomCode);
}

String _errorMessage(Object error) => error is LeaseContractException
    ? error.message
    : 'Không thể gửi yêu cầu. Vui lòng thử lại.';
