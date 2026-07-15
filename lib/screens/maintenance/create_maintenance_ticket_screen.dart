import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hdbhms_mobile/screens/notification/notification_list_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_request_screen.dart';

import 'package:hdbhms_mobile/models/maintenance/maintenance_ticket_model.dart';
import 'package:hdbhms_mobile/services/home/current_room_service.dart';
import 'package:hdbhms_mobile/services/maintenance/maintenance_ticket_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_notification_bell.dart';
import 'package:hdbhms_mobile/widgets/tenant_bottom_navigation.dart';
import 'package:hdbhms_mobile/screens/payment/bill_selection_page.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_list_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_profile_screen.dart';

class CreateMaintenanceTicketScreen extends StatefulWidget {
  const CreateMaintenanceTicketScreen({
    super.key,
    this.ticketService = const MaintenanceTicketService(),
    this.currentRoomService = const CurrentRoomService(),
    this.imagePicker,
  });

  final MaintenanceTicketService ticketService;
  final CurrentRoomService currentRoomService;
  final ImagePicker? imagePicker;

  @override
  State<CreateMaintenanceTicketScreen> createState() =>
      _CreateMaintenanceTicketScreenState();
}

class _CreateMaintenanceTicketScreenState
    extends State<CreateMaintenanceTicketScreen> {
  static const _maxAttachments = 3;
  static const _maxImageBytes = 5 * 1024 * 1024;
  static const _maxVideoBytes = 20 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;

  TicketCategory? _selectedCategory;
  CurrentRentedRoom? _currentRoom;
  String? _attachmentError;
  bool _isSubmitting = false;
  final List<MaintenanceAttachment> _attachments = [];

  ImagePicker get _imagePicker => widget.imagePicker ?? ImagePicker();

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _loadCurrentRoom();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentRoom() async {
    try {
      final room = await widget.currentRoomService.getCurrentRentedRoom();
      if (!mounted) {
        return;
      }
      setState(() {
        _currentRoom = room;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Không tìm thấy phòng đang thuê');
    }
  }

  Future<void> _pickAttachment() async {
    if (_attachments.length >= _maxAttachments) {
      setState(() {
        _attachmentError = 'Chỉ được đính kèm tối đa 3 ảnh/video';
      });
      return;
    }

    final source = await showModalBottomSheet<_AttachmentSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.image_outlined,
                    color: AppColors.deepBlue,
                  ),
                  title: const Text('Chọn ảnh'),
                  onTap: () =>
                      Navigator.of(context).pop(_AttachmentSource.image),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.videocam_outlined,
                    color: AppColors.deepBlue,
                  ),
                  title: const Text('Chọn video'),
                  onTap: () =>
                      Navigator.of(context).pop(_AttachmentSource.video),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    if (source == _AttachmentSource.image) {
      final files = await _imagePicker.pickMultiImage(imageQuality: 82);
      if (files.isEmpty) {
        return;
      }
      await _addPickedFiles(files, MaintenanceAttachmentType.image);
      return;
    }

    final file = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (file == null) {
      return;
    }
    await _addPickedFiles([file], MaintenanceAttachmentType.video);
  }

  Future<void> _addPickedFiles(
    List<XFile> files,
    MaintenanceAttachmentType fallbackType,
  ) async {
    final remainingSlots = _maxAttachments - _attachments.length;
    if (files.length > remainingSlots) {
      setState(() {
        _attachmentError = 'Chỉ được đính kèm tối đa 3 ảnh/video';
      });
      return;
    }

    final added = <MaintenanceAttachment>[];
    for (final file in files) {
      final attachment = await _buildAttachment(file, fallbackType);
      if (attachment == null) {
        setState(() {
          _attachmentError = 'File không hợp lệ';
        });
        return;
      }
      added.add(attachment);
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _attachmentError = null;
      _attachments.addAll(added);
    });
  }

  Future<MaintenanceAttachment?> _buildAttachment(
    XFile file,
    MaintenanceAttachmentType fallbackType,
  ) async {
    final mimeType = _resolveMimeType(file, fallbackType);
    final type = _attachmentTypeFromMime(mimeType);
    if (type == null) {
      return null;
    }

    final sizeBytes = await file.length();
    final maxBytes = type == MaintenanceAttachmentType.image
        ? _maxImageBytes
        : _maxVideoBytes;
    if (sizeBytes > maxBytes) {
      return null;
    }

    Uint8List? previewBytes;
    if (type == MaintenanceAttachmentType.image) {
      previewBytes = await file.readAsBytes();
    }

    return MaintenanceAttachment(
      name: file.name,
      path: file.path,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      type: type,
      previewBytes: previewBytes,
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }
    final room = _currentRoom;
    if (room == null) {
      _showSnackBar('Không tìm thấy phòng đang thuê');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final ticket = await widget.ticketService.createTicket(
        CreateMaintenanceTicketRequest(
          roomId: room.id,
          category: _selectedCategory!,
          title: _generateTitle(
            _selectedCategory!,
            _descriptionController.text,
          ),
          description: _descriptionController.text.trim(),
          attachments: List.unmodifiable(_attachments),
        ),
      );
      if (!mounted) {
        return;
      }
      await _showSuccessDialog(ticket);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Gửi yêu cầu thất bại, vui lòng thử lại');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _showSuccessDialog(MaintenanceTicketModel ticket) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Gửi yêu cầu thành công'),
          content: Text(
            'Mã phiếu của bạn là ${ticket.code}. Quản lý sẽ tiếp nhận và phản hồi trong vòng 24 giờ.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(this.context).pop(true);
              },
              child: const Text('Xem phiếu'),
            ),
          ],
        );
      },
    );
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
      _attachmentError = null;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildHeader() {
    return Container(
      height: AppColors.topBarHeight,
      padding: const EdgeInsets.fromLTRB(4, 0, 15, 0),
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
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.topBarIconColor,
              size: AppColors.topBarIconSize,
            ),
            tooltip: 'Trở về',
          ),
          const Expanded(
            child: Text('Tạo phiếu sự cố', style: AppColors.topBarTitleStyle),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NotificationListScreen(),
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: const AppNotificationBell(
              color: AppColors.topBarIconColor,
              size: AppColors.topBarIconSize,
            ),
            tooltip: 'Thông báo',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(
          header: _buildHeader(),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(14, 18, 14, 26 + bottomInset),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _IntroCard(),
                  const SizedBox(height: 18),
                  const _FieldLabel('Danh mục sự cố'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<TicketCategory>(
                    initialValue: _selectedCategory,
                    items: TicketCategory.values
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            setState(() {
                              _selectedCategory = value;
                            });
                          },
                    validator: (value) =>
                        value == null ? 'Vui lòng chọn loại sự cố' : null,
                    decoration: _inputDecoration(hintText: 'Chọn loại sự cố'),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('Mô tả chi tiết'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descriptionController,
                    enabled: !_isSubmitting,
                    minLines: 5,
                    maxLines: 7,
                    textInputAction: TextInputAction.newline,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Vui lòng mô tả vấn đề'
                        : null,
                    decoration: _inputDecoration(
                      hintText:
                          'Mô tả chi tiết vấn đề (ví dụ: vị trí, âm thanh, mức độ khẩn cấp)...',
                    ),
                  ),
                  const SizedBox(height: 14),
                  _AttachmentHeader(count: _attachments.length),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      for (var index = 0; index < _maxAttachments; index++) ...[
                        Expanded(
                          child: _UploadSlot(
                            attachment: index < _attachments.length
                                ? _attachments[index]
                                : null,
                            enabled: !_isSubmitting,
                            onTap: _pickAttachment,
                            onRemove: index < _attachments.length
                                ? () => _removeAttachment(index)
                                : null,
                          ),
                        ),
                        if (index < _maxAttachments - 1)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  if (_attachmentError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _attachmentError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _isSubmitting ? 'Đang gửi...' : 'GỬI YÊU CẦU',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 18 / 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.58,
                        ),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: TenantBottomNavigation(
        activeTab: TenantBottomNavTab.support,
        onHomeTap: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        onSupportTap: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const MaintenanceTicketListScreen(),
            ),
          );
        },
        onBillsTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const BillSelectionPage()),
          );
        },
        onProfileTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const TenantProfileScreen(),
            ),
          );
        },
        onRequestsTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const TenantRequestScreen()),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEAE8EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yêu cầu bảo trì',
            style: TextStyle(
              color: AppColors.deepBlue,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 20 / 16,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Vui lòng cung cấp chi tiết về vấn đề bạn đang gặp phải. Quản lý sẽ phản hồi trong vòng 24 giờ.',
            style: TextStyle(
              color: AppColors.bodyText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 18 / 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentHeader extends StatelessWidget {
  const _AttachmentHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _FieldLabel('Đính kèm ảnh/video (Tối đa 3 ảnh)')),
        Text(
          '$count/3',
          style: const TextStyle(
            color: AppColors.bodyText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 15 / 11,
          ),
        ),
      ],
    );
  }
}

