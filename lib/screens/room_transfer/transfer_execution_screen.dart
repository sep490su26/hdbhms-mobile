import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/room_transfer/room_transfer_model.dart';
import 'package:hdbhms_mobile/services/room_transfer/room_transfer_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';

/// Screen for executing a room transfer (final step with handover data).
class TransferExecutionScreen extends StatefulWidget {
  const TransferExecutionScreen({
    super.key,
    required this.transfer,
    this.transferService = const RoomTransferService(),
  });

  final RoomTransferRequest transfer;
  final RoomTransferService transferService;

  @override
  State<TransferExecutionScreen> createState() =>
      _TransferExecutionScreenState();
}

class _TransferExecutionScreenState extends State<TransferExecutionScreen> {
  bool _submitting = false;
  bool _loadingMoveOutContext = false;
  bool _loadingMoveInContext = false;
  SettlementType _positiveDifferenceSettlementType =
      SettlementType.tenantPayMore;
  LatestRoomMeterReadings? _latestMoveOutReadings;
  ContractHandoverDetails? _latestMoveOutHandover;
  LatestRoomMeterReadings? _latestMoveInReadings;
  ContractHandoverDetails? _latestMoveInHandover;

  bool get _hasPositiveDifference =>
      (widget.transfer.priceDifferenceToPay ?? 0) > 0;
  bool get _isCompletePhase =>
      widget.transfer.status == TransferRequestStatus.waitingExecution;
  bool get _requiresTransferInNow =>
      _isCompletePhase &&
      widget.transfer.targetTransferType == TargetTransferType.newContract;

  // Transfer-out handover
  final _outElectricityCtrl = TextEditingController();
  final _outWaterCtrl = TextEditingController();
  final _outNoteCtrl = TextEditingController();
  DateTime? _outHandoverDate;

  // Transfer-in handover
  final _inElectricityCtrl = TextEditingController();
  final _inWaterCtrl = TextEditingController();
  final _inNoteCtrl = TextEditingController();
  DateTime? _inHandoverDate;

