import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/change_request/change_request_model.dart';
import 'package:hdbhms_mobile/models/room_transfer/room_transfer_model.dart';
import 'package:hdbhms_mobile/screens/room_transfer/transfer_execution_screen.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/services/room_transfer/room_transfer_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';

/// Detail screen for a room-transfer change request.
/// Shows the change-request info, and if the linked transfer request is
/// available, shows transfer-specific status & contextual action buttons.
class RoomTransferDetailScreen extends StatefulWidget {
  const RoomTransferDetailScreen({
    super.key,
    required this.changeRequest,
    this.transferService = const RoomTransferService(),
    this.leaseContractService = const LeaseContractService(),
  });

  final ChangeRequest changeRequest;
  final RoomTransferService transferService;
  final LeaseContractService leaseContractService;

  @override
  State<RoomTransferDetailScreen> createState() =>
      _RoomTransferDetailScreenState();
}

class _RoomTransferDetailScreenState extends State<RoomTransferDetailScreen> {
  RoomTransferRequest? _transfer;
  bool _loadingTransfer = false;
  bool _transferLoadAttempted = false;
  String? _transferLoadError;
  bool _actionInProgress = false;
  bool _checkingTargetHolderAccess = false;
  bool _isVerifiedTargetHolder = false;

  ChangeRequest get _req => widget.changeRequest;