class _UploadSlot extends StatelessWidget {
  const _UploadSlot({
    required this.attachment,
    required this.enabled,
    required this.onTap,
    required this.onRemove,
  });

  final MaintenanceAttachment? attachment;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.07,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: AppColors.cardBorder,
                radius: 8,
              ),
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: enabled ? onTap : null,
                  child: attachment == null
                      ? const _EmptyUploadContent()
                      : _AttachmentPreview(attachment: attachment!),
                ),
              ),
            ),
          ),
          if (attachment != null && onRemove != null)
            Positioned(
              top: -8,
              right: -7,
              child: Material(
                color: const Color(0xFF111827),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: enabled ? onRemove : null,
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyUploadContent extends StatelessWidget {
  const _EmptyUploadContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo_outlined, color: AppColors.bodyText, size: 22),
        SizedBox(height: 7),
        Text(
          'TẢI LÊN',
          style: TextStyle(
            color: AppColors.bodyText,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            height: 12 / 10,
          ),
        ),
      ],
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.attachment});

  final MaintenanceAttachment attachment;

  @override
  Widget build(BuildContext context) {
    if (attachment.type == MaintenanceAttachmentType.image &&
        attachment.previewBytes != null) {
      return Image.memory(
        Uint8List.fromList(attachment.previewBytes!),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      );
    }

    return Container(
      color: const Color(0xFFE7E9F0),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.play_circle_outline_rounded,
            color: AppColors.deepBlue,
            size: 28,
          ),
          const SizedBox(height: 5),
          Text(
            attachment.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.inputText,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 12 / 10,
            ),
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
        color: AppColors.bodyText,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        height: 16 / 12,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 5;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + 4;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

enum _AttachmentSource { image, video }

InputDecoration _inputDecoration({String? hintText}) {
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: _fieldBorder,
    enabledBorder: _fieldBorder,
    focusedBorder: _fieldBorder.copyWith(
      borderSide: const BorderSide(color: AppColors.deepBlue),
    ),
  );
}

