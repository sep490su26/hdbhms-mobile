import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/room_transfer/room_transfer_model.dart';
import 'package:hdbhms_mobile/services/room_transfer/room_transfer_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';

/// Collects handover data (meter readings + assets) for both old and new rooms,
/// then calls the execute-transfer endpoint.
class TransferHandoverScreen extends StatefulWidget {
  const TransferHandoverScreen({
    super.key,
    required this.transferRequest,
    this.transferService = const RoomTransferService(),
  });

  final RoomTransferRequest transferRequest;
  final RoomTransferService transferService;

  @override
  State<TransferHandoverScreen> createState() => _TransferHandoverScreenState();
}

class _TransferHandoverScreenState extends State<TransferHandoverScreen> {
  // ── Transfer-out (old room) ──────────────────────────────────────────
  final _outElectricityCtrl = TextEditingController();
  final _outWaterCtrl = TextEditingController();
  final _outNoteCtrl = TextEditingController();
  DateTime? _outDate;

  // ── Transfer-in (new room) ───────────────────────────────────────────
  final _inElectricityCtrl = TextEditingController();
  final _inWaterCtrl = TextEditingController();
  final _inNoteCtrl = TextEditingController();
  DateTime? _inDate;

  bool _submitting = false;
  SettlementType _positiveDifferenceSettlementType =
      SettlementType.tenantPayMore;

  bool get _hasPositiveDifference =>
      (widget.transferRequest.priceDifferenceToPay ?? 0) > 0;
  bool get _isCompletePhase =>
      widget.transferRequest.status == TransferRequestStatus.waitingExecution;

  @override
  void initState() {
    super.initState();
    _outDate = DateTime.now();
    _inDate = DateTime.now();
  }

