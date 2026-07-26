import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/room_transfer/room_transfer_model.dart';
import 'package:hdbhms_mobile/services/room_transfer/room_transfer_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';

/// Screen for nominating a replacement holder for the source room.
/// The nominating tenant selects one remaining occupant from the old contract.
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
  late RoomTransferRequest _transfer;
  int? _selectedProfileId;
  bool _submitting = false;
  bool _loadingTransfer = true;

  @override
  void initState() {
    super.initState();
    _transfer = widget.transferRequest;
    _syncSelectedProfile();
    _refreshTransfer();
  }

  void _syncSelectedProfile() {
    final candidates = _holderCandidateIds;
    if (candidates.isEmpty) {
      _selectedProfileId = null;
      return;
    }

    final current = _selectedProfileId;
    final nominated = _transfer.nominatedHolderProfileId;
    if (current != null && candidates.contains(current)) {
      _selectedProfileId = current;
    } else if (nominated != null && candidates.contains(nominated)) {
      _selectedProfileId = nominated;
    } else {
      _selectedProfileId = candidates.first;
    }
  }

  Future<void> _refreshTransfer() async {
    if (!_loadingTransfer) {
      setState(() => _loadingTransfer = true);
    }
    try {
      final latest = await widget.transferService.getTransferRequest(
        _transfer.id,
      );
      if (!mounted) return;
      setState(() {
        _transfer = latest;
        _syncSelectedProfile();
        _loadingTransfer = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTransfer = false);
    }
  }

  List<int> get _holderCandidateIds {
    final ids = _transfer.sourceHolderCandidateProfileIds
        .where((id) => id > 0)
        .toSet()
        .toList();
    ids.sort(
      (a, b) => _holderDisplayName(
        a,
      ).toLowerCase().compareTo(_holderDisplayName(b).toLowerCase()),
    );
    return ids;
  }

  String _holderDisplayName(int profileId) {
    final name = _transfer.sourceHolderCandidateNames[profileId]?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return 'Người thuê #$profileId';
  }

  Future<void> _submit() async {
    final profileId = _selectedProfileId;
    if (profileId == null || profileId <= 0) {
      _snack(
        'Vui lòng chọn người ở lại phòng cũ làm người đứng tên hợp đồng mới.',
      );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
        icon: const Icon(
          Icons.check_circle,
          color: AppColors.successText,
          size: 48,
        ),
        title: const Text(
          'Đề cử thành công',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Đã đề cử người đứng tên hợp đồng mới cho phòng cũ.',
        ),
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
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
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
              'Đề cử chủ hợp đồng',
              style: AppColors.topBarTitleStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AppTopBar(
      title: 'Đề cử chủ hợp đồng',
      onBack: () => Navigator.of(context).maybePop(),
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
              'Chọn người ở lại phòng cũ sẽ trở thành người đứng tên hợp đồng mới sau khi bạn chuyển phòng.',
              style: TextStyle(
                color: AppColors.bodyText,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            if (_holderCandidateIds.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningSurface,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  border: Border.all(color: AppColors.warning),
                ),
                child: const Text(
                  'Không tìm thấy người ở lại phòng cũ phù hợp để đề cử làm người đứng tên hợp đồng mới.',
                  style: TextStyle(
                    color: AppColors.warningText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              )
            else
              DropdownButtonFormField<int>(
                initialValue: _selectedProfileId,
                decoration: const InputDecoration(
                  labelText: 'Người đứng tên hợp đồng mới của phòng cũ',
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
                items: _holderCandidateIds
                    .map(
                      (profileId) => DropdownMenuItem<int>(
                        value: profileId,
                        child: Text(_holderDisplayName(profileId)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _submitting || _loadingTransfer
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _selectedProfileId = value);
                      },
              ),
          ],
        ),

        const SizedBox(height: 24),

        // ── Nominate button ────────────────────────────────────────────
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed:
                _submitting || _loadingTransfer || _holderCandidateIds.isEmpty
                ? null
                : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.deepBlue.withValues(
                alpha: 0.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
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
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
          ),
        ),

        // ── Accept nomination (if nominated) ───────────────────────────
        if (!_loadingTransfer &&
            _transfer.nominatedHolderProfileId != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
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
                    'Đã đề cử: ${_holderDisplayName(_transfer.nominatedHolderProfileId!)}',
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
                foregroundColor: AppColors.successText,
                side: const BorderSide(color: AppColors.successText),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
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
