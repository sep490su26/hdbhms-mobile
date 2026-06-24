import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/room_transfer/room_transfer_model.dart';
import 'package:hdbhms_mobile/services/room_transfer/room_transfer_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';

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
  void dispose() {
    _outElectricityCtrl.dispose();
    _outWaterCtrl.dispose();
    _outNoteCtrl.dispose();
    _inElectricityCtrl.dispose();
    _inWaterCtrl.dispose();
    _inNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
      if (widget.transfer.targetTransferType == TargetTransferType.newContract) {
        if (_inElectricityCtrl.text.trim().isEmpty) {
          throw const RoomTransferException(
              'Vui lòng nhập chỉ số điện phòng mới.');
        }
        if (_inWaterCtrl.text.trim().isEmpty) {
          throw const RoomTransferException(
              'Vui lòng nhập chỉ số nước phòng mới.');
        }

        final inElectricity = double.tryParse(_inElectricityCtrl.text.trim());
        final inWater = double.tryParse(_inWaterCtrl.text.trim());

        if (inElectricity == null || inWater == null) {
          throw const RoomTransferException(
              'Chỉ số điện/nước phòng mới không hợp lệ.');
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                borderRadius: BorderRadius.circular(8),
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
        child: AppScreenShell(
          header: _buildHeader(),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
      children: [
        // ── Transfer-out handover ──────────────────────────────────────
        _SectionCard(
          title: 'Bàn giao phòng cũ',
          icon: Icons.logout_rounded,
          children: [
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
              disabledBackgroundColor: AppColors.deepBlue.withValues(alpha: 0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
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
