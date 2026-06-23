import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:hdbhms_mobile/models/maintenance/maintenance_ticket_model.dart';
import 'package:hdbhms_mobile/services/maintenance/maintenance_ticket_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/widgets/ticket_attachment_grid.dart';
import 'package:hdbhms_mobile/widgets/ticket_status_badge.dart';
import 'package:hdbhms_mobile/widgets/ticket_timeline.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_review_screen.dart';

class MaintenanceTicketDetailScreen extends StatefulWidget {
  const MaintenanceTicketDetailScreen({
    super.key,
    required this.ticketId,
    this.ticket,
    this.role = TicketUserRole.tenant,
    this.ticketService = const MaintenanceTicketService(),
    this.imagePicker,
  });

  final int ticketId;
  final MaintenanceTicketModel? ticket;
  final TicketUserRole role;
  final MaintenanceTicketService ticketService;
  final ImagePicker? imagePicker;

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

  Future<void> _completeTicket() async {
    final data = await showModalBottomSheet<_CompleteFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _CompleteSheet(imagePicker: _imagePicker),
    );
    if (data == null) {
      return;
    }
    await _runAction(
      () => widget.ticketService.completeTicket(
        widget.ticketId,
        completionNote: data.completionNote,
        costDescription: data.costDescription,
        amount: data.amount,
        paidBy: data.paidBy,
      ),
      'Đã đánh dấu hoàn tất',
    );
  }

  Future<void> _confirmTicket() async {
    await _openReviewScreen();
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
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _showRejectDialog() {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Từ chối phiếu'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              minLines: 3,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Lý do từ chối',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập lý do từ chối'
                  : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) {
                  return;
                }
                Navigator.of(context).pop(controller.text.trim());
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Từ chối'),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
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
        foregroundColor: AppColors.deepBlue,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Trở về',
        ),
        title: const Text('Chi tiết sự cố', style: AppColors.topBarTitleStyle),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.topBarIconColor,
              size: AppColors.topBarIconSize,
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
                          _TicketInfoCard(detail: detail),
                          const SizedBox(height: 18),
                          _SectionCard(
                            title: 'Ảnh đính kèm',
                            child: TicketAttachmentGrid(
                              attachments: detail.beforeAttachments,
                              emptyText: 'Không có file đính kèm',
                              onAttachmentError: () =>
                                  _showSnackBar('Không tải được file đính kèm'),
                            ),
                          ),
                          if (_shouldShowAfterAttachments(detail)) ...[
                            const SizedBox(height: 18),
                            _SectionCard(
                              title: 'Ảnh sau sửa chữa',
                              child: TicketAttachmentGrid(
                                attachments: detail.afterAttachments,
                                emptyText: 'Chưa có ảnh sau sửa chữa',
                                onAttachmentError: () => _showSnackBar(
                                  'Không tải được file đính kèm',
                                ),
                              ),
                            ),
                          ],
                          if (_shouldShowRepairInfo(detail)) ...[
                            const SizedBox(height: 18),
                            _RepairInfoCard(detail: detail),
                          ],
                          if (_shouldShowReview(detail)) ...[
                            const SizedBox(height: 18),
                            _ReviewCard(review: detail.review),
                          ],
                          const SizedBox(height: 18),
                          _SectionCard(
                            title: 'Tiến trình xử lý',
                            child: TicketTimeline(
                              events: detail.events,
                              currentStatus: detail.status,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _ActionPanel(
                            role: widget.role,
                            detail: detail,
                            isLoading: _isActionLoading,
                            onAccept: _acceptTicket,
                            onReject: _rejectTicket,
                            onUpdateProgress: _updateProgress,
                            onComplete: _completeTicket,
                            onConfirm: _confirmTicket,
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

class _TicketInfoCard extends StatelessWidget {
  const _TicketInfoCard({required this.detail});

  final MaintenanceTicketDetail detail;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Thông tin sự cố',
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
    return _SectionCard(
      title: 'Thông tin xử lý thực tế',
      child: Column(
        children: [
          _RepairLine(
            icon: Icons.payments_outlined,
            label: 'Chi phí thực tế',
            value: repair?.totalCost == null
                ? 'Chưa cập nhật'
                : '${_formatCurrency(repair!.totalCost!)} VND',
          ),
          const SizedBox(height: 20),
          _RepairLine(
            icon: Icons.fact_check_outlined,
            label: 'Hạng mục',
            value: _fallback(repair?.repairItems ?? repair?.costCategory),
          ),
          const SizedBox(height: 20),
          _RepairLine(
            icon: Icons.engineering_outlined,
            label: 'Người xử lý',
            value: _fallback(repair?.workerName),
          ),
          if (repair?.completionNote?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 20),
            _RepairLine(
              icon: Icons.notes_rounded,
              label: 'Ghi chú hoàn tất',
              value: repair!.completionNote!.trim(),
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
    required this.onUpdateProgress,
    required this.onComplete,
    required this.onConfirm,
    required this.onReview,
  });

  final TicketUserRole role;
  final MaintenanceTicketDetail detail;
  final bool isLoading;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onUpdateProgress;
  final VoidCallback onComplete;
  final VoidCallback onConfirm;
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
    this.headerTrailing,
    this.titleSubtitle,
  });

  final String title;
  final String? titleSubtitle;
  final Widget? headerTrailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasHeader = title.isNotEmpty || headerTrailing != null;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title.isNotEmpty)
                          Text(title, style: AppTypography.sectionTitle),
                        if (titleSubtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            titleSubtitle!,
                            style: AppTypography.sectionTitle,
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
            ),
          if (hasHeader) const Divider(height: 1, color: Color(0xFFE3E1E5)),
          Padding(
            padding: EdgeInsets.fromLTRB(24, hasHeader ? 24 : 20, 24, 24),
            child: child,
          ),
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
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.deepBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
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
          foregroundColor: AppColors.deepBlue,
          side: const BorderSide(color: AppColors.deepBlue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
              ),
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

class _CompleteSheet extends StatefulWidget {
  const _CompleteSheet({required this.imagePicker});

  final ImagePicker imagePicker;

  @override
  State<_CompleteSheet> createState() => _CompleteSheetState();
}

class _CompleteSheetState extends State<_CompleteSheet> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _costDescriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _paidByController = TextEditingController();
  int _selectedFileCount = 0;

  @override
  void dispose() {
    _noteController.dispose();
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
    setState(() {
      _selectedFileCount = files.length > 3 ? 3 : files.length;
    });
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
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _pickAfterFiles,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _selectedFileCount == 0
                    ? 'Thêm ảnh sau sửa chữa'
                    : 'Đã chọn $_selectedFileCount ảnh',
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
                    costDescription: _costDescriptionController.text,
                    amount: num.tryParse(_amountController.text.trim()) ?? 0,
                    paidBy: _paidByController.text,
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
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
      height: 50,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.deepBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
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

class _CompleteFormData {
  const _CompleteFormData({
    required this.completionNote,
    required this.costDescription,
    required this.amount,
    required this.paidBy,
  });

  final String completionNote;
  final String costDescription;
  final num amount;
  final String paidBy;
}

bool _shouldShowAfterAttachments(MaintenanceTicketDetail detail) {
  return detail.afterAttachments.isNotEmpty ||
      detail.status == TicketStatus.inProgress ||
      detail.status == TicketStatus.waitingConfirmation ||
      detail.status == TicketStatus.completed;
}

bool _shouldShowRepairInfo(MaintenanceTicketDetail detail) {
  return detail.hasRepairData ||
      detail.status == TicketStatus.accepted ||
      detail.status == TicketStatus.inProgress ||
      detail.status == TicketStatus.waitingConfirmation ||
      detail.status == TicketStatus.completed;
}

bool _shouldShowReview(MaintenanceTicketDetail detail) {
  return detail.review != null || detail.status == TicketStatus.completed;
}

String _fallback(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? 'Chưa cập nhật' : trimmed;
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