  @override
  void initState() {
    super.initState();
    _loadMoveOutContext();
    _loadMoveInContext();
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

  Future<void> _loadMoveOutContext() async {
    setState(() => _loadingMoveOutContext = true);
    try {
      final results = await Future.wait<Object?>([
        widget.transferService.getLatestRoomMeterReadings(
          widget.transfer.oldRoomId,
        ),
        widget.transferService.getContractHandoverDetails(
          contractId: widget.transfer.oldContractId,
          type: 'MOVE_OUT',
        ),
      ]);

      if (!mounted) return;
      final latestReadings = results[0] as LatestRoomMeterReadings?;
      final latestHandover = results[1] as ContractHandoverDetails?;

      setState(() {
        _latestMoveOutReadings = latestReadings;
        _latestMoveOutHandover = latestHandover?.hasAnyData == true
            ? latestHandover
            : null;
        _loadingMoveOutContext = false;
      });

      _prefillMoveOutReading(
        _outElectricityCtrl,
        latestHandover?.electricity?.currentValue,
        latestReadings?.electricity?.currentValue,
      );
      _prefillMoveOutReading(
        _outWaterCtrl,
        latestHandover?.water?.currentValue,
        latestReadings?.water?.currentValue,
      );
      if ((_outNoteCtrl.text.trim().isEmpty) &&
          (latestHandover?.note?.trim().isNotEmpty ?? false)) {
        _outNoteCtrl.text = latestHandover!.note!.trim();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMoveOutContext = false);
    }
  }

  Future<void> _loadMoveInContext() async {
    if (widget.transfer.targetTransferType != TargetTransferType.newContract) {
      return;
    }

    setState(() => _loadingMoveInContext = true);
    try {
      final latestReadings = await widget.transferService
          .getLatestRoomMeterReadings(widget.transfer.targetRoomId);

      ContractHandoverDetails? latestHandover;
      final contractId = widget.transfer.newContractId;
      if (contractId != null && contractId > 0) {
        latestHandover = await widget.transferService
            .getContractHandoverDetails(
              contractId: contractId,
              type: 'MOVE_IN',
            );
      }

      if (!mounted) return;
      setState(() {
        _latestMoveInReadings = latestReadings;
        _latestMoveInHandover = latestHandover?.hasAnyData == true
            ? latestHandover
            : null;
        _loadingMoveInContext = false;
      });

      _prefillReading(
        _inElectricityCtrl,
        latestHandover?.electricity?.currentValue,
        latestReadings?.electricity?.currentValue,
      );
      _prefillReading(
        _inWaterCtrl,
        latestHandover?.water?.currentValue,
        latestReadings?.water?.currentValue,
      );
      if ((_inNoteCtrl.text.trim().isEmpty) &&
          (latestHandover?.note?.trim().isNotEmpty ?? false)) {
        _inNoteCtrl.text = latestHandover!.note!.trim();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMoveInContext = false);
    }
  }

  void _prefillMoveOutReading(
    TextEditingController controller,
    double? primary,
    double? fallback,
  ) {
    _prefillReading(controller, primary, fallback);
  }

  void _prefillReading(
    TextEditingController controller,
    double? primary,
    double? fallback,
  ) {
    if (controller.text.trim().isNotEmpty) return;
    final value = primary ?? fallback;
    if (value == null) return;
    final rounded = value % 1 == 0
        ? value.toInt().toString()
        : value.toString();
    controller.text = rounded;
  }

  Future<void> _submitCompletePhase() async {
    TransferHandoverData? transferInHandover;
    if (_requiresTransferInNow) {
      final inElectricity = double.tryParse(_inElectricityCtrl.text.trim());
      final inWater = double.tryParse(_inWaterCtrl.text.trim());
      if (inElectricity == null || inWater == null) {
        throw const RoomTransferException(
          'Chỉ số lúc nhận phòng không hợp lệ.',
        );
      }
      transferInHandover = TransferHandoverData(
        handoverDate: _inHandoverDate ?? DateTime.now(),
        electricity: MeterReadingData(currentValue: inElectricity),
        water: MeterReadingData(currentValue: inWater),
        note: _inNoteCtrl.text.trim().isEmpty ? null : _inNoteCtrl.text.trim(),
      );
    }
    await widget.transferService.completeTransfer(
      requestId: widget.transfer.id,
      transferInHandover: transferInHandover,
      positiveDifferenceSettlementType: _hasPositiveDifference
          ? _positiveDifferenceSettlementType
          : null,
    );
  }

  Future<void> _submit() async {
    if (_isCompletePhase) {
      setState(() => _submitting = true);
      try {
        await _submitCompletePhase();
        if (!mounted) return;
        _showSuccessDialog();
      } on RoomTransferException catch (e) {
        if (!mounted) return;
        _snack(e.message);
      } catch (_) {
        if (!mounted) return;
        _snack('Could not complete transfer. Please try again.');
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }

    // Validate transfer-out (always required)
    if (_outElectricityCtrl.text.trim().isEmpty) {
      _snack('Vui lòng nhập chỉ số điện phòng cũ.');
      return;
    }
    if (_outWaterCtrl.text.trim().isEmpty) {
      _snack('Vui lòng nhập chỉ số nước phòng cũ.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final outElectricity = double.tryParse(_outElectricityCtrl.text.trim());
      final outWater = double.tryParse(_outWaterCtrl.text.trim());

      if (outElectricity == null || outWater == null) {
        throw const RoomTransferException('Chỉ số điện/nước không hợp lệ.');
      }

      final transferOutHandover = TransferHandoverData(
        handoverDate: _outHandoverDate ?? DateTime.now(),
        electricity: MeterReadingData(currentValue: outElectricity),
        water: MeterReadingData(currentValue: outWater),
        note: _outNoteCtrl.text.trim().isEmpty
            ? null
            : _outNoteCtrl.text.trim(),
      );

      TransferHandoverData? transferInHandover;
      // For NEW_CONTRACT, transfer-in is required
      if (_requiresTransferInNow) {
        if (_inElectricityCtrl.text.trim().isEmpty) {
          throw const RoomTransferException(
            'Vui lòng nhập chỉ số điện phòng mới.',
          );
        }
        if (_inWaterCtrl.text.trim().isEmpty) {
          throw const RoomTransferException(
            'Vui lòng nhập chỉ số nước phòng mới.',
          );
        }

        final inElectricity = double.tryParse(_inElectricityCtrl.text.trim());
        final inWater = double.tryParse(_inWaterCtrl.text.trim());

        if (inElectricity == null || inWater == null) {
          throw const RoomTransferException(
            'Chỉ số điện/nước phòng mới không hợp lệ.',
          );
        }

        transferInHandover = TransferHandoverData(
          handoverDate: _inHandoverDate ?? DateTime.now(),
          electricity: MeterReadingData(currentValue: inElectricity),
          water: MeterReadingData(currentValue: inWater),
          note: _inNoteCtrl.text.trim().isEmpty
              ? null
              : _inNoteCtrl.text.trim(),
        );
      }

      await widget.transferService.executeTransfer(
        requestId: widget.transfer.id,
        transferOutHandover: transferOutHandover,
        transferInHandover: transferInHandover,
        positiveDifferenceSettlementType: null,
      );

      if (!mounted) return;
      _showSuccessDialog();
    } on RoomTransferException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (e) {
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
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
        title: const Text(
          'Thành công!',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text('Đã thực hiện chuyển phòng thành công.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              Navigator.of(context).pop(true); // pop screen with result
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
              ),
            ),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

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
              'Thực hiện chuyển phòng',
              style: AppColors.topBarTitleStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AppTopBar(
      title: 'Thực hiện chuyển phòng',
      onBack: () => Navigator.of(context).maybePop(),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
      children: [
        // ── Transfer-out handover ──────────────────────────────────────
        _SectionCard(
          title: 'Bàn giao phòng cũ',
          icon: Icons.logout_rounded,
          children: [
            if (_loadingMoveOutContext) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 12),
            ],
            if (_latestMoveOutReadings != null ||
                _latestMoveOutHandover != null) ...[
              _MoveOutContextCard(
                latestReadings: _latestMoveOutReadings,
                latestHandover: _latestMoveOutHandover,
              ),
              const SizedBox(height: 12),
            ],
            _MeterReadingField(
              label: 'Chỉ số điện',
              controller: _outElectricityCtrl,
              hint: 'Nhập chỉ số điện hiện tại',
            ),
            const SizedBox(height: 12),
            _MeterReadingField(
              label: 'Chỉ số nước',
              controller: _outWaterCtrl,
              hint: 'Nhập chỉ số nước hiện tại',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _outNoteCtrl,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (nếu có)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),

        // ── Transfer-in handover (only for NEW_CONTRACT) ───────────────
        if (widget.transfer.targetTransferType ==
            TargetTransferType.newContract) ...[
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Nhận phòng mới (chỉ số ban đầu)',
            icon: Icons.login_rounded,
            children: [
              if (_loadingMoveInContext) ...[
                const LinearProgressIndicator(minHeight: 3),
                const SizedBox(height: 12),
              ],
              if (_latestMoveInReadings != null ||
                  _latestMoveInHandover != null) ...[
                _MoveOutContextCard(
                  latestReadings: _latestMoveInReadings,
                  latestHandover: _latestMoveInHandover,
                  title: 'Dữ liệu move-in gần nhất',
                  handoverDateLabel: 'Nhận phòng gần nhất',
                  handoverNoteLabel: 'Ghi chú nhận phòng',
                ),
                const SizedBox(height: 12),
              ],
              _MeterReadingField(
                label: 'Chỉ số điện',
                controller: _inElectricityCtrl,
                hint: 'Nhập chỉ số điện ban đầu',
              ),
              const SizedBox(height: 12),
              _MeterReadingField(
                label: 'Chỉ số nước',
                controller: _inWaterCtrl,
                hint: 'Nhập chỉ số nước ban đầu',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _inNoteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (nếu có)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ],

        if (_hasPositiveDifference) ...[
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Xử lý chênh lệch hóa đơn',
            icon: Icons.receipt_long_rounded,
            children: [
              Text(
                'Phát sinh chênh lệch cần thanh toán: '
                '${_formatCurrency(widget.transfer.priceDifferenceToPay ?? 0)}',
                style: const TextStyle(
                  color: Color(0xFF000666),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _SettlementOptionTile(
                selected:
                    _positiveDifferenceSettlementType ==
                    SettlementType.tenantPayMore,
                enabled: !_submitting,
                title: 'Thanh toán khoản chênh lệch luôn',
                subtitle:
                    'Tạo/yêu cầu thanh toán riêng cho phần chênh lệch hiện tại.',
                onTap: () => setState(
                  () => _positiveDifferenceSettlementType =
                      SettlementType.tenantPayMore,
                ),
              ),
              const SizedBox(height: 8),
              _SettlementOptionTile(
                selected:
                    _positiveDifferenceSettlementType ==
                    SettlementType.addToNextInvoice,
                enabled: !_submitting,
                title: 'Cộng vào hóa đơn kỳ kế tiếp',
                subtitle:
                    'Khoản chênh lệch sẽ được cộng vào hóa đơn tháng sau.',
                onTap: () => setState(
                  () => _positiveDifferenceSettlementType =
                      SettlementType.addToNextInvoice,
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 24),

        // ── Submit button ──────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline, size: 20),
            label: const Text(
              'Thực hiện chuyển phòng',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.deepBlue.withValues(
                alpha: 0.5,
              ),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
              ),
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

// ── Sub-widgets ──────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.deepBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF000666),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
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
        ? AppColors.neutralStrong
        : const Color(0xFF9CA3AF);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.deepBlue.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
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
                          ? AppColors.neutral
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

class _MoveOutContextCard extends StatelessWidget {
  const _MoveOutContextCard({
    required this.latestReadings,
    required this.latestHandover,
    this.title = 'Dữ liệu gần nhất',
    this.handoverDateLabel = 'Bàn giao gần nhất',
    this.handoverNoteLabel = 'Ghi chú bàn giao',
  });

  final LatestRoomMeterReadings? latestReadings;
  final ContractHandoverDetails? latestHandover;
  final String title;
  final String handoverDateLabel;
  final String handoverNoteLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          _MoveOutContextRow(
            label: 'Điện gần nhất',
            latestValue: latestReadings?.electricity?.currentValue,
            handoverValue: latestHandover?.electricity?.currentValue,
          ),
          const SizedBox(height: 6),
          _MoveOutContextRow(
            label: 'Nước gần nhất',
            latestValue: latestReadings?.water?.currentValue,
            handoverValue: latestHandover?.water?.currentValue,
          ),
          if (latestHandover?.handoverDate != null) ...[
            const SizedBox(height: 8),
            Text(
              '$handoverDateLabel: ${_formatDateTime(latestHandover!.handoverDate!)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
          ],
          if (latestHandover?.note?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Text(
              '$handoverNoteLabel: ${latestHandover!.note!.trim()}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}

class _MoveOutContextRow extends StatelessWidget {
  const _MoveOutContextRow({
    required this.label,
    this.latestValue,
    this.handoverValue,
  });

  final String label;
  final double? latestValue;
  final double? handoverValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
        ),
        Text(
          _buildValueText(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }

  String _buildValueText() {
    final latest = _formatValue(latestValue);
    final handover = _formatValue(handoverValue);
    if (latest != null && handover != null && latest != handover) {
      return '$latest • BG: $handover';
    }
    return handover ?? latest ?? 'Chưa có';
  }

  String? _formatValue(double? value) {
    if (value == null) return null;
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }
}

class _MeterReadingField extends StatelessWidget {
  const _MeterReadingField({
    required this.label,
    required this.controller,
    required this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }
}
