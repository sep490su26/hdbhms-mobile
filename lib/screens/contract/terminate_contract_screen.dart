import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';
import 'package:hdbhms_mobile/widgets/app_notification_bell.dart';
import 'package:hdbhms_mobile/screens/notification/notification_list_screen.dart';

const Color _kLabel = Color(0xFF000666);

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

// ─────────────────────────────────────────────────────────────────────────────
// Màn yêu cầu thanh lý / trả phòng hợp đồng
// ─────────────────────────────────────────────────────────────────────────────

class TerminateContractScreen extends StatefulWidget {
  const TerminateContractScreen({
    super.key,
    this.contractId,
    this.contractCode = 'HN/Phòng 123/2026/HDSV/574',
    this.contractExpiry = '30/09/2026',
    this.contractEndDate,
  });

  final int? contractId;

  /// Mã hợp đồng hiển thị (mock)
  final String contractCode;

  /// Ngày hết hạn hợp đồng hiển thị (mock, định dạng dd/MM/yyyy)
  final String contractExpiry;

  final DateTime? contractEndDate;

  @override
  State<TerminateContractScreen> createState() =>
      _TerminateContractScreenState();
}

class _TerminateContractScreenState extends State<TerminateContractScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();

  DateTime? _expectedDate;
  bool _submitting = false;

  DateTime get _expiryDate {
    final contractEndDate = widget.contractEndDate;
    if (contractEndDate != null) {
      return _dateOnly(contractEndDate);
    }
    final parts = widget.contractExpiry.split('/');
    if (parts.length != 3) {
      return _dateOnly(DateTime.now().add(const Duration(days: 365)));
    }
    return DateTime(
      int.tryParse(parts[2]) ?? DateTime.now().year,
      int.tryParse(parts[1]) ?? DateTime.now().month,
      int.tryParse(parts[0]) ?? DateTime.now().day,
    );
  }

  bool get _isUnderOneMonth {
    final remainingDays = _expiryDate
        .difference(_dateOnly(DateTime.now()))
        .inDays;
    return remainingDays >= 0 && remainingDays < 30;
  }

  String get _expiryLabel => widget.contractEndDate == null
      ? widget.contractExpiry
      : _formatDate(widget.contractEndDate!);

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  // ── Date picker ────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final tomorrow = _dateOnly(DateTime.now().add(const Duration(days: 1)));
    final lastDate = _expiryDate;
    if (lastDate.isBefore(tomorrow)) {
      _snack(
        'Hợp đồng đã quá gần ngày hết hạn. Vui lòng tạo yêu cầu để quản lý hỗ trợ.',
      );
      return;
    }
    final initial = _expectedDate ?? tomorrow;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(tomorrow) ? tomorrow : initial,
      firstDate: tomorrow,
      lastDate: lastDate,
    );
    if (picked != null) {
      setState(() => _expectedDate = picked);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _snack('Vui lòng hoàn thành các trường bắt buộc');
      return;
    }
    if (_expectedDate == null) {
      _snack('Vui lòng chọn ngày trả phòng dự kiến');
      return;
    }
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _submitting = false);
    _showSuccessDialog();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSuccessDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => _TerminateSuccessDialog(
        onHome: () {
          Navigator.of(context).pop();
          Navigator.of(context).popUntil((r) => r.isFirst);
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(header: _buildHeader(), child: _buildForm()),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
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
          ),
          const Expanded(
            child: Text('Thanh lý hợp đồng', style: AppColors.topBarTitleStyle),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationListScreen()),
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

  // ── Form ───────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return AppTopBar(
      title: 'Thanh lý hợp đồng',
      onBack: () => Navigator.of(context).maybePop(),
      trailing: IconButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationListScreen()),
        ),
        icon: const AppNotificationBell(),
        tooltip: 'Thông báo',
      ),
    );
  }

  Widget _buildForm() {
    final reasonLength = _reasonCtrl.text.length;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
        children: [
          // ── Thông tin hợp đồng ─────────────────────────────────────────
          _SectionCard(
            title: 'Thông tin hợp đồng',
            icon: Icons.description_outlined,
            children: [
              _InfoRow(label: 'Mã hợp đồng', value: widget.contractCode),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFEEECEE)),
              const SizedBox(height: 10),
              _InfoRow(
                label: 'Ngày hết hạn',
                value: _expiryLabel,
                valueColor: AppColors.danger,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Thông tin trả phòng ────────────────────────────────────────
          _SectionCard(
            title: 'Thông tin trả phòng',
            icon: Icons.exit_to_app_rounded,
            children: [
              if (_isUnderOneMonth) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    border: Border.all(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 17,
                        color: Color(0xFFEA580C),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hợp đồng còn dưới 1 tháng. '
                          'Yêu cầu hủy/thanh lý sẽ được gửi để quản lý '
                          'kiểm tra trước khi xử lý.',
                          style: TextStyle(
                            color: Color(0xFF9A3412),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Notice banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF8FF),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  border: Border.all(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ngày trả phòng dự kiến phải nhỏ hơn hoặc bằng ngày hết hạn hợp đồng ($_expiryLabel).',
                        style: const TextStyle(
                          color: Color(0xFF0369A1),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Label ngày trả phòng
              Row(
                children: const [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 13,
                    color: AppColors.bodyText,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Ngày trả phòng dự kiến',
                    style: TextStyle(
                      color: AppColors.bodyText,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '*',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Date picker button
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    border: Border.all(
                      color: _expectedDate != null
                          ? AppColors.deepBlue
                          : AppColors.cardBorder,
                      width: _expectedDate != null ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: _expectedDate != null
                            ? AppColors.deepBlue
                            : AppColors.bodyText,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _expectedDate != null
                              ? _formatDate(_expectedDate!)
                              : 'Chọn ngày trả phòng',
                          style: TextStyle(
                            color: _expectedDate != null
                                ? AppColors.inputText
                                : AppColors.bodyText,
                            fontSize: 14,
                            fontWeight: _expectedDate != null
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.expand_more_rounded,
                        size: 20,
                        color: _expectedDate != null
                            ? AppColors.deepBlue
                            : AppColors.bodyText,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Chọn ngày từ ngày mai và trước ngày kết thúc hợp đồng',
                style: TextStyle(
                  color: AppColors.bodyText,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 16),

              // Label lý do
              Row(
                children: const [
                  Icon(
                    Icons.notes_rounded,
                    size: 13,
                    color: AppColors.bodyText,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Lý do trả phòng',
                    style: TextStyle(
                      color: AppColors.bodyText,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '*',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Reason text field
              TextFormField(
                controller: _reasonCtrl,
                minLines: 4,
                maxLines: 6,
                maxLength: 150,
                onChanged: (_) => setState(() {}),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập lý do trả phòng'
                    : null,
                style: const TextStyle(
                  color: AppColors.inputText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Nhập lý do trả phòng...',
                  hintStyle: const TextStyle(
                    color: AppColors.bodyText,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    borderSide: const BorderSide(
                      color: AppColors.deepBlue,
                      width: 1.5,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    borderSide: const BorderSide(color: AppColors.danger),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$reasonLength/150 ký tự',
                  style: const TextStyle(
                    color: AppColors.bodyText,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Submit button
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              label: Text(
                _submitting ? 'Đang gửi...' : 'Gửi yêu cầu',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.5,
                ),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusLg),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Cancel button
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.bodyText,
                side: const BorderSide(color: AppColors.cardBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusLg),
                ),
              ),
              child: const Text(
                'Hủy',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section card wrapper
// ─────────────────────────────────────────────────────────────────────────────
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
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: _kLabel),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: _kLabel,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEEECEE)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info row (label + value)
// ─────────────────────────────────────────────────────────────────────────────
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
        Expanded(
          flex: 4,
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
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? AppColors.inputText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Success dialog popup
// ─────────────────────────────────────────────────────────────────────────────
class _TerminateSuccessDialog extends StatefulWidget {
  const _TerminateSuccessDialog({required this.onHome});

  final VoidCallback onHome;

  @override
  State<_TerminateSuccessDialog> createState() =>
      _TerminateSuccessDialogState();
}

class _TerminateSuccessDialogState extends State<_TerminateSuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: AppColors.danger.withValues(alpha: 0.14),
                  blurRadius: 40,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Top banner gradient đỏ/cam ─────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFC62828),
                        AppColors.danger,
                        Color(0xFFE53935),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Color(0xFFC62828),
                            size: 34,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Yêu cầu đã được gửi!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Body ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5F5),
                          borderRadius: BorderRadius.circular(AppColors.radiusMd),
                          border: Border.all(
                            color: const Color(
                              0xFFDC2626,
                            ).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: AppColors.danger,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Yêu cầu thanh lý hợp đồng của bạn đã được gửi đến chủ trọ. Chủ trọ sẽ liên hệ bạn trong thời gian sớm nhất để hoàn tất thủ tục.',
                                style: TextStyle(
                                  color: Color(0xFFC62828),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: widget.onHome,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppColors.radiusMd),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.home_rounded, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Về màn hình chính',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