  bool get _isResolvingScreenState =>
      _loadingTransfer ||
      (_transfer != null && _checkingTargetHolderAccess);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tryLoadTransfer();
  }

  void _tryLoadTransfer() {
    final transferId = _extractTransferId();
    if (transferId == null) {
      setState(() {
        _transferLoadAttempted = true;
        _loadingTransfer = false;
        _transferLoadError = 'Không tìm thấy liên kết yêu cầu chuyển phòng.';
      });
      return;
    }

    setState(() {
      _loadingTransfer = true;
      _transferLoadAttempted = true;
      _transferLoadError = null;
    });

    widget.transferService
        .getTransferRequest(transferId)
        .then((transfer) async {
      if (!mounted) return;
      setState(() {
        _transfer = transfer;
        _loadingTransfer = false;
        _transferLoadError = null;
      });
      await _resolveTargetHolderAccess(transfer);
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _loadingTransfer = false;
          _transferLoadError = 'Không tải được chi tiết chuyển phòng. Vui lòng thử lại.';
        });
      }
    });
  }

  int? _extractTransferId() {
    if (_req.targetId != null && _req.targetId! > 0) {
      return _req.targetId;
    }

    final rawPayload = _req.requestPayload;
    if (rawPayload != null && rawPayload.trim().isNotEmpty) {
      try {
        final payload = jsonDecode(rawPayload);
        if (payload is Map<String, dynamic>) {
          final fromPayload =
              int.tryParse(payload['transferRequestId']?.toString() ?? '') ??
              int.tryParse(payload['targetId']?.toString() ?? '') ??
              int.tryParse(payload['id']?.toString() ?? '');
          if (fromPayload != null && fromPayload > 0) {
            return fromPayload;
          }
        }
      } catch (_) {
        // Ignore malformed payload and continue with legacy fallback.
      }
    }

    // Legacy fallback only when structured linkage is absent.
    final textToSearch = '${_req.title} ${_req.description}';

    final match =
        RegExp(r'(?:transfer.*id|id)[:\s]*(\d+)', caseSensitive: false)
            .firstMatch(textToSearch);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }

    final numbers = RegExp(r'\b(\d{8,})\b').allMatches(textToSearch);
    for (final m in numbers) {
      final num = int.tryParse(m.group(1)!);
      if (num != null && num > 0) return num;
    }

    return null;
  }

  Future<void> _resolveTargetHolderAccess(RoomTransferRequest transfer) async {
    if (!mounted) return;
    if (transfer.status != TransferRequestStatus.waitingTargetHolderApproval ||
        transfer.targetTransferType != TargetTransferType.otherContract) {
      setState(() {
        _checkingTargetHolderAccess = false;
        _isVerifiedTargetHolder = false;
      });
      return;
    }

    setState(() {
      _checkingTargetHolderAccess = true;
      _isVerifiedTargetHolder = false;
    });

    try {
      final pendingApprovals = await widget.transferService
          .fetchPendingTargetHolderApprovals();
      final isPendingForCurrentUser = pendingApprovals.any(
        (item) => item.id == transfer.id,
      );
      if (!mounted) return;

      if (isPendingForCurrentUser) {
        setState(() {
          _checkingTargetHolderAccess = false;
          _isVerifiedTargetHolder = true;
        });
        return;
      }
    } catch (_) {
      // Fall back to contract-role check below when pending list is unavailable.
    }

    if (transfer.targetContractId == null || transfer.targetContractId! <= 0) {
      if (!mounted) return;
      setState(() {
        _checkingTargetHolderAccess = false;
        _isVerifiedTargetHolder = false;
      });
      return;
    }

    try {
      final contract = await widget.leaseContractService.getContractById(
        transfer.targetContractId!,
      );
      if (!mounted) return;
      setState(() {
        _checkingTargetHolderAccess = false;
        _isVerifiedTargetHolder =
            contract.isPrimary ||
            contract.roleInContract.toUpperCase() == 'PRIMARY';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingTargetHolderAccess = false;
        _isVerifiedTargetHolder = false;
      });
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _cancelTransfer() async {
    if (_transfer == null) return;
    final confirmed = await _confirmDialog(
      title: 'Hủy yêu cầu chuyển phòng',
      content: 'Bạn có chắc muốn hủy yêu cầu chuyển phòng này? Hành động này không thể hoàn tác.',
      confirmLabel: 'Hủy yêu cầu',
      isDestructive: true,
    );
    if (!confirmed) return;

    setState(() => _actionInProgress = true);
    try {
      await widget.transferService.cancelTransferRequest(_transfer!.id);
      if (!mounted) return;
      _snack('Đã hủy yêu cầu chuyển phòng.');
      Navigator.of(context).pop(true); // signal refresh
    } on RoomTransferException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      _snack('Không thể hủy yêu cầu. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _confirmContract() async {
    if (_transfer == null) return;
    setState(() => _actionInProgress = true);
    try {
      await widget.transferService.confirmTransferContract(_transfer!.id);
      if (!mounted) return;
      _snack('Đã xác nhận hợp đồng chuyển phòng.');
      Navigator.of(context).pop(true);
    } on RoomTransferException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      _snack('Không thể xác nhận. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _signContract() async {
    if (_transfer == null) return;
    setState(() => _actionInProgress = true);
    try {
      await widget.transferService.signTransferContract(_transfer!.id);
      if (!mounted) return;
      _snack('Đã ký hợp đồng chuyển phòng.');
      Navigator.of(context).pop(true);
    } on RoomTransferException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      _snack('Không thể ký hợp đồng. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _rejectContract() async {
    if (_transfer == null) return;
    final confirmed = await _confirmDialog(
      title: 'Từ chối hợp đồng',
      content: 'Bạn có chắc muốn từ chối hợp đồng chuyển phòng này?',
      confirmLabel: 'Từ chối',
      isDestructive: true,
    );
    if (!confirmed) return;

    setState(() => _actionInProgress = true);
    try {
      await widget.transferService.rejectTransferContract(_transfer!.id);
      if (!mounted) return;
      _snack('Đã từ chối hợp đồng chuyển phòng.');
      Navigator.of(context).pop(true);
    } on RoomTransferException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      _snack('Không thể từ chối. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  // ── Target Holder Approval Actions ─────────────────────────────────────

  Future<void> _approveTargetHolderTransfer() async {
    if (_transfer == null) return;
    final confirmed = await _confirmDialog(
      title: 'Đồng ý chuyển phòng',
      content: 'Bạn có chắc muốn chấp nhận yêu cầu chuyển phòng này vào phòng của bạn? Sau khi đồng ý, hợp đồng thỏa thuận sẽ được tạo.',
      confirmLabel: 'Đồng ý',
      isDestructive: false,
    );
    if (!confirmed) return;

    setState(() => _actionInProgress = true);
    try {
      await widget.transferService.approveTargetHolderTransfer(_transfer!.id);
      if (!mounted) return;
      _snack('Đã đồng ý yêu cầu chuyển phòng.');
      Navigator.of(context).pop(true);
    } on RoomTransferException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      _snack('Không thể phê duyệt. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _rejectTargetHolderTransfer() async {
    if (_transfer == null) return;
    final confirmed = await _confirmDialog(
      title: 'Từ chối chuyển phòng',
      content: 'Bạn có chắc muốn từ chối yêu cầu chuyển phòng này?',
      confirmLabel: 'Từ chối',
      isDestructive: true,
    );
    if (!confirmed) return;

    setState(() => _actionInProgress = true);
    try {
      await widget.transferService.rejectTargetHolderTransfer(_transfer!.id);
      if (!mounted) return;
      _snack('Đã từ chối yêu cầu chuyển phòng.');
      Navigator.of(context).pop(true);
    } on RoomTransferException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      _snack('Không thể từ chối. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  bool get _isTargetHolder {
    if (_transfer == null) return false;
    return !_checkingTargetHolderAccess &&
        _isVerifiedTargetHolder &&
        _transfer!.status == TransferRequestStatus.waitingTargetHolderApproval &&
        _transfer!.targetTransferType == TargetTransferType.otherContract;
  }

  void _navigateToExecution() {
    if (_transfer == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransferExecutionScreen(transfer: _transfer!),
      ),
    ).then((result) {
      if (result == true && mounted) {
        Navigator.of(context).pop(true); // Signal refresh to parent
      }
    });
  }

  Future<bool> _confirmDialog({
    required String title,
    required String content,
    required String confirmLabel,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy bỏ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDestructive ? const Color(0xFFDC2626) : AppColors.deepBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
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
            child: Text('Chi tiết chuyển phòng', style: AppColors.topBarTitleStyle),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
      children: [
        // ── Status banner ──────────────────────────────────────────────
        _StatusBanner(status: _req.status),

        const SizedBox(height: 14),

        // ── Transfer Status Timeline / loading state ───────────────────
        if (_isResolvingScreenState)
          _TransferLoadingCard(
            message: _loadingTransfer
                ? 'Đang tải chi tiết chuyển phòng...'
                : 'Đang xác định quyền phê duyệt và hành động khả dụng...',
          )
        else if (_transfer != null)
          _StatusTimeline(
            currentStatus: _transfer!.status,
            targetTransferType: _transfer!.targetTransferType,
          )
        else if (_transferLoadAttempted)
          _TransferLoadStateCard(
            message: _transferLoadError ?? 'Không có dữ liệu chuyển phòng.',
            onRetry: _tryLoadTransfer,
          ),

        const SizedBox(height: 14),

        // ── Change request info ────────────────────────────────────────
        _SectionCard(
          title: 'Thông tin yêu cầu',
          icon: Icons.info_outline_rounded,
          children: [
            _InfoRow(label: 'Mã yêu cầu', value: _req.requestCode.isNotEmpty ? _req.requestCode : '--'),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFEEECEE)),
            const SizedBox(height: 8),
            _InfoRow(label: 'Trạng thái', value: _req.status.label, valueColor: _statusColor),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFEEECEE)),
            const SizedBox(height: 8),
            _InfoRow(label: 'Ngày tạo', value: _formatDate(_req.createdAt)),
            if (_req.resolvedAt != null) ...[
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFEEECEE)),
              const SizedBox(height: 8),
              _InfoRow(label: 'Ngày xử lý', value: _formatDate(_req.resolvedAt)),
            ],
          ],
        ),

        // ── Description ────────────────────────────────────────────────
        if (_req.description.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Mô tả / Lý do',
            icon: Icons.notes_outlined,
            children: [
              Text(
                _req.description,
                style: const TextStyle(
                  color: AppColors.inputText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ],

        // ── Resolution note ────────────────────────────────────────────
        if (_req.resolutionNote != null && _req.resolutionNote!.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Ghi chú từ quản lý',
            icon: Icons.comment_outlined,
            children: [
              Text(
                _req.resolutionNote!,
                style: const TextStyle(
                  color: AppColors.inputText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ],

        // ── Transfer-specific info (when linked transfer is loaded) ────
        if (_transfer != null) ...[
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Thông tin chuyển phòng',
            icon: Icons.swap_horiz_rounded,
            children: [
              _InfoRow(label: 'Mã yêu cầu', value: _transfer!.requestCode),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFEEECEE)),
              const SizedBox(height: 8),
              _InfoRow(label: 'Phòng cũ', value: _transfer!.oldRoomName.isNotEmpty ? _transfer!.oldRoomName : _transfer!.oldRoomCode),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFEEECEE)),
              const SizedBox(height: 8),
              _InfoRow(label: 'Phòng đích', value: _transfer!.targetRoomName.isNotEmpty ? _transfer!.targetRoomName : _transfer!.targetRoomCode),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFEEECEE)),
              const SizedBox(height: 8),
              _InfoRow(label: 'Loại chuyển', value: _transfer!.targetTransferType.label),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFEEECEE)),
              const SizedBox(height: 8),
              _InfoRow(label: 'Ngày chuyển dự kiến', value: _formatDate(_transfer!.requestedTransferDate)),
              _InfoRow(label: 'Trạng thái chuyển', value: _transfer!.status.label),
            ],
          ),
        ],

        // ── Target Holder Approval Section ─────────────────────────────
        if (_transfer != null && _isTargetHolder) ...[
          const SizedBox(height: 14),
          _TargetHolderApprovalCard(
            transfer: _transfer!,
            onApprove: _approveTargetHolderTransfer,
            onReject: _rejectTargetHolderTransfer,
            busy: _actionInProgress,
          ),
        ],

        // ── Action buttons ─────────────────────────────────────────────
        const SizedBox(height: 24),
        ..._buildActions(),
      ],
    );
  }

  List<Widget> _buildActions() {
    final actions = <Widget>[];
    final busy = _actionInProgress;

    if (_isResolvingScreenState) {
      actions.add(_TransferActionLoadingCard(
        message: _loadingTransfer
            ? 'Đang tải chi tiết yêu cầu...'
            : 'Đang xác định hành động khả dụng...',
      ));
      return actions;
    }

    // Cancel: available when pending and transfer exists
    if (_req.status == ChangeRequestStatus.pending && _transfer != null) {
      actions.add(_ActionButton(
        label: 'Hủy yêu cầu chuyển phòng',
        icon: Icons.cancel_outlined,
        color: const Color(0xFFDC2626),
        busy: busy,
        onTap: _cancelTransfer,
      ));
    }

    // Transfer-specific contract actions
    if (_transfer != null) {
      switch (_transfer!.status) {
        case TransferRequestStatus.waitingContractConfirmation:
          actions.add(_ActionButton(
            label: 'Xác nhận hợp đồng',
            icon: Icons.check_circle_outline,
            color: const Color(0xFF16A34A),
            busy: busy,
            onTap: _confirmContract,
          ));
          actions.add(const SizedBox(height: 10));
          actions.add(_ActionButton(
            label: 'Từ chối hợp đồng',
            icon: Icons.cancel_outlined,
            color: const Color(0xFFDC2626),
            busy: busy,
            onTap: _rejectContract,
          ));
          break;
        case TransferRequestStatus.waitingSigning:
          actions.add(_ActionButton(
            label: 'Ký hợp đồng',
            icon: Icons.draw_outlined,
            color: AppColors.deepBlue,
            busy: busy,
            onTap: _signContract,
          ));
          break;
        case TransferRequestStatus.waitingTargetHolderApproval:
          // Target holder approval is handled by the embedded card
          // No action button needed here
          break;
        case TransferRequestStatus.waitingExecution:
          actions.add(_ActionButton(
            label: 'Thực hiện chuyển phòng',
            icon: Icons.swap_horiz_rounded,
            color: AppColors.deepBlue,
            busy: busy,
            onTap: _navigateToExecution,
          ));
          break;
        default:
          break;
      }
    }

    // If no transfer-specific actions, show generic close
    if (actions.isEmpty &&
        !_isTargetHolder &&
        (!_transferLoadAttempted || _transferLoadError == null)) {
      actions.add(SizedBox(
        width: double.infinity,
        height: 46,
        child: OutlinedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.deepBlue,
            side: const BorderSide(color: AppColors.deepBlue),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Đóng',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ));
    }

    return actions;
  }

  Color get _statusColor => switch (_req.status) {
    ChangeRequestStatus.pending => const Color(0xFFD97706),
    ChangeRequestStatus.underReview => AppColors.deepBlue,
    ChangeRequestStatus.approved => const Color(0xFF16A34A),
    ChangeRequestStatus.rejected => const Color(0xFFDC2626),
    ChangeRequestStatus.processing => const Color(0xFF2563EB),
    ChangeRequestStatus.completed => const Color(0xFF16A34A),
    ChangeRequestStatus.cancelled => const Color(0xFF6B7280),
  };

  String _formatDate(DateTime? dt) {
    if (dt == null) return '--';
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final ChangeRequestStatus status;

  IconData get _icon => switch (status) {
    ChangeRequestStatus.pending => Icons.hourglass_empty,
    ChangeRequestStatus.underReview => Icons.search,
    ChangeRequestStatus.approved => Icons.check_circle,
    ChangeRequestStatus.rejected => Icons.cancel,
    ChangeRequestStatus.processing => Icons.sync,
    ChangeRequestStatus.completed => Icons.check_circle,
    ChangeRequestStatus.cancelled => Icons.block,
  };

  Color get _color => switch (status) {
    ChangeRequestStatus.pending => const Color(0xFFD97706),
    ChangeRequestStatus.underReview => AppColors.deepBlue,
    ChangeRequestStatus.approved => const Color(0xFF16A34A),
    ChangeRequestStatus.rejected => const Color(0xFFDC2626),
    ChangeRequestStatus.processing => const Color(0xFF2563EB),
    ChangeRequestStatus.completed => const Color(0xFF16A34A),
    ChangeRequestStatus.cancelled => const Color(0xFF6B7280),
  };

  Color get _bg => switch (status) {
    ChangeRequestStatus.pending => const Color(0xFFFFF7ED),
    ChangeRequestStatus.underReview => const Color(0xFFEFF1FF),
    ChangeRequestStatus.approved => const Color(0xFFD4F8DE),
    ChangeRequestStatus.rejected => const Color(0xFFFFE4E4),
    ChangeRequestStatus.processing => const Color(0xFFEFF1FF),
    ChangeRequestStatus.completed => const Color(0xFFD4F8DE),
    ChangeRequestStatus.cancelled => const Color(0xFFF5F5F5),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(_icon, color: _color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.label,
                  style: TextStyle(
                    color: _color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle,
                  style: TextStyle(
                    color: _color.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _subtitle => switch (status) {
    ChangeRequestStatus.pending => 'Yêu cầu đang chờ quản lý xem xét.',
    ChangeRequestStatus.underReview => 'Quản lý đang xem xét yêu cầu của bạn.',
    ChangeRequestStatus.approved => 'Yêu cầu đã được chấp thuận.',
    ChangeRequestStatus.rejected => 'Yêu cầu đã bị từ chối.',
    ChangeRequestStatus.processing => 'Yêu cầu đang được xử lý.',
    ChangeRequestStatus.completed => 'Yêu cầu đã hoàn tất.',
    ChangeRequestStatus.cancelled => 'Yêu cầu đã bị hủy.',
  };
}

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
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
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
            style: TextStyle(
              color: valueColor ?? AppColors.inputText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: busy ? null : onTap,
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _TransferLoadingCard extends StatelessWidget {
  const _TransferLoadingCard({
    this.message = 'Đang tải chi tiết chuyển phòng...',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.deepBlue,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.inputText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferLoadStateCard extends StatelessWidget {
  const _TransferLoadStateCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                Icons.error_outline_rounded,
                color: Color(0xFFD97706),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Không tải được chi tiết',
                style: TextStyle(
                  color: Color(0xFF000666),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.bodyText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Tải lại',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.deepBlue,
                side: const BorderSide(color: AppColors.deepBlue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferActionLoadingCard extends StatelessWidget {
  const _TransferActionLoadingCard({
    this.message = 'Đang xác định hành động khả dụng...',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF1FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7DCFF)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.deepBlue,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.deepBlue,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Target Holder Approval Card ────────────────────────────────────────────

class _TargetHolderApprovalCard extends StatelessWidget {
  const _TargetHolderApprovalCard({
    required this.transfer,
    required this.onApprove,
    required this.onReject,
    this.busy = false,
  });

  final RoomTransferRequest transfer;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_add_outlined,
                color: const Color(0xFFD97706),
                size: 22,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Yêu cầu chuyển vào phòng bạn',
                  style: TextStyle(
                    color: Color(0xFF92400E),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Một người dùng đang yêu cầu chuyển vào phòng của bạn. Vui lòng xem xét và phê duyệt hoặc từ chối yêu cầu này.',
            style: TextStyle(
              color: Color(0xFF92400E),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ApprovalButton(
                  label: 'Từ chối',
                  icon: Icons.close_outlined,
                  color: const Color(0xFFDC2626),
                  busy: busy,
                  onTap: onReject,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ApprovalButton(
                  label: 'Đồng ý',
                  icon: Icons.check_outlined,
                  color: const Color(0xFF16A34A),
                  busy: busy,
                  onTap: onApprove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovalButton extends StatelessWidget {
  const _ApprovalButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: busy ? null : onTap,
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

// ── Status Timeline ────────────────────────────────────────────────────────

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({
    required this.currentStatus,
    required this.targetTransferType,
  });

  final TransferRequestStatus currentStatus;
  final TargetTransferType targetTransferType;

  List<_TimelineStep> get _steps {
    final steps = <_TimelineStep>[
      _TimelineStep(
        status: TransferRequestStatus.waitingApproval,
        label: 'Yêu cầu được tạo',
        icon: Icons.edit_note_outlined,
      ),
      _TimelineStep(
        status: TransferRequestStatus.waitingApproval,
        label: 'Quản lý phê duyệt',
        icon: Icons.verified_outlined,
      ),
    ];

    // Add type-specific steps
    if (targetTransferType == TargetTransferType.otherContract) {
      steps.add(_TimelineStep(
        status: TransferRequestStatus.waitingTargetHolderApproval,
        label: 'Chủ phòng đích phê duyệt',
        icon: Icons.how_to_reg_outlined,
      ));
    }

    steps.addAll([
      _TimelineStep(
        status: TransferRequestStatus.waitingContractConfirmation,
        label: 'Chờ xác nhận hợp đồng',
        icon: Icons.task_outlined,
      ),
      _TimelineStep(
        status: TransferRequestStatus.waitingSigning,
        label: 'Chờ ký hợp đồng',
        icon: Icons.draw_outlined,
      ),
      _TimelineStep(
        status: TransferRequestStatus.waitingExecution,
        label: 'Chờ thực hiện',
        icon: Icons.swap_horiz_outlined,
      ),
      _TimelineStep(
        status: TransferRequestStatus.executed,
        label: 'Hoàn thành',
        icon: Icons.check_circle_outlined,
      ),
    ]);

    return steps;
  }

  bool _isCompleted(_TimelineStep step) {
    final statusOrder = [
      TransferRequestStatus.waitingApproval,
      TransferRequestStatus.waitingNewContract,
      TransferRequestStatus.waitingTargetHolderApproval,
      TransferRequestStatus.waitingContractConfirmation,
      TransferRequestStatus.waitingSigning,
      TransferRequestStatus.waitingExecution,
      TransferRequestStatus.executed,
    ];

    final currentIndex = statusOrder.indexWhere((s) => s == currentStatus);
    final stepIndex = statusOrder.indexWhere((s) => s == step.status);

    // Terminal states
    if (currentStatus == TransferRequestStatus.cancelled ||
        currentStatus == TransferRequestStatus.rejected ||
        currentStatus == TransferRequestStatus.expired) {
      return false;
    }

    return stepIndex < currentIndex;
  }

  bool _isCurrent(_TimelineStep step) {
    return step.status == currentStatus;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(Icons.timeline_outlined, color: AppColors.deepBlue, size: 20),
              SizedBox(width: 8),
              Text(
                'Tiến trình xử lý',
                style: TextStyle(
                  color: Color(0xFF000666),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._buildTimelineItems(),
        ],
      ),
    );
  }

  List<Widget> _buildTimelineItems() {
    final widgets = <Widget>[];

    for (int i = 0; i < _steps.length; i++) {
      final step = _steps[i];
      final isCompleted = _isCompleted(step);
      final isCurrent = _isCurrent(step);

      widgets.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF16A34A)
                        : isCurrent
                            ? AppColors.deepBlue
                            : const Color(0xFFE5E7EB),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    step.icon,
                    size: 18,
                    color: isCompleted || isCurrent ? Colors.white : AppColors.bodyText,
                  ),
                ),
                if (i < _steps.length - 1)
                  Container(
                    width: 2,
                    height: 24,
                    color: isCompleted
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFE5E7EB),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  step.label,
                  style: TextStyle(
                    color: isCompleted
                        ? const Color(0xFF16A34A)
                        : isCurrent
                            ? AppColors.deepBlue
                            : AppColors.bodyText,
                    fontSize: 13,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return widgets;
  }
}

class _TimelineStep {
  const _TimelineStep({
    required this.status,
    required this.label,
    required this.icon,
  });

  final TransferRequestStatus status;
  final String label;
  final IconData icon;
}
