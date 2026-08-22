import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:hdbhms_mobile/models/maintenance/maintenance_ticket_model.dart';
import 'package:hdbhms_mobile/services/maintenance/maintenance_ticket_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/widgets/ticket_attachment_grid.dart';
import 'package:hdbhms_mobile/widgets/ticket_status_badge.dart';
import 'package:hdbhms_mobile/widgets/ticket_timeline.dart';
import 'package:hdbhms_mobile/widgets/app_notification_bell.dart';
import 'package:hdbhms_mobile/widgets/app_primary_gradient_button.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_review_screen.dart';
import 'package:hdbhms_mobile/screens/notification/notification_list_screen.dart';
import 'package:hdbhms_mobile/screens/payment/bill_selection_page.dart';

class MaintenanceTicketDetailScreen extends StatefulWidget {
  const MaintenanceTicketDetailScreen({
    super.key,
    required this.ticketId,
    this.ticket,
    this.role = TicketUserRole.tenant,
    this.ticketService = const MaintenanceTicketService(),
    this.imagePicker,
    this.notificationInitialUnreadCount,
  });

  final int ticketId;
  final MaintenanceTicketModel? ticket;
  final TicketUserRole role;
  final MaintenanceTicketService ticketService;
  final ImagePicker? imagePicker;
  final int? notificationInitialUnreadCount;

  @override
  State<MaintenanceTicketDetailScreen> createState() =>
      _MaintenanceTicketDetailScreenState();
}

