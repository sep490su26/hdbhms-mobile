import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/room_transfer/room_transfer_model.dart';
import 'package:hdbhms_mobile/services/room_transfer/room_transfer_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';

/// Screen for nominating a holder for the room transfer.
/// The nominating tenant selects which transferring tenant will be the
/// contract holder for the target room.
class HolderNominationScreen extends StatefulWidget {
  const HolderNominationScreen({
    super.key,
    required this.transferRequest,
    this.transferService = const RoomTransferService(),
  });

  final RoomTransferRequest transferRequest;
  final RoomTransferService transferService;

  @override
  State<HolderNominationScreen> createState() => _HolderNominationScreenState();
}

class _HolderNominationScreenState extends State<HolderNominationScreen> {
  final _profileIdCtrl = TextEditingController();
  bool _submitting = false;

  RoomTransferRequest get _transfer => widget.transferRequest;

  @override
  void dispose() {
    _profileIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rawId = _profileIdCtrl.text.trim();
    if (rawId.isEmpty) {
      _snack('Vui lòng nhập ID người được đề cử.');
      return;
    }
    final profileId = int.tryParse(rawId);
    if (profileId == null || profileId <= 0) {
      _snack('ID không hợp lệ.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.transferService.nominateHolder(
        requestId: _transfer.id,
        nominatedHolderProfileId: profileId,
      );
      if (!mounted) return;
      _showSuccessDialog();
    } on RoomTransferException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      _snack('Không thể đề cử. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _acceptNomination() async {
    setState(() => _submitting = true);
    try {
      await widget.transferService.acceptHolderNomination(_transfer.id);
      if (!mounted) return;
      _snack('Đã chấp nhận đề cử.');
      Navigator.of(context).pop(true);
    } on RoomTransferException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      _snack('Không thể chấp nhận. Vui lòng thử lại.');
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 48),
        title: const Text('Đề cử thành công',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Đã đề cử người giữ hợp đồng mới cho phòng đích.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
            child: Text('Đề cử chủ hợp đồng', style: AppColors.topBarTitleStyle),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
      children: [
        // ── Transfer info summary ──────────────────────────────────────
        _SectionCard(
          title: 'Thông tin chuyển phòng',
          icon: Icons.swap_horiz_rounded,
          children: [
            _InfoRow(label: 'Mã yêu cầu', value: _transfer.requestCode),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFEEECEE)),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Phòng cũ',
              value: _transfer.oldRoomName.isNotEmpty
                  ? _transfer.oldRoomName
                  : _transfer.oldRoomCode,
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFEEECEE)),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Phòng đích',
              value: _transfer.targetRoomName.isNotEmpty
                  ? _transfer.targetRoomName
                  : _transfer.targetRoomCode,
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFEEECEE)),
            const SizedBox(height: 8),
            _InfoRow(label: 'Trạng thái', value: _transfer.status.label),
          ],
        ),

        const SizedBox(height: 14),

        // ── Nomination form ────────────────────────────────────────────
        _SectionCard(
          title: 'Đề cử người giữ hợp đồng',
          icon: Icons.person_outline_rounded,
          children: [
            const Text(
              'Chọn người sẽ đứng tên hợp đồng tại phòng đích. '
              'Người này phải nằm trong danh sách người chuyển đi.',
              style: TextStyle(
                color: AppColors.bodyText,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'ID người được đề cử',
              style: TextStyle(
                color: AppColors.inputText,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _profileIdCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Nhập ID profile người được đề cử',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                filled: true,
                fillColor: AppColors.inputFill,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              style: const TextStyle(
                color: AppColors.inputText,
                fontSize: 14,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ── Nominate button ────────────────────────────────────────────
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  AppColors.deepBlue.withValues(alpha: 0.5),
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
                    'Đề cử',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),

        // ── Accept nomination (if nominated) ───────────────────────────
        if (_transfer.nominatedHolderProfileId != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF1FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.deepBlue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã đề cử profile ID: ${_transfer.nominatedHolderProfileId}',
                    style: const TextStyle(
                      color: AppColors.deepBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _submitting ? null : _acceptNomination,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF16A34A),
                side: const BorderSide(color: Color(0xFF16A34A)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Chấp nhận đề cử',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
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
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppColors.inputText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
