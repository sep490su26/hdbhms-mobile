import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';
import 'package:hdbhms_mobile/widgets/request_form_widgets.dart';

class AddRoommateRequestScreen extends StatefulWidget {
  const AddRoommateRequestScreen({
    super.key,
    required this.contractId,
    this.contractService = const LeaseContractService(),
  });
  final int contractId;
  final LeaseContractService contractService;

  @override
  State<AddRoommateRequestScreen> createState() =>
      _AddRoommateRequestScreenState();
}

class _AddRoommateRequestScreenState extends State<AddRoommateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _noteController = TextEditingController();
  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await widget.contractService.submitAddCoOccupantRequest(
        contractId: widget.contractId,
        fullName: _nameController.text,
        phone: _digits(_phoneController.text),
        email: _emailController.text,
        note: _noteController.text,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      await showRequestSuccessSheet(
        context,
        message:
            'Yêu cầu thêm người ở cùng đã được gửi tới quản lý để xét duyệt.',
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
          title: 'Thêm người ở cùng',
          onBack: () => Navigator.of(context).maybePop(),
        ),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: RequestFormScaffold(
            action: StickyRequestAction(
              label: 'Gửi yêu cầu',
              onPressed: _submit,
              isLoading: _submitting,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RequestSectionHeader(
                  title: 'Thông tin người ở cùng',
                  subtitle:
                      'Dùng để quản lý xét duyệt và cấp tài khoản sau khi được chấp nhận.',
                ),
                const SizedBox(height: AppColors.space16),
                RequestFormSection(
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'Thông tin liên hệ',
                  child: Column(
                    children: [
                      _Field(
                        label: 'Họ và tên',
                        required: true,
                        controller: _nameController,
                        hint: 'Nhập họ và tên đầy đủ',
                        textCapitalization: TextCapitalization.words,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Vui lòng nhập họ và tên.'
                            : null,
                      ),
                      const SizedBox(height: AppColors.space16),
                      _Field(
                        label: 'Số điện thoại',
                        required: true,
                        controller: _phoneController,
                        hint: '0xxx xxx xxx',
                        keyboardType: TextInputType.phone,
                        inputFormatters: [_PhoneFormatter()],
                        validator: (value) =>
                            RegExp(
                              r'^0\d{8,10}$',
                            ).hasMatch(_digits(value ?? ''))
                            ? null
                            : 'Số điện thoại không hợp lệ.',
                      ),
                      const SizedBox(height: AppColors.space16),
                      _Field(
                        label: 'Email',
                        controller: _emailController,
                        hint: 'example@gmail.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          return email.isEmpty ||
                                  RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                  ).hasMatch(email)
                              ? null
                              : 'Email không hợp lệ.';
                        },
                      ),
                      const SizedBox(height: AppColors.space16),
                      _Field(
                        label: 'Ghi chú',
                        controller: _noteController,
                        hint: 'Thông tin thêm (không bắt buộc)',
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppColors.space16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppColors.space12),
                  decoration: BoxDecoration(
                    color: AppColors.infoSurface,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: .2),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.deepBlue,
                        size: 18,
                      ),
                      SizedBox(width: AppColors.space8),
                      Expanded(
                        child: Text(
                          'Giới hạn tối đa 3 người/phòng',
                          style: AppTypography.body,
                        ),
                      ),
                    ],
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.required = false,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
  });
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool required;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final int maxLines;
  final TextCapitalization textCapitalization;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RequestFieldLabel(label: label, required: required),
      const SizedBox(height: AppColors.space8),
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        validator: validator,
        decoration: InputDecoration(hintText: hint),
      ),
    ],
  );
}

String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');

class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = _digits(
      newValue.text,
    ).substring(0, _digits(newValue.text).length.clamp(0, 11));
    final parts = <String>[];
    if (digits.isNotEmpty) {
      parts.add(digits.substring(0, digits.length.clamp(0, 4)));
    }
    if (digits.length > 4) {
      parts.add(digits.substring(4, digits.length.clamp(4, 7)));
    }
    if (digits.length > 7) {
      parts.add(digits.substring(7));
    }
    final text = parts.join(' ');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
