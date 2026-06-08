import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/tenant_profile_model.dart';
import '../services/auth_service.dart';
import '../services/tenant_profile_service.dart';
import '../theme/app_colors.dart';

/// Dữ liệu được pre-fill từ TenantProfileResponse truyền vào.
class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({
    super.key,
    required this.profile,
  });

  final TenantProfileResponse profile;

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  // ── Thông tin liên hệ ───────────────────────────────────────────────
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

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

    final firstContact =
        p.emergencyContacts.isNotEmpty ? p.emergencyContacts.first : null;
    _relativeName = TextEditingController(text: firstContact?.fullName ?? '');
    _relativePhone = TextEditingController(text: firstContact?.phone ?? '');

    _vehicles = p.vehicles.isEmpty
        ? [_VehicleFormData()]
        : p.vehicles
            .map((v) => _VehicleFormData(
                  licensePlate: v.licensePlate,
                  existingImageUrl: v.imageUrl,
                ))
            .toList();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
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

  Future<void> _handleSave() async {
    if (_isLoading) return;

    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final relName = _relativeName.text.trim();
    final relPhone = _relativePhone.text.trim();

    if (phone.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đủ số điện thoại và email')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = const TenantProfileService();
      
      final vehiclesData = <Map<String, dynamic>>[];
      for (final v in _vehicles) {
        final plate = v.licensePlateController.text.trim();
        if (plate.isEmpty && v.localImage == null && v.existingImageUrl.isEmpty) continue;
        
        int? fileId;
        if (v.localImage != null) {
          fileId = await service.uploadVehicleImage(
            bytes: await v.localImage!.readAsBytes(),
            fileName: v.localImage!.name,
          );
        }
        
        vehiclesData.add({
          'license_plate': plate,
          'vehicle_type': 'MOTORBIKE',
          if (fileId != null) 'image_file_id': fileId,
        });
      }

      await service.updateMyProfile(
        phone: phone,
        email: email,
        emergencyContacts: [
          if (relName.isNotEmpty || relPhone.isNotEmpty)
            {
              'full_name': relName,
              'phone': relPhone,
              'relationship': 'Người thân',
            }
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
          backgroundColor: const Color(0xFFDC2626),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildContactInfoSection(),
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
                _buildBottomSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 48,
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
              'Cập nhật hồ sơ',
              style: TextStyle(
                color: AppColors.deepBlue,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 18 / 14,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.inputText,
              size: 22,
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
        ),
        const SizedBox(height: 16),
        _EditableField(
          label: 'EMAIL',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }

  // ── 2. Thông tin liên hệ người thân ───────────────────────────────────

  Widget _buildRelativeSection() {
    return _SectionCard(
      icon: Icons.contact_emergency_outlined,
      title: 'Thông tin liên hệ người thân',
      children: [
        _EditableField(
          label: 'TÊN NGƯỜI THÂN',
          controller: _relativeName,
        ),
        const SizedBox(height: 16),
        _EditableField(
          label: 'SỐ ĐIỆN THOẠI',
          controller: _relativePhone,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  // ── 3. Thông tin phương tiện ───────────────────────────────────────────

  Widget _buildVehicleSection() {
    return _SectionCard(
      icon: Icons.directions_car_outlined,
      title: 'Thông tin phương tiện',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.darkBlue,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          '${_vehicles.length}/$_maxVehicles Xe',
          style: const TextStyle(
            fontFamily: 'Inter',
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
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: buttonColor,
                width: 2,
              ),
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
                  const SizedBox(width: 8),
                  const Text(
                    'Thêm phương tiện',
                    style: TextStyle(
                      fontFamily: 'Inter',
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
          top: BorderSide(
            color: AppColors.cardBorder.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _handleSave,
          icon: _isLoading 
            ? const SizedBox(
                width: 18, 
                height: 18, 
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ) 
            : const Icon(Icons.save_rounded, size: 18),
          label: Text(
            _isLoading ? 'ĐANG LƯU...' : 'LƯU THAY ĐỔI',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 24 / 16,
              letterSpacing: 0.5,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkBlue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.darkBlue.withValues(alpha: 0.5),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(12),
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
                    fontFamily: 'Inter',
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
                fontFamily: 'Inter',
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
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: AppColors.bodyText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 16 / 12,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: AppColors.inputText,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 24 / 16,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.inputFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.deepBlue, width: 1.5),
            ),
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: tag + delete icon
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cardBorder.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PHƯƠNG TIỆN ${index + 1}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
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
                    color: Color(0xFFDC2626),
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
          ),
          const SizedBox(height: 12),

          // Ảnh phương tiện
          const Text(
            'Ảnh phương tiện',
            style: TextStyle(
              fontFamily: 'Inter',
              color: AppColors.bodyText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 16 / 12,
            ),
          ),
          const SizedBox(height: 8),
          _VehicleImagePicker(
            data: data,
            onPickImage: onPickImage,
          ),
        ],
      ),
    );
  }
}

/// Vehicle image picker: shows existing image and an "upload" button
class _VehicleImagePicker extends StatelessWidget {
  const _VehicleImagePicker({
    required this.data,
    required this.onPickImage,
  });

  final _VehicleFormData data;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        data.localImage != null || data.existingImageUrl.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing / picked image preview
        if (hasImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: data.localImage != null
                  ? (kIsWeb
                      ? Image.network(data.localImage!.path, fit: BoxFit.cover)
                      : Image.file(File(data.localImage!.path), fit: BoxFit.cover))
                  : _NetworkVehicleThumb(url: data.existingImageUrl),
            ),
          ),
        if (hasImage) const SizedBox(height: 8),
        // Upload button
        GestureDetector(
          onTap: onPickImage,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEDECF1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.cardBorder,
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.bodyText,
                    size: 28,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tải ảnh lên',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: AppColors.bodyText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 16 / 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
    final resolvedUrl = widget.url.startsWith('http')
        ? widget.url
        : '${ApiConfig.baseUrl}${widget.url}';
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AuthService.accessTokenKey);
    final response = await http.get(
      Uri.parse(resolvedUrl),
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
              child: Icon(Icons.broken_image_outlined,
                  color: AppColors.bodyText, size: 24),
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

/// Mutable form data for a single vehicle entry
class _VehicleFormData {
  _VehicleFormData({
    String licensePlate = '',
    this.existingImageUrl = '',
  }) : licensePlateController = TextEditingController(text: licensePlate);

  final TextEditingController licensePlateController;
  final String existingImageUrl;
  XFile? localImage;
}
