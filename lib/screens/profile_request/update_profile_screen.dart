// ignore_for_file: use_null_aware_elements

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/models/profile_request/tenant_profile_model.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/services/notification/notification_service.dart';
import 'package:hdbhms_mobile/services/profile_request/tenant_profile_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/utils/identity_profile_validators.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_notification_bell.dart';

/// Dữ liệu được pre-fill từ TenantProfileResponse truyền vào.
class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({
    super.key,
    required this.profile,
    this.profileService = const TenantProfileService(),
    this.notificationService = const NotificationService(),
  });

  final TenantProfileResponse profile;
  final TenantProfileService profileService;
  final NotificationService notificationService;

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Thông tin liên hệ ───────────────────────────────────────────────
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  // ── Thông tin định danh & cư trú (UI-first, chưa có PUT support) ───
  late final TextEditingController _permanentAddressController;
  late final TextEditingController _docNumberController;
  late final TextEditingController _issuedDateController;
  late final TextEditingController _issuedPlaceController;
  DateTime? _issuedDate;
  late final String _originalPermanentAddress;
  late final String _originalDocNumber;
  late final DateTime? _originalIssuedDate;
  late final String _originalIssuedPlace;

  // ── Thông tin liên hệ người thân ────────────────────────────────────
  late final TextEditingController _relativeName;
  late final TextEditingController _relativePhone;

  // ── Phương tiện ─────────────────────────────────────────────────────
  late List<_VehicleFormData> _vehicles;
  static const int _maxVehicles = 2;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _phoneController = TextEditingController(text: p.person.phone);
    _emailController = TextEditingController(text: p.person.email);
    _originalPermanentAddress = p.person.permanentAddress.trim();
    _originalDocNumber = p.identityDocument?.docNumber.trim() ?? '';
    _originalIssuedDate = p.identityDocument?.issuedDate;
    _originalIssuedPlace = p.identityDocument?.issuedPlace.trim() ?? '';
    _permanentAddressController = TextEditingController(
      text: _originalPermanentAddress,
    );
    _docNumberController = TextEditingController(text: _originalDocNumber);
    _issuedDate = _originalIssuedDate;
    _issuedDateController = TextEditingController(
      text: _issuedDate == null ? '' : formatIdentityIssuedDate(_issuedDate!),
    );
    _issuedPlaceController = TextEditingController(text: _originalIssuedPlace);

    final firstContact = p.emergencyContacts.isNotEmpty
        ? p.emergencyContacts.first
        : null;
    _relativeName = TextEditingController(text: firstContact?.fullName ?? '');
    _relativePhone = TextEditingController(text: firstContact?.phone ?? '');

    _vehicles = p.vehicles.isEmpty
        ? [_VehicleFormData()]
        : p.vehicles
              .map(
                (v) => _VehicleFormData(
                  licensePlate: v.licensePlate,
                  existingImageUrl: v.imageUrl,
                ),
              )
              .toList();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _permanentAddressController.dispose();
    _docNumberController.dispose();
    _issuedDateController.dispose();
    _issuedPlaceController.dispose();
    _relativeName.dispose();
    _relativePhone.dispose();
    for (final v in _vehicles) {
      v.licensePlateController.dispose();
    }
    super.dispose();
  }

  void _addVehicle() {
    if (_vehicles.length >= _maxVehicles) return;
    setState(() {
      _vehicles.add(_VehicleFormData());
    });
  }

  void _removeVehicle(int index) {
    if (_vehicles.length <= 1) return;
    setState(() {
      _vehicles[index].licensePlateController.dispose();
      _vehicles.removeAt(index);
    });
  }

  Future<void> _pickImage(int vehicleIndex) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      _vehicles[vehicleIndex].localImage = picked;
    });
  }

  String? _validateVietnamesePhone(String? value, {required String label}) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Vui lòng nhập $label';
    if (!RegExp(r'^(0\d{9}|\+84\d{9})$').hasMatch(phone)) {
      return '$label không hợp lệ';
    }
    return null;
  }

  bool get _hasUnsupportedMetadataChanges =>
      _permanentAddressController.text.trim() != _originalPermanentAddress ||
      _docNumberController.text.trim() != _originalDocNumber ||
      !_isSameDate(_issuedDate, _originalIssuedDate) ||
      _issuedPlaceController.text.trim() != _originalIssuedPlace;

  bool _isSameDate(DateTime? left, DateTime? right) {
    if (left == null || right == null) return left == right;
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String? _validateUnsupportedTextField(
    String? value, {
    required String originalValue,
    required String? Function(String?) validator,
  }) {
    final currentValue = value?.trim() ?? '';
    if (originalValue.isEmpty && currentValue.isEmpty) {
      return null;
    }
    return validator(value);
  }

  String? _validateIssuedDate() {
    if (_originalIssuedDate == null && _issuedDate == null) {
      return null;
    }
    return validateIdentityIssuedDate(_issuedDate);
  }

  Future<void> _pickIssuedDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _issuedDate ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _issuedDate = selected;
      _issuedDateController.text = formatIdentityIssuedDate(selected);
    });
  }

  Future<void> _handleSave() async {
    if (_isLoading) return;

    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final relName = _relativeName.text.trim();
    final relPhone = _relativePhone.text.trim();

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng kiểm tra lại thông tin hồ sơ')),
      );
      return;
    }

    if (_hasUnsupportedMetadataChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Các thay đổi về địa chỉ và CCCD chưa thể lưu vì hệ thống chưa hỗ trợ cập nhật các trường này.',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = widget.profileService;

      final vehiclesData = <Map<String, dynamic>>[];
      for (final v in _vehicles) {
        final plate = v.licensePlateController.text.trim();
        if (plate.isEmpty &&
            v.localImage == null &&
            v.existingImageUrl.isEmpty) {
          continue;
        }

        int? fileId;
        if (v.localImage != null) {
          fileId = await service.uploadVehicleImage(
            bytes: await v.localImage!.readAsBytes(),
            fileName: v.localImage!.name,
          );
        }

        vehiclesData.add({
          'licensePlate': plate,
          'vehicleType': 'MOTORBIKE',
          if (fileId != null) 'imageFileId': fileId,
        });
      }

      await service.updateMyProfile(
        phone: phone,
        email: email,
        emergencyContacts: [
          if (relName.isNotEmpty || relPhone.isNotEmpty)
            {
              'fullName': relName,
              'phone': relPhone,
              'relationship': 'Người thân',
            },
        ],
        vehicles: vehiclesData,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật hồ sơ thành công'),
          backgroundColor: AppColors.darkBlue,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is TenantProfileException ? e.message : 'Có lỗi xảy ra',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(
          header: _buildHeader(context),
          child: Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildContactInfoSection(),
                        const SizedBox(height: 15),
                        _buildIdentityAndResidenceSection(),
                        const SizedBox(height: 15),
                        _buildRelativeSection(),
                        const SizedBox(height: 15),
                        _buildVehicleSection(),
                        if (_vehicles.length < _maxVehicles) ...[
                          const SizedBox(height: 15),
                          _buildAddVehicleButton(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              _buildBottomSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: AppColors.topBarHeight,
      padding: const EdgeInsets.fromLTRB(4, 0, 13, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.cardBorder.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.deepBlue,
              size: 24,
            ),
            tooltip: 'Trở về',
          ),
          const Expanded(
            child: Text('Cập nhật hồ sơ', style: AppColors.topBarTitleStyle),
          ),
          IconButton(
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: AppNotificationBell(
              color: AppColors.topBarIconColor,
              size: AppColors.topBarIconSize,
              notificationService: widget.notificationService,
            ),
            tooltip: 'Thông báo',
          ),
        ],
      ),
    );
  }

  // ── 1. Thông tin liên hệ ──────────────────────────────────────────────

  Widget _buildContactInfoSection() {
    return _SectionCard(
      icon: Icons.contact_phone_outlined,
      title: 'Thông tin liên hệ',
      children: [
        _EditableField(
          label: 'SỐ ĐIỆN THOẠI',
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          validator: (value) => _validateVietnamesePhone(
            value,
            label: 'số điện thoại',
          ),
        ),
        const SizedBox(height: 16),
        _EditableField(
          label: 'EMAIL',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          fieldKey: const ValueKey('update-profile-email'),
          validator: validateProfileEmail,
        ),
      ],
    );
  }

  // ── 2. Thông tin định danh & cư trú ──────────────────────────────────

  Widget _buildIdentityAndResidenceSection() {
    return _SectionCard(
      icon: Icons.badge_outlined,
      title: 'Thông tin định danh & cư trú',
      children: [
        _EditableField(
          label: 'ĐỊA CHỈ THƯỜNG TRÚ',
          controller: _permanentAddressController,
          fieldKey: const ValueKey('update-profile-permanent-address'),
          keyboardType: TextInputType.streetAddress,
          minLines: 2,
          maxLines: 4,
          maxLength: 1000,
          validator: (value) => _validateUnsupportedTextField(
            value,
            originalValue: _originalPermanentAddress,
            validator: validatePermanentAddress,
          ),
        ),
        const SizedBox(height: 16),
        _EditableField(
          label: 'SỐ CCCD',
          controller: _docNumberController,
          fieldKey: const ValueKey('update-profile-doc-number'),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 12,
          validator: (value) => _validateUnsupportedTextField(
            value,
            originalValue: _originalDocNumber,
            validator: validateIdentityDocumentNumber,
          ),
        ),
        const SizedBox(height: 16),
        _EditableField(
          label: 'NGÀY CẤP',
          controller: _issuedDateController,
          fieldKey: const ValueKey('update-profile-issued-date'),
          readOnly: true,
          onTap: _pickIssuedDate,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
          validator: (_) => _validateIssuedDate(),
        ),
        const SizedBox(height: 16),
        _EditableField(
          label: 'NƠI CẤP',
          controller: _issuedPlaceController,
          fieldKey: const ValueKey('update-profile-issued-place'),
          minLines: 1,
          maxLines: 3,
          maxLength: 255,
          validator: (value) => _validateUnsupportedTextField(
            value,
            originalValue: _originalIssuedPlace,
            validator: validateIdentityIssuedPlace,
          ),
        ),
      ],
    );
  }

  // ── 3. Thông tin liên hệ người thân ───────────────────────────────────

  Widget _buildRelativeSection() {
    return _SectionCard(
      icon: Icons.contact_emergency_outlined,
      title: 'Thông tin liên hệ người thân',
      children: [
        _EditableField(
          label: 'TÊN NGƯỜI THÂN',
          controller: _relativeName,
          validator: (value) {
            final name = value?.trim() ?? '';
            final phone = _relativePhone.text.trim();
            if (name.isEmpty && phone.isEmpty) return null;
            return name.isEmpty ? 'Vui lòng nhập tên người liên hệ' : null;
          },
        ),
        const SizedBox(height: 16),
        _EditableField(
          label: 'SỐ ĐIỆN THOẠI',
          controller: _relativePhone,
          keyboardType: TextInputType.phone,
          validator: (value) {
            final phone = value?.trim() ?? '';
            final name = _relativeName.text.trim();
            if (name.isEmpty && phone.isEmpty) return null;
            return _validateVietnamesePhone(
              value,
              label: 'số điện thoại người liên hệ',
            );
          },
        ),
      ],
    );
  }

  // ── 4. Thông tin phương tiện ───────────────────────────────────────────

  Widget _buildVehicleSection() {
    return _SectionCard(
      icon: Icons.directions_car_outlined,
      title: 'Thông tin phương tiện',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.darkBlue,
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
        ),
        child: Text(
          '${_vehicles.length}/$_maxVehicles Xe',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 16 / 12,
          ),
        ),
      ),
      subtitle: 'Mỗi người chỉ được đăng ký tối đa $_maxVehicles xe',
      children: [
        for (var i = 0; i < _vehicles.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _VehicleCard(
            index: i,
            data: _vehicles[i],
            canDelete: _vehicles.length > 1,
            onDelete: () => _removeVehicle(i),
            onPickImage: () => _pickImage(i),
          ),
        ],
      ],
    );
  }

  // ── Nút "Thêm phương tiện" ────────────────────────────────────────────

  Widget _buildAddVehicleButton() {
    const buttonColor = Color(0xFF000666);
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _addVehicle,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              border: Border.all(color: buttonColor, width: 2),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_circle_outline_rounded,
                    color: buttonColor,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Thêm phương tiện',
                    style: TextStyle(
                      color: buttonColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 24 / 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Bottom Action Button ──────────────────────────────────────────────

  Widget _buildBottomSaveButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.6)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          key: const ValueKey('update-profile-save'),
          onPressed: _isLoading ? null : _handleSave,
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded, size: 18),
          label: Text(
            _isLoading ? 'ĐANG LƯU...' : 'LƯU THAY ĐỔI',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 24 / 16,
              letterSpacing: 0.5,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.72),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Shared Widgets
