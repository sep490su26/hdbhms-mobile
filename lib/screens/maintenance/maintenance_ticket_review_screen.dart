import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/maintenance/maintenance_ticket_model.dart';
import 'package:hdbhms_mobile/services/maintenance/maintenance_ticket_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import '../../widgets/star_rating_input.dart';
import 'package:hdbhms_mobile/widgets/ticket_attachment_grid.dart';
import 'package:hdbhms_mobile/widgets/app_notification_bell.dart';
import 'package:hdbhms_mobile/widgets/app_primary_gradient_button.dart';

class MaintenanceTicketReviewScreen extends StatefulWidget {
  const MaintenanceTicketReviewScreen({
    super.key,
    required this.ticketId,
    this.initialDetail,
    this.ticketService = const MaintenanceTicketService(),
  });

  final int ticketId;
  final MaintenanceTicketDetail? initialDetail;
  final MaintenanceTicketService ticketService;

  @override
  State<MaintenanceTicketReviewScreen> createState() =>
      _MaintenanceTicketReviewScreenState();
}

class _MaintenanceTicketReviewScreenState
    extends State<MaintenanceTicketReviewScreen> {
  final _commentController = TextEditingController();

  MaintenanceTicketDetail? _detail;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  int _rating = 0;
  String? _ratingError;
  String? _commentError;

  @override
  void initState() {
    super.initState();
    _detail = widget.initialDetail;
    _loadDetail();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = _detail == null;
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

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final comment = _commentController.text.trim();
    var isValid = true;
    setState(() {
      _ratingError = null;
      _commentError = null;
      if (_rating == 0) {
        _ratingError = 'Vui lòng chọn số sao đánh giá';
        isValid = false;
      }
      if (comment.length > 500) {
        _commentError = 'Nhận xét tối đa 500 ký tự';
        isValid = false;
      }
    });

    if (!isValid) {
      return;
    }

    final detail = _detail;
    if (detail == null) {
      _showSnackBar('Không thể gửi xác nhận. Vui lòng thử lại.');
      return;
    }

    if (detail.afterAttachments.isEmpty) {
      final confirmed = await _showMissingAfterPhotoDialog();
      if (confirmed != true) {
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (detail.status == TicketStatus.waitingConfirmation) {
        await widget.ticketService.confirmTicket(
          widget.ticketId,
          satisfactionNote: comment.isEmpty
              ? 'Khách thuê xác nhận hoàn tất'
              : comment,
        );
      }
      await widget.ticketService.reviewTicket(
        widget.ticketId,
        rating: _rating.toDouble(),
        comment: comment,
      );
      if (!mounted) {
        return;
      }
      await _showSuccessDialog();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Không thể gửi xác nhận. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<bool?> _showMissingAfterPhotoDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Chưa có ảnh sau sửa'),
          content: const Text(
            'Quản lý chưa tải lên ảnh sau sửa, bạn có chắc muốn xác nhận?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            AppPrimaryGradientButton(
              onPressed: () => Navigator.of(context).pop(true),
              height: 40,
              borderRadius: 12,
              child: const Text('Vẫn xác nhận'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Thành công'),
          content: const Text('Đã xác nhận hoàn tất và gửi đánh giá'),
          actions: [
            AppPrimaryGradientButton(
              onPressed: () => Navigator.of(context).pop(),
              height: 40,
              borderRadius: 12,
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
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
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Trở về',
        ),
        title: const Text(
          'Xác nhận & Đánh giá',
          style: AppColors.topBarTitleStyle,
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const AppNotificationBell(
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
                : SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _WorkDetailCard(detail: detail),
                        const SizedBox(height: 16),
                        _ReviewFormCard(
                          rating: _rating,
                          ratingError: _ratingError,
                          commentController: _commentController,
                          commentError: _commentError,
                          isSubmitting: _isSubmitting,
                          onRatingChanged: (value) {
                            setState(() {
                              _rating = value;
                              _ratingError = null;
                            });
                          },
                          onSubmit: _submit,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _WorkDetailCard extends StatelessWidget {
  const _WorkDetailCard({required this.detail});

  final MaintenanceTicketDetail detail;

  @override
  Widget build(BuildContext context) {
    final repair = detail.repairInfo;
    final completedAt = repair?.completedAt ?? _completedEventDate(detail);

    return _SectionCard(
      title: 'Chi tiết công việc',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryBox(
                  label: 'Ngày hoàn thành',
                  value: completedAt == null
                      ? 'Chưa cập nhật'
                      : _formatDate(completedAt),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryBox(
                  label: 'Loại dịch vụ',
                  value: _fallback(
                    repair?.repairItems ?? repair?.costCategory ?? detail.title,
                  ),
                ),
              ),
            ],
          ),
          if (repair != null) ...[
            const SizedBox(height: 18),
            _DetailLine(label: 'Tên thợ', value: _fallback(repair.workerName)),
            const SizedBox(height: 12),
            _DetailLine(
              label: 'Hạng mục sửa',
              value: _fallback(repair.repairItems ?? repair.costCategory),
            ),
            const SizedBox(height: 12),
            _DetailLine(
              label: 'Chi phí thực tế',
              value: repair.totalCost == null
                  ? 'Chưa cập nhật'
                  : '${_formatCurrency(repair.totalCost!)} VND',
            ),
            const SizedBox(height: 12),
            _DetailLine(
              label: 'Ghi chú hoàn tất',
              value: _fallback(repair.completionNote),
            ),
          ],
          const SizedBox(height: 18),
          if (detail.afterAttachments.isEmpty)
            const _MissingAfterPhotoWarning()
          else
            TicketAttachmentGrid(
              attachments: detail.afterAttachments,
              emptyText: 'Quản lý chưa tải lên ảnh sau sửa',
            ),
        ],
      ),
    );
  }
}

class _ReviewFormCard extends StatelessWidget {
  const _ReviewFormCard({
    required this.rating,
    required this.ratingError,
    required this.commentController,
    required this.commentError,
    required this.isSubmitting,
    required this.onRatingChanged,
    required this.onSubmit,
  });

  final int rating;
  final String? ratingError;
  final TextEditingController commentController;
  final String? commentError;
  final bool isSubmitting;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Đánh giá sự hài lòng',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chọn mức độ hài lòng (Bắt buộc)',
            style: TextStyle(
              color: AppColors.bodyText,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 17 / 13,
            ),
          ),
          const SizedBox(height: 12),
          StarRatingInput(
            value: rating,
            onChanged: onRatingChanged,
            errorText: ratingError,
          ),
          const SizedBox(height: 24),
          const Text(
            'Nhận xét bổ sung (Tùy chọn)',
            style: TextStyle(
              color: AppColors.bodyText,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 17 / 13,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: commentController,
            enabled: !isSubmitting,
            minLines: 5,
            maxLines: 7,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Chia sẻ thêm về trải nghiệm của bạn...',
              errorText: commentError,
              filled: true,
              fillColor: const Color(0xFFF3F3F5),
              counterText: '',
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
                borderSide: const BorderSide(color: AppColors.deepBlue),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: AppPrimaryGradientButton(
              onPressed: isSubmitting ? null : onSubmit,
              height: 56,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSubmitting)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.2,
                      ),
                    )
                  else
                    const Icon(
                      Icons.send_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    isSubmitting ? 'Đang gửi...' : 'Gửi xác nhận & Đánh giá',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      height: 19 / 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text.rich(
              TextSpan(
                text:
                    'Bằng việc nhấn gửi, Ticket sẽ được chuyển\nsang trạng thái ',
                children: [
                  TextSpan(
                    text: 'Hoàn tất.',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      color: AppColors.deepBlue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                color: AppColors.bodyText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 18 / 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: const Color(0xFFE9E7EA)),
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
          Text(title, style: AppTypography.sectionTitle),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE3E1E5)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F1F2),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.bodyText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 16 / 12,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.inputText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 21 / 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.bodyText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 18 / 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.inputText,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 19 / 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _MissingAfterPhotoWarning extends StatelessWidget {
  const _MissingAfterPhotoWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3D6),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: const Color(0xFFF4C76B)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 20),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Quản lý chưa tải lên ảnh sau sửa',
              style: TextStyle(
                color: AppColors.warningText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 18 / 13,
              ),
            ),
          ),
        ],
      ),
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

DateTime? _completedEventDate(MaintenanceTicketDetail detail) {
  for (final event in detail.events.reversed) {
    if (TicketStatus.fromBackend(event.status) == TicketStatus.completed ||
        TicketStatus.fromBackend(event.status) ==
            TicketStatus.waitingConfirmation) {
      return event.createdAt;
    }
  }
  return null;
}

String _fallback(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? 'Chưa cập nhật' : trimmed;
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