  @override
  void dispose() {
    _outElectricityCtrl.dispose();
    _outWaterCtrl.dispose();
    _outNoteCtrl.dispose();
    _inElectricityCtrl.dispose();
    _inWaterCtrl.dispose();
    _inNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isOut) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isOut ? (_outDate ?? now) : (_inDate ?? now),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() {
        if (isOut) {
          _outDate = picked;
        } else {
          _inDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  TransferHandoverData? _buildHandoverData({
    required TextEditingController electricityCtrl,
    required TextEditingController waterCtrl,
    required TextEditingController noteCtrl,
    DateTime? date,
  }) {
    final electricityRaw = electricityCtrl.text.trim();
    final waterRaw = waterCtrl.text.trim();

    // If both are empty, skip this handover entirely
    if (electricityRaw.isEmpty && waterRaw.isEmpty) return null;

    final electricity = double.tryParse(electricityRaw) ?? 0;
    final water = double.tryParse(waterRaw) ?? 0;

    return TransferHandoverData(
      handoverDate: date ?? DateTime.now(),
      electricity: MeterReadingData(currentValue: electricity),
      water: MeterReadingData(currentValue: water),
      note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
    );
  }

  Future<void> _submit() async {
    // Validate at least one room has readings
    final outData = _buildHandoverData(
      electricityCtrl: _outElectricityCtrl,
      waterCtrl: _outWaterCtrl,
      noteCtrl: _outNoteCtrl,
      date: _outDate,
    );
    final inData = _buildHandoverData(
      electricityCtrl: _inElectricityCtrl,
      waterCtrl: _inWaterCtrl,
      noteCtrl: _inNoteCtrl,
      date: _inDate,
    );

    if (outData == null && inData == null) {
      _snack('Vui lòng nhập ít nhất một chỉ số điện hoặc nước.');
      return;
    }

    if (!_isCompletePhase && outData == null) {
      _snack('Transfer checkout requires old-room readings.');
      return;
    }
    if (_isCompletePhase &&
        widget.transferRequest.targetTransferType ==
            TargetTransferType.newContract &&
        inData == null) {
      _snack('Transfer completion requires new-room readings.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Xác nhận thực hiện chuyển phòng',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Sau khi xác nhận, quá trình chuyển phòng sẽ được thực hiện. '
          'Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy bỏ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);
    try {
      if (_isCompletePhase) {
        await widget.transferService.completeTransfer(
          requestId: widget.transferRequest.id,
          transferInHandover: inData,
          positiveDifferenceSettlementType: _hasPositiveDifference
              ? _positiveDifferenceSettlementType
              : null,
        );
      } else {
        await widget.transferService.executeTransfer(
          requestId: widget.transferRequest.id,
          transferOutHandover: outData,
          positiveDifferenceSettlementType: null,
        );
      }
      if (!mounted) return;
      _showSuccessDialog();
    } on RoomTransferException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      _snack('Không thể thực hiện chuyển phòng. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
      builder: (ctx) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FFF4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF16A34A),
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Chuyển phòng thành công',
                style: TextStyle(
                  color: AppColors.inputText,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Quá trình chuyển phòng đã được ghi nhận.\nVui lòng liên hệ quản lý nếu cần hỗ trợ thêm.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.bodyText,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    // Pop back to the list, signaling refresh
                    Navigator.of(context).pop(true);
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Đã hiểu',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(header: _buildHeader(), child: _buildBody()),
      ),
    );
  }

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
            tooltip: 'Trở về',
          ),
          const Expanded(
            child: Text(
              'Bàn giao chuyển phòng',
              style: AppColors.topBarTitleStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AppTopBar(
      title: 'Bàn giao chuyển phòng',
      onBack: () => Navigator.of(context).maybePop(),
    );
  }

  Widget _buildBody() {
    final transfer = widget.transferRequest;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
      children: [
        // ── Transfer info ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF1FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppColors.deepBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${transfer.oldRoomName.isNotEmpty ? transfer.oldRoomName : transfer.oldRoomCode} → ${transfer.targetRoomName.isNotEmpty ? transfer.targetRoomName : transfer.targetRoomCode}',
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Transfer-out (old room) ────────────────────────────────────
        _HandoverSection(
          title: 'Bàn giao phòng cũ',
          subtitle: transfer.oldRoomName.isNotEmpty
              ? transfer.oldRoomName
              : transfer.oldRoomCode,
          icon: Icons.logout_rounded,
          electricityCtrl: _outElectricityCtrl,
          waterCtrl: _outWaterCtrl,
          noteCtrl: _outNoteCtrl,
          date: _outDate,
          onPickDate: () => _pickDate(true),
          formatDate: _formatDate,
        ),

        const SizedBox(height: 16),

        // ── Transfer-in (new room) ─────────────────────────────────────
        _HandoverSection(
          title: 'Bàn giao phòng mới',
          subtitle: transfer.targetRoomName.isNotEmpty
              ? transfer.targetRoomName
              : transfer.targetRoomCode,
          icon: Icons.login_rounded,
          electricityCtrl: _inElectricityCtrl,
          waterCtrl: _inWaterCtrl,
          noteCtrl: _inNoteCtrl,
          date: _inDate,
          onPickDate: () => _pickDate(false),
          formatDate: _formatDate,
        ),

        if (_hasPositiveDifference) ...[
          const SizedBox(height: 16),
          _SettlementSection(
            amount: transfer.priceDifferenceToPay ?? 0,
            selectedType: _positiveDifferenceSettlementType,
            enabled: !_submitting,
            onChanged: (type) =>
                setState(() => _positiveDifferenceSettlementType = type),
            formatCurrency: _formatCurrency,
          ),
        ],

        const SizedBox(height: 24),

        // ── Execute button ─────────────────────────────────────────────
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(
                0xFF16A34A,
              ).withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Thực hiện chuyển phòng',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }

  String _formatCurrency(num value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write('.');
      }
    }
    return '${buffer.toString()} đ';
  }
}

// ── Settlement section ────────────────────────────────────────────────────────

class _SettlementSection extends StatelessWidget {
  const _SettlementSection({
    required this.amount,
    required this.selectedType,
    required this.enabled,
    required this.onChanged,
    required this.formatCurrency,
  });

  final num amount;
  final SettlementType selectedType;
  final bool enabled;
  final ValueChanged<SettlementType> onChanged;
  final String Function(num) formatCurrency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                color: AppColors.deepBlue,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Xử lý chênh lệch hóa đơn',
                style: TextStyle(
                  color: Color(0xFF000666),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Phát sinh chênh lệch cần thanh toán: ${formatCurrency(amount)}',
            style: const TextStyle(
              color: Color(0xFF000666),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _SettlementOptionTile(
            selected: selectedType == SettlementType.tenantPayMore,
            enabled: enabled,
            title: 'Thanh toán khoản chênh lệch luôn',
            subtitle:
                'Tạo/yêu cầu thanh toán riêng cho phần chênh lệch hiện tại.',
            onTap: () => onChanged(SettlementType.tenantPayMore),
          ),
          const SizedBox(height: 8),
          _SettlementOptionTile(
            selected: selectedType == SettlementType.addToNextInvoice,
            enabled: enabled,
            title: 'Cộng vào hóa đơn kỳ kế tiếp',
            subtitle: 'Khoản chênh lệch sẽ được cộng vào hóa đơn tháng sau.',
            onTap: () => onChanged(SettlementType.addToNextInvoice),
          ),
        ],
      ),
    );
  }
}

class _SettlementOptionTile extends StatelessWidget {
  const _SettlementOptionTile({
    required this.selected,
    required this.enabled,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final bool enabled;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = selected ? AppColors.deepBlue : const Color(0xFF9CA3AF);
    final textColor = enabled
        ? const Color(0xFF111827)
        : const Color(0xFF9CA3AF);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.deepBlue.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.deepBlue.withValues(alpha: 0.55)
                : AppColors.cardBorder,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: enabled ? activeColor : const Color(0xFFD1D5DB),
              size: 21,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: enabled
                          ? const Color(0xFF6B7280)
                          : const Color(0xFF9CA3AF),
                      fontSize: 12,
                    ),
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

// ── Handover section (meter readings + note) ─────────────────────────────────

class _HandoverSection extends StatelessWidget {
  const _HandoverSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.electricityCtrl,
    required this.waterCtrl,
    required this.noteCtrl,
    required this.date,
    required this.onPickDate,
    required this.formatDate,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final TextEditingController electricityCtrl;
  final TextEditingController waterCtrl;
  final TextEditingController noteCtrl;
  final DateTime? date;
  final VoidCallback onPickDate;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.deepBlue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF000666),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.bodyText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Date picker
          _FieldLabel('Ngày bàn giao'),
          const SizedBox(height: 6),
          InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_outlined,
                    color: AppColors.hintText,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    date != null ? formatDate(date!) : 'Chọn ngày',
                    style: TextStyle(
                      color: date == null
                          ? AppColors.hintText
                          : AppColors.inputText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Electricity reading
          _FieldLabel('Chỉ số điện (kWh)'),
          const SizedBox(height: 6),
          TextField(
            controller: electricityCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'Nhập chỉ số điện hiện tại',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: AppColors.border),
              ),
              filled: true,
              fillColor: AppColors.inputFill,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            style: const TextStyle(color: AppColors.inputText, fontSize: 14),
          ),

          const SizedBox(height: 12),

          // Water reading
          _FieldLabel('Chỉ số nước (m³)'),
          const SizedBox(height: 6),
          TextField(
            controller: waterCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'Nhập chỉ số nước hiện tại',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: AppColors.border),
              ),
              filled: true,
              fillColor: AppColors.inputFill,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            style: const TextStyle(color: AppColors.inputText, fontSize: 14),
          ),

          const SizedBox(height: 12),

          // Note
          _FieldLabel('Ghi chú (không bắt buộc)'),
          const SizedBox(height: 6),
          TextField(
            controller: noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Ghi chú tình trạng phòng, tài sản...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: AppColors.border),
              ),
              filled: true,
              fillColor: AppColors.inputFill,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            style: const TextStyle(color: AppColors.inputText, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.inputText,
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