// ═════════════════════════════════════════════════════════════════════════════

/// Section card with icon title — matches Figma design "Contact Info Section"
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
    this.trailing,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 15, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(26, 35, 126, 0.05),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(icon, color: AppColors.deepBlue, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.inputText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 28 / 16,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.bodyText,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 20 / 14,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// Editable text field matching Figma input style
class _EditableField extends StatelessWidget {
  const _EditableField({
    required this.label,
    required this.controller,
    this.fieldKey,
    this.keyboardType,
    this.validator,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
  });

  final String label;
  final TextEditingController controller;
  final Key? fieldKey;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.bodyText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 16 / 12,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          key: fieldKey,
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          minLines: minLines,
          maxLines: maxLines,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          readOnly: readOnly,
          onTap: onTap,
          style: const TextStyle(
            color: AppColors.inputText,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 24 / 16,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.inputFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              borderSide: const BorderSide(
                color: AppColors.deepBlue,
                width: 1.5,
              ),
            ),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

/// Vehicle card matching Figma "Vehicle 1" design
class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.index,
    required this.data,
    required this.canDelete,
    required this.onDelete,
    required this.onPickImage,
  });

  final int index;
  final _VehicleFormData data;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: tag + delete icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardBorder.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: Text(
                  'PHƯƠNG TIỆN ${index + 1}',
                  style: const TextStyle(
                    color: Color(0xFF000666),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 14 / 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              if (canDelete)
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.danger,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Biển số xe
          _EditableField(
            label: 'Biển số xe',
            controller: data.licensePlateController,
            validator: (value) {
              final plate = value?.trim() ?? '';
              final hasVehicleContent =
                  plate.isNotEmpty ||
                  data.localImage != null ||
                  data.existingImageUrl.isNotEmpty;
              if (!hasVehicleContent || plate.isNotEmpty) return null;
              return 'Vui lòng nhập biển số xe';
            },
          ),
          const SizedBox(height: 12),

          // Ảnh phương tiện
          const Text(
            'Ảnh phương tiện',
            style: TextStyle(
              color: AppColors.bodyText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 16 / 12,
            ),
          ),
          const SizedBox(height: 8),
          _VehicleImagePicker(data: data, onPickImage: onPickImage),
        ],
      ),
    );
  }
}