class _MaintenanceTicketDetailScreenState
    extends State<MaintenanceTicketDetailScreen> {
  MaintenanceTicketDetail? _detail;
  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _errorMessage;

  ImagePicker get _imagePicker => widget.imagePicker ?? ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail = await widget.ticketService.getTicketDetail(
        widget.ticketId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    } on MaintenanceTicketException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Không thể tải chi tiết sự cố. Vui lòng thử lại.';
        _isLoading = false;
      });
    }
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() {
      _isActionLoading = true;
    });
    try {
      await action();
      if (!mounted) {
        return;
      }
      _showSnackBar(successMessage);
      await _loadDetail();
    } on MaintenanceTicketException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Thao tác thất bại, vui lòng thử lại');
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  Future<void> _acceptTicket() async {
    final confirmed = await _showConfirmDialog(
      title: 'Tiếp nhận phiếu',
      content: 'Bạn muốn tiếp nhận phiếu sự cố này?',
      confirmText: 'Tiếp nhận',
    );
    if (confirmed != true) {
      return;
    }
    await _runAction(
      () => widget.ticketService.acceptTicket(widget.ticketId),
      'Đã tiếp nhận phiếu sự cố',
    );
  }

  Future<void> _rejectTicket() async {
    final reason = await _showRejectDialog();
    if (reason == null) {
      return;
    }
    await _runAction(
      () => widget.ticketService.rejectTicket(widget.ticketId, reason),
      'Đã từ chối phiếu sự cố',
    );
  }

  Future<void> _updateProgress() async {
    final data = await showModalBottomSheet<_ProgressFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const _ProgressSheet(),
    );
    if (data == null) {
      return;
    }
    await _runAction(
      () => widget.ticketService.updateProgress(
        widget.ticketId,
        workerName: data.workerName,
        repairItems: data.repairItems,
        expectedCompletionDate: data.expectedCompletionDate,
        note: data.note,
      ),
      'Đã cập nhật tiến độ',
    );
  }

  Future<void> _submitRepairProposal() async {
    final data = await showModalBottomSheet<_RepairProposalFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const _RepairProposalSheet(),
    );
    if (data == null) {
      return;
    }
    await _runAction(
      () => widget.ticketService.updateRepairInfo(
        widget.ticketId,
        workerName: data.workerName,
        repairItems: data.repairItems,
        amount: data.amount,
        repairmanPhone: data.repairmanPhone,
        rootCause: data.rootCause,
        costResponsibility: data.costResponsibility,
      ),
      'Đã gửi phương án sửa chữa cho khách thuê',
    );
  }

  Future<void> _completeTicket() async {
    final data = await showModalBottomSheet<_CompleteFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) =>
          _CompleteSheet(imagePicker: _imagePicker, detail: _detail),
    );
    if (data == null) {
      return;
    }
    await _runAction(
      () => widget.ticketService.completeTicket(
        widget.ticketId,
        completionNote: data.completionNote,
        workerName: data.workerName,
        repairmanPhone: data.repairmanPhone,
        repairItems: data.repairItems,
        rootCause: data.rootCause,
        costDescription: data.costDescription,
        amount: data.amount,
        paidBy: data.paidBy,
        afterAttachments: data.afterAttachments,
      ),
      'Đã đánh dấu hoàn tất',
    );
  }

  Future<void> _confirmTicket() async {
    await _openReviewScreen();
  }

  Future<void> _decideRepair(bool approved) async {
    if (approved) {
      final confirmed = await _showConfirmDialog(
        title: 'Đồng ý sửa chữa',
        content: 'Bạn đồng ý với phương án và chi phí sửa chữa này?',
        confirmText: 'Đồng ý sửa',
      );
      if (confirmed != true) {
        return;
      }
      await _runAction(
        () =>
            widget.ticketService.decideRepair(widget.ticketId, approved: true),
        'Đã đồng ý phương án sửa chữa',
      );
      return;
    }

    final reason = await _showRejectDialog(
      title: 'Không đồng ý sửa chữa',
      reasonLabel: 'Lý do không đồng ý',
    );
    if (reason == null) {
      return;
    }
    await _runAction(
      () => widget.ticketService.decideRepair(
        widget.ticketId,
        approved: false,
        reason: reason,
      ),
      'Đã gửi quyết định không sửa chữa',
    );
  }

  Future<void> _reviewTicket() async {
    await _openReviewScreen();
  }

  Future<void> _openReviewScreen() async {
    final detail = _detail;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => MaintenanceTicketReviewScreen(
          ticketId: widget.ticketId,
          initialDetail: detail,
          ticketService: widget.ticketService,
        ),
      ),
    );
    if (updated == true && mounted) {
      await _loadDetail();
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(content),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppPrimaryGradientButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      height: 48,
                      borderRadius: 12,
                      child: Text(confirmText),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    await _waitForDialogDismissal();
    return result;
  }

  Future<String?> _showRejectDialog({
    String title = 'Từ chối phiếu',
    String reasonLabel = 'Lý do từ chối',
  }) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  minLines: 3,
                  maxLines: 4,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: reasonLabel,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Vui lòng nhập lý do từ chối'
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppPrimaryGradientButton(
                      onPressed: () {
                        if (formKey.currentState?.validate() != true) {
                          return;
                        }
                        Navigator.of(context).pop(controller.text.trim());
                      },
                      height: 48,
                      borderRadius: 12,
                      child: const Text('Từ chối'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    await _waitForDialogDismissal();
    controller.dispose();
    return result;
  }

  Future<void> _waitForDialogDismissal() async {
    // Navigator.pop completes before the dialog exit animation removes its overlay.
    await Future<void>.delayed(const Duration(milliseconds: 220));
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        foregroundColor: AppColors.deepBlue,
        toolbarHeight: AppColors.topBarHeight,
        elevation: 0,
        shape: Border(
          bottom: BorderSide(
            color: AppColors.cardBorder.withValues(alpha: 0.65),
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Trở về',
        ),
        title: const Text('Chi tiết sự cố', style: AppColors.topBarTitleStyle),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => NotificationListScreen(
                  roomId: detail?.roomId,
                  roomCode: detail?.roomCode ?? '',
                ),
              ),
            ),
            icon: AppNotificationBell(
              color: AppColors.topBarIconColor,
              size: AppColors.topBarIconSize,
              initialUnreadCount: widget.notificationInitialUnreadCount,
              roomId: detail?.roomId,
              roomCode: detail?.roomCode ?? '',
            ),
            tooltip: 'Thông báo',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: _isLoading
                ? const _LoadingState()
                : _errorMessage != null
                ? _ErrorState(message: _errorMessage!, onRetry: _loadDetail)
                : detail == null
                ? _ErrorState(
                    message: 'Không tìm thấy phiếu sự cố',
                    onRetry: _loadDetail,
                  )
                : RefreshIndicator(
                    color: AppColors.deepBlue,
                    onRefresh: _loadDetail,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 18, 14, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TicketStatusBanner(detail: detail),
                          const SizedBox(height: 14),
                          _TicketInfoCard(detail: detail),
                          const SizedBox(height: 14),
                          _SectionCard(
                            title: 'Ảnh đính kèm',
                            icon: Icons.photo_library_outlined,
                            child: TicketAttachmentGrid(
                              attachments: detail.beforeAttachments,
                              emptyText: 'Không có tệp đính kèm',
                              onAttachmentError: () =>
                                  _showSnackBar('Không tải được tệp đính kèm'),
                            ),
                          ),
                          if (_shouldShowAfterAttachments(detail)) ...[
                            const SizedBox(height: 14),
                            _SectionCard(
                              title: 'Ảnh sau sửa chữa',
                              icon: Icons.photo_camera_back_outlined,
                              child: TicketAttachmentGrid(
                                attachments: detail.afterAttachments,
                                emptyText: 'Chưa có ảnh sau sửa chữa',
                                onAttachmentError: () => _showSnackBar(
                                  'Không tải được tệp đính kèm',
                                ),
                              ),
                            ),
                          ],
                          if (_shouldShowRepairInfo(detail)) ...[
                            const SizedBox(height: 14),
                            _RepairInfoCard(detail: detail),
                          ],
                          if (_shouldShowBillingInfo(detail)) ...[
                            const SizedBox(height: 14),
                            _BillingInfoCard(detail: detail),
                          ],
                          if (_shouldShowReview(detail)) ...[
                            const SizedBox(height: 14),
                            _ReviewCard(review: detail.review),
                          ],
                          const SizedBox(height: 14),
                          _SectionCard(
                            title: 'Tiến trình xử lý',
                            icon: Icons.timeline_rounded,
                            child: TicketTimeline(
                              events: detail.events,
                              currentStatus: detail.status,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _ActionPanel(
                            role: widget.role,
                            detail: detail,
                            isLoading: _isActionLoading,
                            onAccept: _acceptTicket,
                            onReject: _rejectTicket,
                            onSubmitRepairProposal: _submitRepairProposal,
                            onUpdateProgress: _updateProgress,
                            onComplete: _completeTicket,
                            onConfirm: _confirmTicket,
                            onDecideRepair: _decideRepair,
                            onReview: _reviewTicket,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _TicketStatusBanner extends StatelessWidget {
  const _TicketStatusBanner({required this.detail});

  final MaintenanceTicketDetail detail;

  @override
  Widget build(BuildContext context) {
    final (icon, color, background, message) = switch (detail.status) {
      TicketStatus.pending => (
        Icons.schedule_rounded,
        const Color(0xFFD97706),
        const Color(0xFFFFF7ED),
        'Phiếu đã được gửi, đang chờ tiếp nhận.',
      ),
      TicketStatus.accepted => (
        Icons.assignment_turned_in_outlined,
        AppColors.primary,
        AppColors.primaryLight,
        'Yêu cầu đã được tiếp nhận và sẽ sớm được xử lý.',
      ),
      TicketStatus.waitingTenantDecision => (
        Icons.price_check_outlined,
        const Color(0xFFB45309),
        const Color(0xFFFFF7ED),
        'Quản lý đã gửi phương án và chi phí. Vui lòng quyết định có sửa hay không.',
      ),
      TicketStatus.inProgress => (
        Icons.handyman_outlined,
        AppColors.primary,
        AppColors.primaryLight,
        'Sự cố đang được xử lý.',
      ),
      TicketStatus.waitingConfirmation => (
        Icons.fact_check_outlined,
        const Color(0xFF7C3AED),
        const Color(0xFFF1EAFE),
        'Vui lòng kiểm tra và xác nhận kết quả xử lý.',
      ),
      TicketStatus.completed => (
        Icons.check_circle_outline_rounded,
        AppColors.success,
        AppColors.successSurface,
        'Sự cố đã được xử lý hoàn tất.',
      ),
      TicketStatus.rejected => (
        Icons.cancel_outlined,
        AppColors.danger,
        AppColors.dangerSurface,
        'Phiếu đã bị từ chối.',
      ),
      TicketStatus.cancelled => (
        Icons.do_not_disturb_on_outlined,
        AppColors.bodyText,
        AppColors.surfaceMuted,
        'Phiếu đã được hủy.',
      ),
    };

    return Semantics(
      label: 'Trạng thái phiếu: ${detail.status.label}. $message',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.ticketStatusLabel.isNotEmpty
                        ? detail.ticketStatusLabel
                        : detail.status.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 20 / 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 16 / 12,
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

class _TicketInfoCard extends StatelessWidget {
  const _TicketInfoCard({required this.detail});

  final MaintenanceTicketDetail detail;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Thông tin sự cố',
      icon: Icons.report_problem_outlined,
      headerTrailing: TicketStatusBadge(status: detail.status),
      titleSubtitle: detail.ticketCode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoText(label: 'Loại sự cố', value: detail.categoryName),
          const SizedBox(height: 18),
          _InfoText(
            label: 'Thời gian tạo',
            value: _formatDateTime(detail.createdAt),
          ),
          const SizedBox(height: 18),
          _InfoText(
            label: 'Mong muốn xử lý',
            value: detail.repairRequested ? 'Cần sửa chữa' : 'Chỉ báo sự cố',
          ),
          const SizedBox(height: 18),
          _InfoText(label: 'Mô tả chi tiết', value: detail.description),
        ],
      ),
    );
  }
}

class _RepairInfoCard extends StatelessWidget {
  const _RepairInfoCard({required this.detail});

  final MaintenanceTicketDetail detail;

  @override
  Widget build(BuildContext context) {
    final repair = detail.repairInfo;
    final repairItems = _firstNonBlank(
      repair?.repairItems,
      repair?.costCategory,
    );
    final completionNote = repair?.completionNote;
    final repairLines = <Widget>[
      _RepairLine(
        icon: Icons.task_alt_rounded,
        label: 'Trạng thái xử lý',
        value: detail.ticketStatusLabel.isNotEmpty
            ? detail.ticketStatusLabel
            : detail.status.label,
      ),
      if (repair?.rootCause?.trim().isNotEmpty == true)
        _RepairLine(
          icon: Icons.search_rounded,
          label: 'Nguyên nhân',
          value: repair!.rootCause!,
        ),
      _RepairLine(
        icon: Icons.fact_check_outlined,
        label: _repairItemsLabel(detail.status),
        value: repairItems ?? 'Chưa cập nhật',
      ),
      _RepairLine(
        icon: Icons.engineering_outlined,
        label: 'Người sửa/thợ',
        value: _fallback(repair?.workerName),
      ),
      if (repair?.repairmanPhone?.trim().isNotEmpty == true)
        _RepairLine(
          icon: Icons.phone_outlined,
          label: 'Số điện thoại người sửa',
          value: repair!.repairmanPhone!.trim(),
        ),
      _RepairLine(
        icon: Icons.payments_outlined,
        label: _repairCostLabel(detail.status),
        value: repair?.totalCost == null
            ? 'Chưa cập nhật'
            : '${_formatCurrency(repair!.totalCost!)} VND',
      ),
      if (repair?.costResponsibility?.trim().isNotEmpty == true)
        _RepairLine(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Trách nhiệm',
          value: maintenanceCostResponsibilityLabel(repair!.costResponsibility),
        ),
      if (completionNote?.trim().isNotEmpty == true &&
          completionNote!.trim() != repairItems?.trim())
        _RepairLine(
          icon: Icons.notes_rounded,
          label: 'Ghi chú hoàn tất',
          value: completionNote,
        ),
    ];
    return _SectionCard(
      title: _repairCardTitle(detail.status),
      icon: Icons.handyman_outlined,
      child: Column(
        children: [
          for (var index = 0; index < repairLines.length; index++) ...[
            repairLines[index],
            if (index < repairLines.length - 1) const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _BillingInfoCard extends StatelessWidget {
  const _BillingInfoCard({required this.detail});

  final MaintenanceTicketDetail detail;

  @override
  Widget build(BuildContext context) {
    final isPaid = detail.billingStatus.toUpperCase() == 'PAID';
    final responsibility =
        detail.chargeToTenant || detail.payer.toUpperCase() == 'TENANT'
        ? 'Khách thuê chịu'
        : 'Không thu khách';
    return _SectionCard(
      title: 'Thanh toán phát sinh',
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          _RepairLine(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Trách nhiệm chi phí',
            value: responsibility,
          ),
          const SizedBox(height: 20),
          _RepairLine(
            icon: Icons.payments_outlined,
            label: 'Số tiền',
            value: '${_formatCurrency(detail.chargeAmount ?? 0)}đ',
          ),
          if (detail.invoiceCode.isNotEmpty) ...[
            const SizedBox(height: 20),
            _RepairLine(
              icon: Icons.receipt_long_outlined,
              label: 'Mã hóa đơn',
              value: detail.invoiceCode,
            ),
          ],
          const SizedBox(height: 20),
          _RepairLine(
            icon: isPaid
                ? Icons.check_circle_outline_rounded
                : Icons.schedule_rounded,
            label: 'Trạng thái thanh toán',
            value: detail.billingStatusLabel.isNotEmpty
                ? detail.billingStatusLabel
                : responsibility,
          ),
          if (detail.chargeToTenant && detail.invoiceId != null && !isPaid) ...[
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: AppPrimaryGradientButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => BillSelectionPage(
                      roomId: detail.roomId,
                      roomCode: detail.roomCode,
                    ),
                  ),
                ),
                height: 48,
                child: const Row(
                  children: [
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Xem hóa đơn / Thanh toán ngay',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final TicketReview? review;

  @override
  Widget build(BuildContext context) {
    final data = review;
    if (data == null) {
      return const _SectionCard(
        title: 'Đánh giá từ cư dân',
        icon: Icons.star_outline_rounded,
        child: Text(
          'Khách chưa đánh giá',
          style: TextStyle(
            color: AppColors.bodyText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return _SectionCard(
      title: 'Đánh giá từ cư dân',
      icon: Icons.star_outline_rounded,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RatingStars(rating: data.rating),
                const SizedBox(height: 4),
                Text(
                  '${data.rating.toStringAsFixed(1)} / 5.0',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.comment?.trim().isNotEmpty == true)
                  Text(
                    '"${data.comment!.trim()}"',
                    style: const TextStyle(
                      color: AppColors.inputText,
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      height: 23 / 16,
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  '— ${_formatDate(data.createdAt)}',
                  style: const TextStyle(
                    color: AppColors.bodyText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.role,
    required this.detail,
    required this.isLoading,
    required this.onAccept,
    required this.onReject,
    required this.onSubmitRepairProposal,
    required this.onUpdateProgress,
    required this.onComplete,
    required this.onConfirm,
    required this.onDecideRepair,
    required this.onReview,
  });

  final TicketUserRole role;
  final MaintenanceTicketDetail detail;
  final bool isLoading;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onSubmitRepairProposal;
  final VoidCallback onUpdateProgress;
  final VoidCallback onComplete;
  final VoidCallback onConfirm;
  final void Function(bool approved) onDecideRepair;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];

    if (canAcceptTicket(role, detail.status)) {
      actions.add(_PrimaryActionButton(label: 'Tiếp nhận', onTap: onAccept));
    }
    if (canRejectTicket(role, detail.status)) {
      actions.add(_SecondaryActionButton(label: 'Từ chối', onTap: onReject));
    }
    if (canSubmitRepairProposal(role, detail.status)) {
      actions.add(
        _PrimaryActionButton(
          label: 'Lập phương án sửa chữa',
          onTap: onSubmitRepairProposal,
        ),
      );
    }
    if (canDecideRepair(role, detail.status)) {
      actions.add(
        _PrimaryActionButton(
          label: 'Đồng ý sửa chữa',
          onTap: () => onDecideRepair(true),
        ),
      );
      actions.add(
        _SecondaryActionButton(
          label: 'Không đồng ý sửa',
          onTap: () => onDecideRepair(false),
        ),
      );
    }
    if (canCompleteTicket(role, detail.status)) {
      actions.add(
        _PrimaryActionButton(label: 'Đánh dấu hoàn tất', onTap: onComplete),
      );
    }
    if (canUpdateProgress(role, detail.status)) {
      actions.add(
        _SecondaryActionButton(
          label: 'Cập nhật tiến độ',
          onTap: onUpdateProgress,
        ),
      );
    }
    if (role.canManage && detail.status == TicketStatus.waitingConfirmation) {
      actions.add(const _ActionNote(text: 'Đang chờ khách xác nhận'));
    }
    if (canConfirmTicket(role, detail.status)) {
      actions.add(
        _PrimaryActionButton(label: 'Xác nhận hoàn tất', onTap: onConfirm),
      );
    }
    if (canReviewTicket(
      role,
      detail.status,
      hasReview: detail.review != null,
    )) {
      actions.add(_PrimaryActionButton(label: 'Đánh giá', onTap: onReview));
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return _SectionCard(
      title: '',
      icon: null,
      child: AbsorbPointer(
        absorbing: isLoading,
        child: Opacity(
          opacity: isLoading ? 0.65 : 1,
          child: Column(
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                actions[index],
                if (index < actions.length - 1) const SizedBox(height: 10),
              ],
              if (isLoading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(color: AppColors.deepBlue),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.icon,
    this.headerTrailing,
    this.titleSubtitle,
  });

  final String title;
  final IconData? icon;
  final String? titleSubtitle;
  final Widget? headerTrailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasHeader = title.isNotEmpty || headerTrailing != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasHeader)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: AppColors.deepBlue, size: 20),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title.isNotEmpty)
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.darkBlue,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 20 / 14,
                          ),
                        ),
                      if (titleSubtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          titleSubtitle!,
                          style: const TextStyle(
                            color: AppColors.bodyText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 16 / 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (headerTrailing != null) ...[
                  const SizedBox(width: 12),
                  Flexible(child: headerTrailing!),
                ],
              ],
            ),
          if (hasHeader) const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.bodyText,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 20 / 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value.trim().isEmpty ? 'Chưa cập nhật' : value.trim(),
          style: const TextStyle(
            color: AppColors.inputText,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 24 / 16,
          ),
        ),
      ],
    );
  }
}

class _RepairLine extends StatelessWidget {
  const _RepairLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFECEBED),
          ),
          child: Icon(icon, color: AppColors.deepBlue, size: 23),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.bodyText,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 20 / 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.deepBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 21 / 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AppPrimaryGradientButton(
        onPressed: onTap,
        height: 52,
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.primaryLight.withValues(alpha: 0.72),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.24)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _ActionNote extends StatelessWidget {
  const _ActionNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.bodyText,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 1; index <= 5; index++)
          Icon(
            index <= rating.round()
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            color: const Color(0xFFEAB308),
            size: 20,
          ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.deepBlue),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.deepBlue,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.inputText,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            AppPrimaryGradientButton(
              onPressed: onRetry,
              height: 44,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 7),
                  Text('Thử lại'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepairProposalSheet extends StatefulWidget {
  const _RepairProposalSheet();

  @override
  State<_RepairProposalSheet> createState() => _RepairProposalSheetState();
}

class _RepairProposalSheetState extends State<_RepairProposalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _workerController = TextEditingController();
  final _phoneController = TextEditingController();
  final _itemsController = TextEditingController();
  final _amountController = TextEditingController();
  final _rootCauseController = TextEditingController();
  String _costResponsibility = 'OWNER';

  @override
  void dispose() {
    _workerController.dispose();
    _phoneController.dispose();
    _itemsController.dispose();
    _amountController.dispose();
    _rootCauseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheetFrame(
      title: 'Lập phương án sửa chữa',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _SheetTextField(
              label: 'Người sửa/thợ *',
              controller: _workerController,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập người sửa.'
                  : null,
            ),
            const SizedBox(height: 12),
            _SheetTextField(
              label: 'Số điện thoại người sửa',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _SheetTextField(
              label: 'Hạng mục dự kiến sửa *',
              controller: _itemsController,
              minLines: 2,
              maxLines: 4,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập hạng mục dự kiến.'
                  : null,
            ),
            const SizedBox(height: 12),
            _SheetTextField(
              label: 'Chi phí dự kiến (VNĐ) *',
              controller: _amountController,
              keyboardType: TextInputType.number,
              validator: (value) {
                final amount = num.tryParse(value?.trim() ?? '');
                return amount == null || amount < 0
                    ? 'Chi phí không hợp lệ.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _costResponsibility,
              decoration: InputDecoration(
                labelText: 'Người chịu chi phí',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'OWNER', child: Text('Chủ trọ chịu')),
                DropdownMenuItem(
                  value: 'TENANT',
                  child: Text('Khách thuê chịu'),
                ),
                DropdownMenuItem(
                  value: 'OPERATION',
                  child: Text('Chi phí vận hành'),
                ),
              ],
              onChanged: (value) => setState(() {
                _costResponsibility = value ?? 'OWNER';
              }),
            ),
            const SizedBox(height: 12),
            _SheetTextField(
              label: 'Nguyên nhân (nếu có)',
              controller: _rootCauseController,
              minLines: 2,
              maxLines: 3,
            ),
            const SizedBox(height: 18),
            _SheetSubmitButton(
              label: 'Gửi phương án cho khách',
              onPressed: () {
                if (_formKey.currentState?.validate() != true) {
                  return;
                }
                Navigator.of(context).pop(
                  _RepairProposalFormData(
                    workerName: _workerController.text,
                    repairmanPhone: _phoneController.text,
                    repairItems: _itemsController.text,
                    amount: num.parse(_amountController.text.trim()),
                    rootCause: _rootCauseController.text,
                    costResponsibility: _costResponsibility,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressSheet extends StatefulWidget {
  const _ProgressSheet();

  @override
  State<_ProgressSheet> createState() => _ProgressSheetState();
}

class _ProgressSheetState extends State<_ProgressSheet> {
  final _formKey = GlobalKey<FormState>();
  final _workerController = TextEditingController();
  final _itemsController = TextEditingController();
  final _dateController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _workerController.dispose();
    _itemsController.dispose();
    _dateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheetFrame(
      title: 'Cập nhật tiến độ',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _SheetTextField(
              label: 'Người xử lý/thợ',
              controller: _workerController,
            ),
            const SizedBox(height: 12),
            _SheetTextField(
              label: 'Hạng mục sửa chữa',
              controller: _itemsController,
            ),
            const SizedBox(height: 12),
            _SheetTextField(
              label: 'Ngày dự kiến hoàn tất (YYYY-MM-DD)',
              controller: _dateController,
              keyboardType: TextInputType.datetime,
            ),
            const SizedBox(height: 12),
            _SheetTextField(
              label: 'Ghi chú tiến độ',
              controller: _noteController,
              minLines: 3,
              maxLines: 4,
            ),
            const SizedBox(height: 18),
            _SheetSubmitButton(
              label: 'Lưu cập nhật',
              onPressed: () {
                if (_formKey.currentState?.validate() != true) {
                  return;
                }
                Navigator.of(context).pop(
                  _ProgressFormData(
                    workerName: _workerController.text,
                    repairItems: _itemsController.text,
                    expectedCompletionDate: DateTime.tryParse(
                      _dateController.text.trim(),
                    ),
                    note: _noteController.text,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedRepairSummary extends StatelessWidget {
  const _SavedRepairSummary({required this.detail});

  final MaintenanceTicketDetail? detail;

  @override
  Widget build(BuildContext context) {
    final repair = detail?.repairInfo;
    final amount = repair?.totalCost;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông tin sửa chữa đã lưu',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text('Người sửa: ${_fallback(repair?.workerName)}'),
          Text('Hạng mục: ${_fallback(repair?.repairItems)}'),
          Text(
            'Chi phí: ${amount == null ? _fallback(null) : _formatCurrency(amount)}',
          ),
          Text(
            'Trách nhiệm: ${maintenanceCostResponsibilityLabel(repair?.costResponsibility)}',
          ),
        ],
      ),
    );
  }
}

class _CompleteSheet extends StatefulWidget {
  const _CompleteSheet({required this.imagePicker, this.detail});

  final ImagePicker imagePicker;
  final MaintenanceTicketDetail? detail;

  @override
  State<_CompleteSheet> createState() => _CompleteSheetState();
}

class _CompleteSheetState extends State<_CompleteSheet> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _workerController = TextEditingController();
  final _repairmanPhoneController = TextEditingController();
  final _repairItemsController = TextEditingController();
  final _rootCauseController = TextEditingController();
  final _costDescriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _paidByController = TextEditingController();
  bool _editRepairDetails = false;
  List<MaintenanceAttachment> _selectedFiles = const [];

  @override
  void initState() {
    super.initState();
    final repair = widget.detail?.repairInfo;
    _workerController.text = repair?.workerName ?? '';
    _repairmanPhoneController.text = repair?.repairmanPhone ?? '';
    _repairItemsController.text = repair?.repairItems ?? '';
    _rootCauseController.text = repair?.rootCause ?? '';
    _costDescriptionController.text =
        repair?.costCategory ?? repair?.repairItems ?? '';
    if (repair?.totalCost != null) {
      _amountController.text = repair!.totalCost!.toString();
    }
    _paidByController.text =
        repair?.costResponsibility ?? widget.detail?.payer ?? '';
  }

  @override
  void dispose() {
    _noteController.dispose();
    _workerController.dispose();
    _repairmanPhoneController.dispose();
    _repairItemsController.dispose();
    _rootCauseController.dispose();
    _costDescriptionController.dispose();
    _amountController.dispose();
    _paidByController.dispose();
    super.dispose();
  }

  Future<void> _pickAfterFiles() async {
    final files = await widget.imagePicker.pickMultiImage(imageQuality: 82);
    if (!mounted || files.isEmpty) {
      return;
    }
    final selected = <MaintenanceAttachment>[];
    for (final file in files.take(3)) {
      final bytes = await file.readAsBytes();
      selected.add(
        MaintenanceAttachment(
          name: file.name,
          path: file.path,
          mimeType: _imageMimeType(file.name),
          sizeBytes: bytes.length,
          type: MaintenanceAttachmentType.image,
          previewBytes: bytes,
        ),
      );
    }
    if (mounted) {
      setState(() {
        _selectedFiles = List.unmodifiable(selected);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheetFrame(
      title: 'Đánh dấu hoàn tất',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _SheetTextField(
              label: 'Ghi chú hoàn tất',
              controller: _noteController,
              minLines: 3,
              maxLines: 4,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập ghi chú hoàn tất'
                  : null,
            ),
            const SizedBox(height: 12),
            if (!_editRepairDetails) ...[
              _SavedRepairSummary(detail: widget.detail),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => setState(() => _editRepairDetails = true),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Chỉnh sửa thông tin thực tế'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: AppColors.deepBlue,
                  side: const BorderSide(color: AppColors.deepBlue),
                ),
              ),
            ] else ...[
              _SheetTextField(
                label: 'Người sửa/thợ',
                controller: _workerController,
              ),
              const SizedBox(height: 12),
              _SheetTextField(
                label: 'Số điện thoại người sửa',
                controller: _repairmanPhoneController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _SheetTextField(
                label: 'Hạng mục đã sửa',
                controller: _repairItemsController,
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              _SheetTextField(
                label: 'Nguyên nhân',
                controller: _rootCauseController,
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _SheetTextField(
                label: 'Hạng mục chi phí',
                controller: _costDescriptionController,
              ),
              const SizedBox(height: 12),
              _SheetTextField(
                label: 'Số tiền',
                controller: _amountController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _SheetTextField(
                label: 'Người thanh toán',
                controller: _paidByController,
              ),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _pickAfterFiles,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.deepBlue,
                side: const BorderSide(color: AppColors.deepBlue),
                minimumSize: const Size.fromHeight(44),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
              ),
              label: Text(
                _selectedFiles.isEmpty
                    ? 'Thêm ảnh sau sửa chữa'
                    : 'Đã chọn ${_selectedFiles.length} ảnh',
              ),
            ),
            const SizedBox(height: 18),
            _SheetSubmitButton(
              label: 'Hoàn tất',
              onPressed: () {
                if (_formKey.currentState?.validate() != true) {
                  return;
                }
                Navigator.of(context).pop(
                  _CompleteFormData(
                    completionNote: _noteController.text,
                    workerName: _editRepairDetails
                        ? _workerController.text
                        : null,
                    repairmanPhone: _editRepairDetails
                        ? _repairmanPhoneController.text
                        : null,
                    repairItems: _editRepairDetails
                        ? _repairItemsController.text
                        : null,
                    rootCause: _editRepairDetails
                        ? _rootCauseController.text
                        : null,
                    costDescription: _editRepairDetails
                        ? _costDescriptionController.text
                        : null,
                    amount: _editRepairDetails
                        ? num.tryParse(_amountController.text.trim())
                        : null,
                    paidBy: _editRepairDetails ? _paidByController.text : null,
                    afterAttachments: _selectedFiles,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _imageMimeType(String fileName) {
  final extension = fileName.split('.').last.toLowerCase();
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => 'image/jpeg',
  };
}

class _BottomSheetFrame extends StatelessWidget {
  const _BottomSheetFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.sectionTitle),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  const _SheetTextField({
    required this.label,
    required this.controller,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: AppColors.inputText,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: const TextStyle(
          color: AppColors.bodyText,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: AppColors.deepBlue,
          fontWeight: FontWeight.w800,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          borderSide: const BorderSide(color: AppColors.deepBlue, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }
}

class _SheetSubmitButton extends StatelessWidget {
  const _SheetSubmitButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AppPrimaryGradientButton(
        onPressed: onPressed,
        height: 50,
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _ProgressFormData {
  const _ProgressFormData({
    required this.workerName,
    required this.repairItems,
    required this.expectedCompletionDate,
    required this.note,
  });

  final String workerName;
  final String repairItems;
  final DateTime? expectedCompletionDate;
  final String note;
}

class _RepairProposalFormData {
  const _RepairProposalFormData({
    required this.workerName,
    required this.repairmanPhone,
    required this.repairItems,
    required this.amount,
    required this.rootCause,
    required this.costResponsibility,
  });

  final String workerName;
  final String repairmanPhone;
  final String repairItems;
  final num amount;
  final String rootCause;
  final String costResponsibility;
}

class _CompleteFormData {
  const _CompleteFormData({
    required this.completionNote,
    this.workerName,
    this.repairmanPhone,
    this.repairItems,
    this.rootCause,
    this.costDescription,
    this.amount,
    this.paidBy,
    required this.afterAttachments,
  });

  final String completionNote;
  final String? workerName;
  final String? repairmanPhone;
  final String? repairItems;
  final String? rootCause;
  final String? costDescription;
  final num? amount;
  final String? paidBy;
  final List<MaintenanceAttachment> afterAttachments;
}

bool _shouldShowAfterAttachments(MaintenanceTicketDetail detail) {
  return detail.afterAttachments.isNotEmpty ||
      detail.status == TicketStatus.inProgress ||
      detail.status == TicketStatus.waitingConfirmation ||
      detail.status == TicketStatus.completed;
}

bool _shouldShowRepairInfo(MaintenanceTicketDetail detail) {
  return detail.hasRepairData ||
      detail.status == TicketStatus.waitingTenantDecision ||
      detail.status == TicketStatus.inProgress ||
      detail.status == TicketStatus.waitingConfirmation ||
      detail.status == TicketStatus.completed;
}

String _repairCardTitle(TicketStatus status) {
  return switch (status) {
    TicketStatus.accepted ||
    TicketStatus.waitingTenantDecision => 'Phương án sửa chữa',
    TicketStatus.inProgress => 'Thông tin sửa chữa',
    TicketStatus.waitingConfirmation ||
    TicketStatus.completed => 'Kết quả xử lý',
    TicketStatus.pending ||
    TicketStatus.rejected ||
    TicketStatus.cancelled => 'Thông tin sửa chữa',
  };
}

String _repairItemsLabel(TicketStatus status) {
  return switch (status) {
    TicketStatus.accepted ||
    TicketStatus.waitingTenantDecision => 'Hạng mục dự kiến sửa',
    TicketStatus.inProgress => 'Hạng mục sửa chữa',
    TicketStatus.waitingConfirmation ||
    TicketStatus.completed => 'Hạng mục đã sửa',
    TicketStatus.pending ||
    TicketStatus.rejected ||
    TicketStatus.cancelled => 'Hạng mục sửa chữa',
  };
}

String _repairCostLabel(TicketStatus status) {
  return switch (status) {
    TicketStatus.accepted ||
    TicketStatus.waitingTenantDecision => 'Chi phí dự kiến',
    TicketStatus.waitingConfirmation ||
    TicketStatus.completed => 'Chi phí thực tế',
    TicketStatus.pending ||
    TicketStatus.inProgress ||
    TicketStatus.rejected ||
    TicketStatus.cancelled => 'Chi phí',
  };
}

bool _shouldShowBillingInfo(MaintenanceTicketDetail detail) {
  return detail.status != TicketStatus.rejected &&
      detail.billingStatus.isNotEmpty &&
      (detail.status == TicketStatus.waitingTenantDecision ||
          detail.status == TicketStatus.waitingConfirmation ||
          detail.status == TicketStatus.completed);
}

bool _shouldShowReview(MaintenanceTicketDetail detail) {
  return detail.review != null || detail.status == TicketStatus.completed;
}

String _fallback(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? 'Chưa cập nhật' : trimmed;
}

String? _firstNonBlank(String? primary, String? fallback) {
  final primaryText = primary?.trim() ?? '';
  if (primaryText.isNotEmpty) {
    return primary;
  }
  final fallbackText = fallback?.trim() ?? '';
  return fallbackText.isEmpty ? null : fallback;
}

String _formatDateTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}, '
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String _formatCurrency(num amount) {
  final value = amount.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < value.length; index++) {
    final reverseIndex = value.length - index;
    buffer.write(value[index]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write('.');
    }
  }
  return buffer.toString();
}
