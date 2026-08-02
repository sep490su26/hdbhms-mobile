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
import 'package:hdbhms_mobile/widgets/app_filter_chip.dart';
import 'package:hdbhms_mobile/widgets/app_primary_gradient_button.dart';
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
    this.roomId,
    this.roomCode = '',
    this.notificationInitialUnreadCount,
  });

  final MaintenanceTicketService ticketService;
  final CurrentRoomService currentRoomService;
  final ImagePicker? imagePicker;
  final int? roomId;
  final String roomCode;
  final int? notificationInitialUnreadCount;

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
  bool _repairRequested = true;
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
    final selectedRoomId = widget.roomId ?? 0;
    if (selectedRoomId > 0) {
      _currentRoom = CurrentRentedRoom(
        id: selectedRoomId,
        roomCode: widget.roomCode.trim(),
      );
      return;
    }

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
                  iconColor: AppColors.deepBlue,
                  textColor: AppColors.inputText,
                  titleTextStyle: const TextStyle(
                    color: AppColors.inputText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Chọn ảnh'),
                  onTap: () =>
                      Navigator.of(context).pop(_AttachmentSource.image),
                ),
                ListTile(
                  iconColor: AppColors.deepBlue,
                  textColor: AppColors.inputText,
                  titleTextStyle: const TextStyle(
                    color: AppColors.inputText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  leading: const Icon(Icons.videocam_outlined),
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
          _attachmentError = 'Tệp không hợp lệ';
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
      _showSnackBar('Vui lòng hoàn thành các trường bắt buộc');
      return;
    }
    final room = _currentRoom;
    if (room == null || room.id <= 0) {
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
          repairRequested: _repairRequested,
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
            icon: AppNotificationBell(
              color: AppColors.topBarIconColor,
              size: AppColors.topBarIconSize,
              initialUnreadCount: widget.notificationInitialUnreadCount,
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
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(14, 18, 14, 26 + bottomInset),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IntroCard(room: _currentRoom),
                  const SizedBox(height: 14),
                  _FormSurface(
                    header: const _FormSectionHeader(
                      icon: Icons.report_problem_outlined,
                      title: 'Thông tin sự cố',
                      subtitle: 'Cho biết vấn đề để quản lý dễ tiếp nhận.',
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Danh mục sự cố', required: true),
                        const SizedBox(height: 6),
                        FormField<TicketCategory>(
                          initialValue: _selectedCategory,
                          validator: (value) =>
                              value == null ? 'Vui lòng chọn loại sự cố' : null,
                          builder: (field) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _CategoryChipSelector(
                                selectedCategory: field.value,
                                enabled: !_isSubmitting,
                                onSelected: (category) {
                                  field.didChange(category);
                                  setState(() {
                                    _selectedCategory = category;
                                  });
                                },
                              ),
                              if (field.hasError) ...[
                                const SizedBox(height: 7),
                                Text(
                                  field.errorText!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _FieldLabel('Mô tả chi tiết', required: true),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _descriptionController,
                          enabled: !_isSubmitting,
                          minLines: 5,
                          maxLines: 7,
                          textInputAction: TextInputAction.newline,
                          style: const TextStyle(
                            color: AppColors.inputText,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 18 / 13,
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Vui lòng mô tả vấn đề'
                              : null,
                          decoration: _inputDecoration(
                            hintText:
                                'Mô tả chi tiết vấn đề (ví dụ: vị trí, âm thanh, mức độ khẩn cấp)...',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FormSurface(
                    header: _FormSectionHeader(
                      icon: Icons.add_photo_alternate_outlined,
                      title: 'Hình ảnh hoặc video',
                      subtitle: 'Thêm tối đa 3 tệp để minh họa sự cố.',
                      trailing: _AttachmentCount(count: _attachments.length),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            for (
                              var index = 0;
                              index < _maxAttachments;
                              index++
                            ) ...[
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FormSurface(
                    header: const _FormSectionHeader(
                      icon: Icons.tune_rounded,
                      title: 'Hướng xử lý mong muốn',
                      subtitle:
                          'Chọn cách quản lý nên phản hồi với yêu cầu này.',
                    ),
                    child: _RepairIntentSelector(
                      repairRequested: _repairRequested,
                      enabled: !_isSubmitting,
                      onChanged: (value) {
                        setState(() {
                          _repairRequested = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: AppPrimaryGradientButton(
                      onPressed: _isSubmitting ? null : _submit,
                      height: 56,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isSubmitting)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
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
                            _isSubmitting ? 'Đang gửi...' : 'GỬI YÊU CẦU',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              height: 18 / 14,
                            ),
                          ),
                        ],
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
              builder: (context) => MaintenanceTicketListScreen(
                ticketService: widget.ticketService,
                currentRoomService: widget.currentRoomService,
                roomId: _activeRoomId,
                roomCode: _activeRoomCode,
                notificationInitialUnreadCount:
                    widget.notificationInitialUnreadCount,
              ),
            ),
          );
        },
        onBillsTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => BillSelectionPage(
                roomId: _activeRoomId,
                roomCode: _activeRoomCode,
              ),
            ),
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
          MaterialPageRoute(
            builder: (context) => TenantRequestScreen(
              roomId: _activeRoomId,
              roomCode: _activeRoomCode,
            ),
          ),
        ),
      ),
    );
  }

  int? get _activeRoomId {
    final id = _currentRoom?.id ?? widget.roomId;
    return (id ?? 0) > 0 ? id : null;
  }

  String get _activeRoomCode {
    final code = _currentRoom?.roomCode ?? widget.roomCode;
    return code.trim();
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.room});

  final CurrentRentedRoom? room;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: const Color(0xFFEAE8EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
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
          if (room != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.meeting_room_outlined,
                    size: 18,
                    color: AppColors.deepBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PHÒNG ÁP DỤNG',
                          style: TextStyle(
                            color: AppColors.bodyText,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            height: 13 / 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          room!.roomCode.isEmpty
                              ? 'Phòng đang thuê'
                              : 'Phòng ${room!.roomCode}',
                          style: const TextStyle(
                            color: AppColors.deepBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            height: 17 / 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FormSurface extends StatelessWidget {
  const _FormSurface({required this.header, required this.child});

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [header, const SizedBox(height: 16), child],
      ),
    );
  }
}

class _CategoryChipSelector extends StatelessWidget {
  const _CategoryChipSelector({
    required this.selectedCategory,
    required this.enabled,
    required this.onSelected,
  });

  final TicketCategory? selectedCategory;
  final bool enabled;
  final ValueChanged<TicketCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final category in TicketCategory.values) ...[
            AppFilterChip(
              label: category.label,
              icon: _categoryIcon(category),
              isActive: selectedCategory == category,
              onTap: enabled ? () => onSelected(category) : () {},
            ),
            if (category != TicketCategory.values.last)
              const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FormSectionHeader extends StatelessWidget {
  const _FormSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          child: Icon(icon, color: AppColors.deepBlue, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.inputText,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 18 / 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.bodyText,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 15 / 11,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class _AttachmentCount extends StatelessWidget {
  const _AttachmentCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
      ),
      child: Text(
        '$count/3',
        style: const TextStyle(
          color: AppColors.deepBlue,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 14 / 11,
        ),
      ),
    );
  }
}

class _RepairIntentSelector extends StatelessWidget {
  const _RepairIntentSelector({
    required this.repairRequested,
    required this.enabled,
    required this.onChanged,
  });

  final bool repairRequested;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RepairIntentOption(
            selected: repairRequested,
            enabled: enabled,
            icon: Icons.handyman_outlined,
            title: 'Cần sửa chữa',
            subtitle: 'Nhờ quản lý xử lý sự cố',
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RepairIntentOption(
            selected: !repairRequested,
            enabled: enabled,
            icon: Icons.info_outline_rounded,
            title: 'Chỉ báo sự cố',
            subtitle: 'Ghi nhận để quản lý theo dõi',
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

class _RepairIntentOption extends StatelessWidget {
  const _RepairIntentOption({
    required this.selected,
    required this.enabled,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.deepBlue : AppColors.cardBorder;
    return Material(
      color: selected
          ? AppColors.deepBlue.withValues(alpha: 0.07)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Container(
          constraints: const BoxConstraints(minHeight: 92),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.deepBlue, size: 20),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected ? AppColors.deepBlue : AppColors.bodyText,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.inputText,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 16 / 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.bodyText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 15 / 11,
                ),
              ),
            ],
          ),
        ),
      ),
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
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
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
                color: AppColors.neutralStrong,
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
  const _FieldLabel(this.text, {this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: required ? '$text, bắt buộc' : text,
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: AppColors.bodyText,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            height: 16 / 12,
          ),
          children: [
            TextSpan(text: text),
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: AppColors.danger),
              ),
          ],
        ),
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

InputDecoration _inputDecoration({String? hintText, IconData? prefixIcon}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: AppColors.bodyText,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 18 / 13,
    ),
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: EdgeInsets.fromLTRB(
      prefixIcon == null ? 14 : 0,
      13,
      14,
      13,
    ),
    prefixIcon: prefixIcon == null
        ? null
        : Icon(prefixIcon, color: AppColors.bodyText, size: 20),
    prefixIconConstraints: prefixIcon == null
        ? null
        : const BoxConstraints(minWidth: 46, minHeight: 48),
    border: _fieldBorder,
    enabledBorder: _fieldBorder,
    focusedBorder: _fieldBorder.copyWith(
      borderSide: const BorderSide(color: AppColors.deepBlue),
    ),
  );
}

final OutlineInputBorder _fieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppColors.radiusSm),
  borderSide: const BorderSide(color: AppColors.cardBorder),
);

IconData _categoryIcon(TicketCategory category) {
  return switch (category) {
    TicketCategory.equipment => Icons.inventory_2_outlined,
    TicketCategory.electricity => Icons.bolt_outlined,
    TicketCategory.water => Icons.water_drop_outlined,
    TicketCategory.airConditioner => Icons.ac_unit_rounded,
    TicketCategory.internet => Icons.wifi_rounded,
    TicketCategory.doorLock => Icons.lock_outline_rounded,
    TicketCategory.cleaningDrainage => Icons.cleaning_services_outlined,
    TicketCategory.other => Icons.more_horiz_rounded,
  };
}

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