/// A single image area that can be tapped to upload or replace the image.
class _VehicleImagePicker extends StatelessWidget {
  const _VehicleImagePicker({required this.data, required this.onPickImage});

  final _VehicleFormData data;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        data.localImage != null || data.existingImageUrl.isNotEmpty;

    return GestureDetector(
      onTap: onPickImage,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                data.localImage != null
                    ? (kIsWeb
                          ? Image.network(
                              data.localImage!.path,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(data.localImage!.path),
                              fit: BoxFit.cover,
                            ))
                    : _NetworkVehicleThumb(url: data.existingImageUrl)
              else
                Container(
                  color: const Color(0xFFEDECF1),
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        color: AppColors.bodyText,
                        size: 28,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Tải ảnh lên',
                        style: TextStyle(
                          color: AppColors.bodyText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 16 / 13,
                        ),
                      ),
                    ],
                  ),
                ),
              if (hasImage)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 15,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Thay ảnh',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.cardBorder),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thumbnail for an existing network vehicle image
class _NetworkVehicleThumb extends StatefulWidget {
  const _NetworkVehicleThumb({required this.url});
  final String url;

  @override
  State<_NetworkVehicleThumb> createState() => _NetworkVehicleThumbState();
}

class _NetworkVehicleThumbState extends State<_NetworkVehicleThumb> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Uint8List> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AuthService.accessTokenKey);
    final response = await http.get(
      Uri.parse(_resolveImageUrl(widget.url)),
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw const FormatException('Cannot load image');
    }
    return response.bodyBytes;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        }
        if (snapshot.hasError) {
          return Container(
            color: const Color(0xFFEDECF1),
            child: const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: AppColors.bodyText,
                size: 24,
              ),
            ),
          );
        }
        return Container(
          color: const Color(0xFFEDECF1),
          child: const Center(
            child: CircularProgressIndicator(
              color: AppColors.deepBlue,
              strokeWidth: 2,
            ),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Data & Utilities
// ═════════════════════════════════════════════════════════════════════════════

String _resolveImageUrl(String value) {
  final url = value.trim();
  if (url.isEmpty) return '';

  final uri = Uri.tryParse(url);
  if (uri != null && uri.hasScheme) return url;

  final baseUri = Uri.parse(ApiConfig.baseUrl);
  if (url.startsWith('/')) {
    return baseUri.replace(path: url).toString();
  }

  final base = ApiConfig.baseUrl.endsWith('/')
      ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
      : ApiConfig.baseUrl;
  return '$base/$url';
}

/// Mutable form data for a single vehicle entry
class _VehicleFormData {
  _VehicleFormData({String licensePlate = '', this.existingImageUrl = ''})
    : licensePlateController = TextEditingController(text: licensePlate);

  final TextEditingController licensePlateController;
  final String existingImageUrl;
  XFile? localImage;
}
