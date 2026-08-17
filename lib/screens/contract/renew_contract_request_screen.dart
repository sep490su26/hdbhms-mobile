import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hdbhms_mobile/models/contract/lease_contract_model.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_request_screen.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/utils/currency_formatter.dart';
import 'package:hdbhms_mobile/widgets/app_filter_chip.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';
import 'package:hdbhms_mobile/widgets/request_form_widgets.dart';

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
    return end == null ? null : DateTime(end.year, end.month, end.day + 1);
  }

  DateTime? get _newEndDate {
    final start = _newStartDate;
    return start == null || _months < 1
        ? null
        : _addMonthsClamped(start, _months).subtract(const Duration(days: 1));
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
                  icon: Icons.autorenew_rounded,
                  accentColor: AppColors.actionBlue,
                ),
                const SizedBox(height: AppColors.space16),
                RequestContractSummaryCard(
                  room: _roomLabel(widget.contract),
                  contractCode: _dash(widget.contract.contractCode),
                  expiry: _date(widget.contract.endDate),
                  startDate: _date(widget.contract.startDate),
                ),
                const SizedBox(height: AppColors.space16),
                RequestFormSection(
                  icon: Icons.calendar_month_outlined,
                  title: 'Thời hạn gia hạn',
                  subtitle: 'Chọn nhanh hoặc nhập số tháng phù hợp.',
                  accentColor: AppColors.actionCyan,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _termChip(6)),
                          const SizedBox(width: AppColors.space8),
                          Expanded(child: _termChip(12)),
                        ],
                      ),
                      const SizedBox(height: AppColors.space8),
                      Row(
                        children: [
                          Expanded(child: _termChip(18)),
                          const SizedBox(width: AppColors.space8),
                          Expanded(child: _termChip(24)),
                        ],
                      ),
                      const SizedBox(height: AppColors.space16),
                      const RequestFieldLabel(
                        label: 'Số tháng khác',
                        required: true,
                      ),
                      const SizedBox(height: AppColors.space8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.inputFill,
                          borderRadius: BorderRadius.circular(
                            AppColors.radiusSm,
                          ),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                key: const Key('renewal-custom-months'),
                                controller: _monthsController,
                                enabled: true,
                                readOnly: false,
                                enableInteractiveSelection: true,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (_) => setState(() {}),
                                validator: (value) {
                                  final months = int.tryParse(value ?? '');
                                  return months == null || months < 6
                                      ? 'Thời hạn gia hạn tối thiểu 6 tháng.'
                                      : null;
                                },
                                decoration: const InputDecoration(
                                  hintText: 'Ví dụ: 9',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 68,
                              height: AppColors.minimumTouchTarget,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: AppColors.primarySurface,
                                border: Border(
                                  left: BorderSide(color: AppColors.cardBorder),
                                ),
                              ),
                              child: Text('tháng', style: AppTypography.label),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppColors.space4),
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.bodyText,
                            size: 14,
                          ),
                          const SizedBox(width: AppColors.space4),
                          Text(
                            'Nhập từ 6 tháng trở lên',
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppColors.space16),
                RequestFormSection(
                  icon: Icons.event_available_outlined,
                  title: 'Thời gian dự kiến',
                  accentColor: AppColors.actionCyan,
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
                      const SizedBox(height: AppColors.space8),
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
                const SizedBox(height: AppColors.space16),
                RequestFormSection(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Điều khoản tài chính',
                  accentColor: AppColors.actionViolet,
                  child: Column(
                    children: [
                      RequestReadOnlyRow(
                        label: 'Giá thuê',
                        value: widget.contract.monthlyRent == null
                            ? '--'
                            : '${CurrencyFormatter.vnd(widget.contract.monthlyRent!)} / tháng',
                      ),
                      const SizedBox(height: AppColors.space8),
                      RequestReadOnlyRow(
                        label: 'Chu kỳ thanh toán',
                        value: widget.contract.paymentCycleMonths == null
                            ? '--'
                            : '${widget.contract.paymentCycleMonths} tháng',
                      ),
                      const SizedBox(height: AppColors.space8),
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
                const SizedBox(height: AppColors.space16),
                RequestFormSection(
                  icon: Icons.notes_outlined,
                  title: 'Ghi chú',
                  accentColor: AppColors.actionEmerald,
                  child: TextFormField(
                    controller: _noteController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: AppColors.inputFill,
                      hintText: 'Nhập ghi chú cho quản lý...',
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

  Widget _termChip(int value) => AppFilterChip(
    label: '$value tháng',
    isActive: _months == value,
    expanded: true,
    onTap: () => setState(() => _monthsController.text = '$value'),
  );
}

DateTime _addMonthsClamped(DateTime date, int months) {
  final monthIndex = date.month - 1 + months;
  final year = date.year + monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  return DateTime(
    year,
    month,
    date.day.clamp(1, DateTime(year, month + 1, 0).day),
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