final OutlineInputBorder _fieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(8),
  borderSide: const BorderSide(color: AppColors.cardBorder),
);

String _generateTitle(TicketCategory category, String description) {
  final firstLine = description
      .trim()
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  if (firstLine.isEmpty) {
    return category.label;
  }
  if (firstLine.length <= 60) {
    return firstLine;
  }
  return '${firstLine.substring(0, 57)}...';
}

String _resolveMimeType(XFile file, MaintenanceAttachmentType fallbackType) {
  final explicitMime = file.mimeType;
  if (explicitMime != null && explicitMime.isNotEmpty) {
    return explicitMime;
  }

  final extension = file.name.split('.').last.toLowerCase();
  if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(extension)) {
    return 'image/$extension';
  }
  if (['mp4', 'mov', 'm4v', 'avi', 'webm'].contains(extension)) {
    return 'video/$extension';
  }
  return fallbackType == MaintenanceAttachmentType.image
      ? 'image/unknown'
      : 'video/unknown';
}

MaintenanceAttachmentType? _attachmentTypeFromMime(String mimeType) {
  if (mimeType.startsWith('image/')) {
    return MaintenanceAttachmentType.image;
  }
  if (mimeType.startsWith('video/')) {
    return MaintenanceAttachmentType.video;
  }
  return null;
}
