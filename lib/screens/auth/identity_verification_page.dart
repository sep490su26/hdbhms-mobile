import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hdbhms_mobile/models/auth/identity_image_file.dart';
import 'package:hdbhms_mobile/models/onboarding_state.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/services/file_upload_service.dart';
import 'package:hdbhms_mobile/services/home/home_service.dart';
import 'package:hdbhms_mobile/services/auth/identity_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/screens/tenant_overview/tenant_overview_screen.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';
import 'package:hdbhms_mobile/widgets/request_form_widgets.dart';

enum IdentityDocumentStep {
  portrait,
  frontId,
  backId,
  identityInfo,
  confirm;

  String get title {
    switch (this) {
      case IdentityDocumentStep.portrait:
        return '\u1EA2nh ch\u00E2n dung';
      case IdentityDocumentStep.frontId:
        return 'CCCD m\u1EB7t tr\u01B0\u1EDBc';
      case IdentityDocumentStep.backId:
        return 'CCCD m\u1EB7t sau';
      case IdentityDocumentStep.identityInfo:
        return 'Th\u00F4ng tin CCCD';
      case IdentityDocumentStep.confirm:
        return 'X\u00E1c nh\u1EADn';
    }
  }

  String get stepperLabel {
    return switch (this) {
      IdentityDocumentStep.portrait => 'Ảnh chân dung',
      IdentityDocumentStep.frontId => 'CCCD mặt trước',
      IdentityDocumentStep.backId => 'CCCD mặt sau',
      IdentityDocumentStep.identityInfo => 'Th\u00F4ng tin',
      IdentityDocumentStep.confirm => 'X\u00E1c nh\u1EADn',
    };
  }
}

String? validateIdentityDocumentNumber(String? value) {
  final number = value?.trim() ?? '';
  if (number.isEmpty) return 'Vui l\u00F2ng nh\u1EADp s\u1ED1 CCCD';
  if (!RegExp(r'^\d{12}$').hasMatch(number)) {
    return 'S\u1ED1 CCCD ph\u1EA3i g\u1ED3m \u0111\u00FAng 12 ch\u1EEF s\u1ED1';
  }
  return null;
}

String? validateIdentityIssuedDate(DateTime? value, {DateTime? today}) {
  if (value == null) return 'Vui l\u00F2ng ch\u1ECDn ng\u00E0y c\u1EA5p';
  final now = today ?? DateTime.now();
  final dateOnly = DateTime(value.year, value.month, value.day);
  final todayOnly = DateTime(now.year, now.month, now.day);
  if (dateOnly.isAfter(todayOnly)) {
    return 'Ng\u00E0y c\u1EA5p kh\u00F4ng \u0111\u01B0\u1EE3c \u1EDF t\u01B0\u01A1ng lai';
  }
  return null;
}

String? validateIdentityIssuedPlace(String? value) {
  final place = value?.trim() ?? '';
  if (place.isEmpty) return 'Vui l\u00F2ng nh\u1EADp n\u01A1i c\u1EA5p';
  if (place.length > 255) {
    return 'N\u01A1i c\u1EA5p kh\u00F4ng \u0111\u01B0\u1EE3c v\u01B0\u1EE3t qu\u00E1 255 k\u00FD t\u1EF1';
  }
  return null;
}

String formatIdentityIssuedDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

class CompleteProfileUploadScreen extends IdentityVerificationPage {
  const CompleteProfileUploadScreen({
    super.key,
    super.fileUploadService,
    super.identityService,
    super.authService,
    super.homeService,
    super.isRequired,
    super.onCompleted,
  });
}

class IdentityVerificationPage extends StatefulWidget {
  const IdentityVerificationPage({
    super.key,
    this.fileUploadService,
    this.identityService,
    this.authService = const AuthService(),
    this.homeService = const HomeService(),
    this.isRequired = false,
    this.onCompleted,
  });

  final FileUploadService? fileUploadService;
  final IdentityService? identityService;
  final AuthService authService;
  final HomeService homeService;
  final bool isRequired;
  final VoidCallback? onCompleted;

  @override
  State<IdentityVerificationPage> createState() =>
      _IdentityVerificationPageState();
}

class _IdentityVerificationPageState extends State<IdentityVerificationPage> {
  IdentityDocumentStep _currentStep = IdentityDocumentStep.portrait;
  IdentityImageFile? _portraitImage;
  IdentityImageFile? _frontIdImage;
  IdentityImageFile? _backIdImage;
  IdentityDocumentStep? _loadingStep;
  final _identityInfoFormKey = GlobalKey<FormState>();
  final _docNumberFieldKey = GlobalKey<FormFieldState<String>>();
  final _issuedDateFieldKey = GlobalKey<FormFieldState<String>>();
  final _issuedPlaceFieldKey = GlobalKey<FormFieldState<String>>();
  late final FileUploadService _fileUploadService;
  late final IdentityService _identityService;
  late final TextEditingController _docNumberController;
  late final TextEditingController _issuedDateController;
  late final TextEditingController _issuedPlaceController;
  late final FocusNode _docNumberFocusNode;
  late final FocusNode _issuedDateFocusNode;
  late final FocusNode _issuedPlaceFocusNode;
  DateTime? _issuedDate;
  bool _isSubmitting = false;

  bool get _hasAllImages =>
      _portraitImage != null && _frontIdImage != null && _backIdImage != null;

  bool get _hasValidIdentityInfo =>
      validateIdentityDocumentNumber(_docNumberController.text) == null &&
      validateIdentityIssuedDate(_issuedDate) == null &&
      validateIdentityIssuedPlace(_issuedPlaceController.text) == null;

  bool get _canContinue {
    if (_loadingStep != null || _isSubmitting) {
      return false;
    }
    return switch (_currentStep) {
      IdentityDocumentStep.portrait => _portraitImage != null,
      IdentityDocumentStep.frontId => _frontIdImage != null,
      IdentityDocumentStep.backId => _backIdImage != null,
      IdentityDocumentStep.identityInfo => true,
      IdentityDocumentStep.confirm => _hasAllImages && _hasValidIdentityInfo,
    };
  }

  @override
  void initState() {
    super.initState();
    _fileUploadService =
        widget.fileUploadService ?? ImagePickerFileUploadService();
    _identityService = widget.identityService ?? const IdentityService();
    _docNumberController = TextEditingController();
    _issuedDateController = TextEditingController();
    _issuedPlaceController = TextEditingController();
    _docNumberFocusNode = FocusNode();
    _issuedDateFocusNode = FocusNode();
    _issuedPlaceFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _docNumberController.dispose();
    _issuedDateController.dispose();
    _issuedPlaceController.dispose();
    _docNumberFocusNode.dispose();
    _issuedDateFocusNode.dispose();
    _issuedPlaceFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isRequired && !_isSubmitting,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(AppColors.topBarHeight),
          child: AppTopBar(
            title: 'Hoàn tất hồ sơ',
            onBack: widget.isRequired
                ? null
                : () => Navigator.of(context).maybePop(),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _HeaderCopy(),
                        const SizedBox(height: 18),
                        _IdentityStepper(
                          currentStep: _currentStep,
                          portraitDone: _portraitImage != null,
                          frontDone: _frontIdImage != null,
                          backDone: _backIdImage != null,
                          identityInfoDone: _hasValidIdentityInfo,
                        ),
                        const SizedBox(height: 18),
                        _buildCurrentStepCard(),
                      ],
                    ),
                  ),
                ),
                _BottomActionBar(
                  showBackButton: _currentStep != IdentityDocumentStep.portrait,
                  isEnabled: _canContinue,
                  isLoading: _isSubmitting,
                  actionLabel: _currentStep == IdentityDocumentStep.confirm
                      ? 'Xác nhận'
                      : 'Tiếp tục',
                  onBack: _handleBackStep,
                  onContinue: () {
                    _handleContinue();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepCard() {
    switch (_currentStep) {
      case IdentityDocumentStep.portrait:
        return _ImageCaptureStepCard(
          key: const ValueKey('portrait_step'),
          step: IdentityDocumentStep.portrait,
          imageFile: _portraitImage,
          isLoading: _loadingStep == IdentityDocumentStep.portrait,
          preview: const _PortraitPreview(),
          instruction:
              'Ch\u1EE5p r\u00F5 m\u1EB7t, \u0111\u1EE7 s\u00E1ng, kh\u00F4ng \u0111eo kh\u1EA9u trang/k\u00EDnh che m\u1EB7t, kh\u00F4ng b\u1ECB nh\u00F2e.',
          onCapture: () => _pickImage(
            IdentityDocumentStep.portrait,
            IdentityImageSource.camera,
          ),
          onPick: () => _pickImage(
            IdentityDocumentStep.portrait,
            IdentityImageSource.gallery,
          ),
        );
      case IdentityDocumentStep.frontId:
        return _ImageCaptureStepCard(
          key: const ValueKey('front_id_step'),
          step: IdentityDocumentStep.frontId,
          imageFile: _frontIdImage,
          isLoading: _loadingStep == IdentityDocumentStep.frontId,
          preview: const _IdCardPreview(label: 'MẶT TRƯỚC'),
          instruction:
              '\u0110\u1EB7t CCCD n\u1EB1m trong khung, \u0111\u1EE7 4 g\u00F3c, ch\u1EEF r\u00F5 n\u00E9t, kh\u00F4ng b\u1ECB l\u00F3a s\u00E1ng.',
          onCapture: () => _pickImage(
            IdentityDocumentStep.frontId,
            IdentityImageSource.camera,
          ),
          onPick: () => _pickImage(
            IdentityDocumentStep.frontId,
            IdentityImageSource.gallery,
          ),
        );
      case IdentityDocumentStep.backId:
        return _ImageCaptureStepCard(
          key: const ValueKey('back_id_step'),
          step: IdentityDocumentStep.backId,
          imageFile: _backIdImage,
          isLoading: _loadingStep == IdentityDocumentStep.backId,
          preview: const _IdCardPreview(label: 'M\u1EB6T SAU'),
          instruction:
              '\u0110\u1EB7t CCCD n\u1EB1m trong khung, \u0111\u1EE7 4 g\u00F3c, ch\u1EEF r\u00F5 n\u00E9t, kh\u00F4ng b\u1ECB l\u00F3a s\u00E1ng.',
          onCapture: () => _pickImage(
            IdentityDocumentStep.backId,
            IdentityImageSource.camera,
          ),
          onPick: () => _pickImage(
            IdentityDocumentStep.backId,
            IdentityImageSource.gallery,
          ),
        );
      case IdentityDocumentStep.identityInfo:
        return _IdentityInfoStepCard(
          key: const ValueKey('identity-info-step'),
          formKey: _identityInfoFormKey,
          docNumberFieldKey: _docNumberFieldKey,
          issuedDateFieldKey: _issuedDateFieldKey,
          issuedPlaceFieldKey: _issuedPlaceFieldKey,
          docNumberController: _docNumberController,
          issuedDateController: _issuedDateController,
          issuedPlaceController: _issuedPlaceController,
          docNumberFocusNode: _docNumberFocusNode,
          issuedDateFocusNode: _issuedDateFocusNode,
          issuedPlaceFocusNode: _issuedPlaceFocusNode,
          issuedDate: _issuedDate,
          onPickIssuedDate: _pickIssuedDate,
        );
      case IdentityDocumentStep.confirm:
        return _ReviewStepCard(
          portraitImage: _portraitImage,
          frontIdImage: _frontIdImage,
          backIdImage: _backIdImage,
          docNumber: _docNumberController.text.trim(),
          issuedDate: _issuedDate,
          issuedPlace: _issuedPlaceController.text.trim(),
          onEditStep: _selectStep,
        );
    }
  }

  void _selectStep(IdentityDocumentStep step) {
    setState(() {
      _currentStep = step;
    });
  }

  void _handleBackStep() {
    final previousStep = switch (_currentStep) {
      IdentityDocumentStep.portrait => null,
      IdentityDocumentStep.frontId => IdentityDocumentStep.portrait,
      IdentityDocumentStep.backId => IdentityDocumentStep.frontId,
      IdentityDocumentStep.identityInfo => IdentityDocumentStep.backId,
      IdentityDocumentStep.confirm => IdentityDocumentStep.identityInfo,
    };

    if (previousStep == null) {
      if (widget.isRequired) {
        _showMessage('Vui lòng hoàn tất định danh để tiếp tục');
        return;
      }
      Navigator.of(context).maybePop();
      return;
    }

    setState(() {
      _currentStep = previousStep;
    });
  }

  Future<void> _pickImage(
    IdentityDocumentStep step,
    IdentityImageSource source,
  ) async {
    setState(() {
      _loadingStep = step;
    });

    try {
      final image = await _fileUploadService.pickIdentityImage(
        label: step.title,
        source: source,
      );

      if (!mounted) return;

      final validationMessage = _fileUploadService.validateIdentityImage(image);
      if (validationMessage != null) {
        _showMessage(validationMessage);
        return;
      }

      setState(() {
        switch (step) {
          case IdentityDocumentStep.portrait:
            _portraitImage = image;
          case IdentityDocumentStep.frontId:
            _frontIdImage = image;
          case IdentityDocumentStep.backId:
            _backIdImage = image;
          case IdentityDocumentStep.identityInfo:
          case IdentityDocumentStep.confirm:
            break;
        }
      });
    } on FilePickerCanceledException {
      return;
    } on FilePickerPermissionDeniedException catch (error) {
      if (mounted) {
        _showMessage(
          error.source == IdentityImageSource.camera
              ? 'Không có quyền camera, vui lòng cấp quyền để chụp ảnh'
              : 'Không có quyền truy cập thư viện ảnh, vui lòng cấp quyền để chọn ảnh',
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Không chọn được ảnh, vui lòng thử lại');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingStep = null;
        });
      }
    }
  }

  Future<void> _handleContinue() async {
    if (_currentStep == IdentityDocumentStep.identityInfo) {
      final isValid = _identityInfoFormKey.currentState?.validate() ?? false;
      if (!isValid) {
        _focusFirstInvalidIdentityField();
        return;
      }
      setState(() {
        _currentStep = IdentityDocumentStep.confirm;
      });
      return;
    }

    final validationMessage = _currentStep == IdentityDocumentStep.confirm
        ? _validateImages()
        : _validateCurrentStep();
    if (validationMessage != null) {
      _showMessage(validationMessage);
      return;
    }

    if (_currentStep != IdentityDocumentStep.confirm) {
      setState(() {
        _currentStep = _nextStepAfterCurrent();
      });
      return;
    }

    if (!_hasValidIdentityInfo) {
      setState(() {
        _currentStep = IdentityDocumentStep.identityInfo;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _identityInfoFormKey.currentState?.validate();
        _focusFirstInvalidIdentityField();
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // TODO: Send CCCD metadata when identity-verification supports
      // docNumber, issuedDate, and issuedPlace multipart fields.
      final result = await _identityService.uploadIdentity(
        portrait: _portraitImage!,
        frontId: _frontIdImage!,
        backId: _backIdImage!,
      );

      if (!mounted) {
        return;
      }

      if (widget.onCompleted != null) {
        await showAppAnimatedSuccessDialog(
          context,
          title: 'Hoàn tất hồ sơ',
          message: 'Thông tin định danh của bạn đã được gửi thành công.',
          primaryLabel: 'Tiếp tục',
          onPrimary: widget.onCompleted!,
        );
        return;
      }

      if (result.profileCompleted ||
          result.onboarding.nextStep == OnboardingState.home) {
        await showAppAnimatedSuccessDialog(
          context,
          title: 'Hoàn tất hồ sơ',
          message: 'Thông tin định danh của bạn đã được gửi thành công.',
          primaryLabel: 'Về tổng quan',
          onPrimary: () {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => TenantOverviewScreen(
                  authService: widget.authService,
                  homeService: widget.homeService,
                ),
              ),
            );
          },
        );
        if (!mounted) {
          return;
        }
        return;
      }

      _showMessage(
        result.message.isNotEmpty
            ? result.message
            : 'Hoàn tất hồ sơ thành công',
      );
    } on IdentityException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  IdentityDocumentStep _nextStepAfterCurrent() {
    return switch (_currentStep) {
      IdentityDocumentStep.portrait => IdentityDocumentStep.frontId,
      IdentityDocumentStep.frontId => IdentityDocumentStep.backId,
      IdentityDocumentStep.backId => IdentityDocumentStep.identityInfo,
      IdentityDocumentStep.identityInfo => IdentityDocumentStep.confirm,
      IdentityDocumentStep.confirm => IdentityDocumentStep.confirm,
    };
  }

  String? _validateCurrentStep() {
    return switch (_currentStep) {
      IdentityDocumentStep.portrait =>
        _portraitImage == null ? 'Vui lòng thêm ảnh chân dung' : null,
      IdentityDocumentStep.frontId =>
        _frontIdImage == null ? 'Vui lòng thêm CCCD mặt trước' : null,
      IdentityDocumentStep.backId =>
        _backIdImage == null ? 'Vui lòng thêm CCCD mặt sau' : null,
      IdentityDocumentStep.identityInfo => null,
      IdentityDocumentStep.confirm => _validateImages(),
    };
  }

  String? _validateImages() {
    if (_portraitImage == null) {
      return 'Vui lòng tải lên đủ ảnh chân dung và 2 mặt CCCD';
    }
    if (_frontIdImage == null) {
      return 'Vui lòng tải lên đủ ảnh chân dung và 2 mặt CCCD';
    }
    if (_backIdImage == null) {
      return 'Vui lòng tải lên đủ ảnh chân dung và 2 mặt CCCD';
    }
    return null;
  }

  Future<void> _pickIssuedDate() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _issuedDate ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (selectedDate == null || !mounted) return;
    setState(() {
      _issuedDate = selectedDate;
      _issuedDateController.text = formatIdentityIssuedDate(selectedDate);
    });
    _issuedDateFieldKey.currentState?.validate();
  }

  void _focusFirstInvalidIdentityField() {
    final focusNode =
        validateIdentityDocumentNumber(_docNumberController.text) != null
        ? _docNumberFocusNode
        : validateIdentityIssuedDate(_issuedDate) != null
        ? _issuedDateFocusNode
        : _issuedPlaceFocusNode;
    focusNode.requestFocus();
    final fieldContext = focusNode == _docNumberFocusNode
        ? _docNumberFieldKey.currentContext
        : focusNode == _issuedDateFocusNode
        ? _issuedDateFieldKey.currentContext
        : _issuedPlaceFieldKey.currentContext;
    if (fieldContext != null) {
      Scrollable.ensureVisible(
        fieldContext,
        alignment: 0.2,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HeaderCopy extends StatelessWidget {
  const _HeaderCopy();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Center(
          child: Text(
            'Ho\u00E0n t\u1EA5t h\u1ED3 s\u01A1',
            style: AppTypography.pageTitle,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Vui l\u00F2ng cung c\u1EA5p \u1EA3nh ch\u00E2n dung v\u00E0 CCCD r\u00F5 n\u00E9t \u0111\u1EC3 ho\u00E0n t\u1EA5t h\u1ED3 s\u01A1.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.bodyText,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 20 / 13,
          ),
        ),
      ],
    );
  }
}

class _IdentityStepper extends StatelessWidget {
  const _IdentityStepper({
    required this.currentStep,
    required this.portraitDone,
    required this.frontDone,
    required this.backDone,
    required this.identityInfoDone,
  });

  final IdentityDocumentStep currentStep;
  final bool portraitDone;
  final bool frontDone;
  final bool backDone;
  final bool identityInfoDone;

  @override
  Widget build(BuildContext context) {
    final steps = IdentityDocumentStep.values;

    return Container(
      key: const ValueKey('identity-stepper'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 340;
          final currentIndex = steps.indexOf(currentStep) + 1;
          return Column(
            children: [
              Row(
                children: [
                  for (var index = 0; index < steps.length; index++) ...[
                    Expanded(
                      child: _StepPill(
                        step: steps[index],
                        status: _statusFor(steps[index]),
                        showLabel: !compact,
                      ),
                    ),
                    if (index != steps.length - 1)
                      Container(
                        width: compact ? 6 : 10,
                        height: 2,
                        color: _connectorColor(
                          _statusFor(steps[index]),
                          _statusFor(steps[index + 1]),
                        ),
                      ),
                  ],
                ],
              ),
              if (compact) ...[
                const SizedBox(height: 8),
                Text(
                  'Bước $currentIndex/${steps.length} • ${currentStep.title}',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.bodyText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  _StepStatus _statusFor(IdentityDocumentStep step) {
    if (step == currentStep) return _StepStatus.active;
    switch (step) {
      case IdentityDocumentStep.portrait:
        return portraitDone ? _StepStatus.done : _StepStatus.pending;
      case IdentityDocumentStep.frontId:
        return frontDone ? _StepStatus.done : _StepStatus.pending;
      case IdentityDocumentStep.backId:
        return backDone ? _StepStatus.done : _StepStatus.pending;
      case IdentityDocumentStep.identityInfo:
        return identityInfoDone ? _StepStatus.done : _StepStatus.pending;
      case IdentityDocumentStep.confirm:
        return portraitDone && frontDone && backDone && identityInfoDone
            ? _StepStatus.done
            : _StepStatus.pending;
    }
  }

  Color _connectorColor(_StepStatus current, _StepStatus next) {
    if (current == _StepStatus.done && next != _StepStatus.pending) {
      return AppColors.success;
    }
    if (current == _StepStatus.active || next == _StepStatus.active) {
      return AppColors.primary;
    }
    return AppColors.cardBorder;
  }
}

enum _StepStatus { active, done, pending }

class _StepPill extends StatelessWidget {
  const _StepPill({
    required this.step,
    required this.status,
    required this.showLabel,
  });

  final IdentityDocumentStep step;
  final _StepStatus status;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final isActive = status == _StepStatus.active;
    final isDone = status == _StepStatus.done;

    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: isDone
                ? AppColors.success
                : isActive
                ? AppColors.primary
                : AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDone
                  ? AppColors.success
                  : isActive
                  ? AppColors.primary
                  : AppColors.cardBorder,
            ),
          ),
          child: Icon(
            isDone ? Icons.check_rounded : Icons.circle,
            color: isActive || isDone ? Colors.white : AppColors.cardBorder,
            size: isDone ? 17 : 8,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 6),
          Text(
            step.stepperLabel,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: isDone
                  ? AppColors.successText
                  : isActive
                  ? AppColors.primary
                  : AppColors.bodyText,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
              height: 13 / 10,
            ),
          ),
        ],
      ],
    );
  }
}

class _ImageCaptureStepCard extends StatelessWidget {
  const _ImageCaptureStepCard({
    super.key,
    required this.step,
    required this.imageFile,
    required this.isLoading,
    required this.preview,
    required this.instruction,
    required this.onCapture,
    required this.onPick,
  });

  final IdentityDocumentStep step;
  final IdentityImageFile? imageFile;
  final bool isLoading;
  final Widget preview;
  final String instruction;
  final VoidCallback onCapture;
  final VoidCallback onPick;

  bool get _hasImage => imageFile != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.title,
            style: const TextStyle(
              color: AppColors.darkBlue,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 22 / 16,
            ),
          ),
          const SizedBox(height: 14),
          Stack(
            alignment: Alignment.center,
            children: [
              imageFile == null
                  ? preview
                  : _SelectedImagePreview(
                      file: imageFile!,
                      isPortrait: step == IdentityDocumentStep.portrait,
                    ),
              if (isLoading)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _ImageMeta(file: imageFile),
          const SizedBox(height: 14),
          _InstructionBox(instruction: instruction),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : onCapture,
                  icon: Icon(
                    _hasImage
                        ? Icons.camera_alt_rounded
                        : Icons.photo_camera_outlined,
                  ),
                  label: Text(
                    _hasImage ? 'Ch\u1EE5p l\u1EA1i' : 'Ch\u1EE5p \u1EA3nh',
                  ),
                  style: _outlinedActionStyle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : onPick,
                  icon: Icon(
                    _hasImage
                        ? Icons.swap_horiz_rounded
                        : Icons.photo_library_outlined,
                  ),
                  label: Text(
                    _hasImage
                        ? '\u0110\u1ED5i \u1EA3nh'
                        : 'Ch\u1ECDn t\u1EEB th\u01B0 vi\u1EC7n',
                  ),
                  style: _outlinedActionStyle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static final ButtonStyle _outlinedActionStyle = OutlinedButton.styleFrom(
    foregroundColor: AppColors.actionBlue,
    side: const BorderSide(color: AppColors.actionBlue),
    minimumSize: const Size.fromHeight(44),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
    ),
    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
  );
}

class _ImageMeta extends StatelessWidget {
  const _ImageMeta({required this.file});

  final IdentityImageFile? file;

  @override
  Widget build(BuildContext context) {
    if (file == null) {
      return const Text(
        'Ch\u01B0a c\u00F3 \u1EA3nh. Vui l\u00F2ng ch\u1EE5p ho\u1EB7c ch\u1ECDn t\u1EEB th\u01B0 vi\u1EC7n.',
        style: TextStyle(
          color: AppColors.bodyText,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 18 / 12,
        ),
      );
    }

    return Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: AppColors.successText,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${file!.label} \u0111\u00E3 s\u1EB5n s\u00E0ng',
            style: const TextStyle(
              color: AppColors.inputText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 18 / 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedImagePreview extends StatelessWidget {
  const _SelectedImagePreview({required this.file, required this.isPortrait});

  final IdentityImageFile file;
  final bool isPortrait;

  @override
  Widget build(BuildContext context) {
    if (isPortrait) {
      return Center(
        child: ClipOval(
          child: SizedBox(
            width: 172,
            height: 172,
            child: Image.memory(file.bytes, fit: BoxFit.cover),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1.6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        child: Image.memory(file.bytes, fit: BoxFit.cover),
      ),
    );
  }
}

class _InstructionBox extends StatelessWidget {
  const _InstructionBox({required this.instruction});

  final String instruction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.infoSurface,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              instruction,
              style: const TextStyle(
                color: AppColors.bodyText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 18 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityInfoStepCard extends StatelessWidget {
  const _IdentityInfoStepCard({
    super.key,
    required this.formKey,
    required this.docNumberFieldKey,
    required this.issuedDateFieldKey,
    required this.issuedPlaceFieldKey,
    required this.docNumberController,
    required this.issuedDateController,
    required this.issuedPlaceController,
    required this.docNumberFocusNode,
    required this.issuedDateFocusNode,
    required this.issuedPlaceFocusNode,
    required this.issuedDate,
    required this.onPickIssuedDate,
  });

  final GlobalKey<FormState> formKey;
  final GlobalKey<FormFieldState<String>> docNumberFieldKey;
  final GlobalKey<FormFieldState<String>> issuedDateFieldKey;
  final GlobalKey<FormFieldState<String>> issuedPlaceFieldKey;
  final TextEditingController docNumberController;
  final TextEditingController issuedDateController;
  final TextEditingController issuedPlaceController;
  final FocusNode docNumberFocusNode;
  final FocusNode issuedDateFocusNode;
  final FocusNode issuedPlaceFocusNode;
  final DateTime? issuedDate;
  final VoidCallback onPickIssuedDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Th\u00F4ng tin CCCD',
              style: TextStyle(
                color: AppColors.darkBlue,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 22 / 16,
              ),
            ),
            const SizedBox(height: 14),
            const _InstructionBox(
              instruction:
                  'Nh\u1EADp ch\u00EDnh x\u00E1c th\u00F4ng tin \u0111\u01B0\u1EE3c in tr\u00EAn c\u0103n c\u01B0\u1EDBc c\u00F4ng d\u00E2n.',
            ),
            const SizedBox(height: 16),
            KeyedSubtree(
              key: const ValueKey('identity-doc-number-field'),
              child: TextFormField(
                key: docNumberFieldKey,
                controller: docNumberController,
                focusNode: docNumberFocusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                validator: validateIdentityDocumentNumber,
                decoration: const InputDecoration(
                  labelText: 'S\u1ED1 CCCD',
                  hintText: '079xxxxxxxxx',
                ),
              ),
            ),
            const SizedBox(height: 14),
            KeyedSubtree(
              key: const ValueKey('identity-issued-date-field'),
              child: TextFormField(
                key: issuedDateFieldKey,
                controller: issuedDateController,
                focusNode: issuedDateFocusNode,
                readOnly: true,
                onTap: onPickIssuedDate,
                validator: (_) => validateIdentityIssuedDate(issuedDate),
                decoration: const InputDecoration(
                  labelText: 'Ng\u00E0y c\u1EA5p',
                  hintText: 'dd/MM/yyyy',
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 14),
            KeyedSubtree(
              key: const ValueKey('identity-issued-place-field'),
              child: TextFormField(
                key: issuedPlaceFieldKey,
                controller: issuedPlaceController,
                focusNode: issuedPlaceFocusNode,
                textInputAction: TextInputAction.done,
                minLines: 1,
                maxLines: 2,
                maxLength: 255,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                validator: validateIdentityIssuedPlace,
                decoration: const InputDecoration(
                  labelText: 'N\u01A1i c\u1EA5p',
                  hintText: 'Nh\u1EADp n\u01A1i c\u1EA5p tr\u00EAn CCCD',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortraitPreview extends StatelessWidget {
  const _PortraitPreview();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 172,
        height: 172,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF5F5F5),
          border: Border.all(color: const Color(0xFFE8E8EF)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.person_rounded,
              color: Color(0xFFC5C7D4),
              size: 108,
            ),
            Positioned(
              right: 14,
              bottom: 18,
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdCardPreview extends StatelessWidget {
  const _IdCardPreview({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.inputText,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 15 / 11,
          ),
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 1.6,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F0F0),
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              border: Border.all(
                color: AppColors.cardBorder,
                style: BorderStyle.solid,
              ),
            ),
            child: CustomPaint(painter: _IdPreviewPainter()),
          ),
        ),
      ],
    );
  }
}

class _IdPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF7AD8EA);
    final linePaint = Paint()
      ..color = const Color(0xFF24AFCB)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.62,
        height: size.height * 0.5,
      ),
      const Radius.circular(6),
    );

    canvas.drawRRect(cardRect, bgPaint);
    final left = cardRect.outerRect.left + 16;
    final top = cardRect.outerRect.top + 20;
    canvas.drawRect(
      Rect.fromLTWH(left, top + 22, size.width * 0.16, size.height * 0.19),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
    for (var i = 0; i < 4; i++) {
      final y = top + 24 + i * 14;
      canvas.drawLine(
        Offset(left + size.width * 0.22, y),
        Offset(left + size.width * (0.46 + i * 0.02), y),
        linePaint,
      );
    }
    canvas.drawLine(
      Offset(left + size.width * 0.22, top + 8),
      Offset(left + size.width * 0.5, top + 8),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReviewStepCard extends StatelessWidget {
  const _ReviewStepCard({
    required this.portraitImage,
    required this.frontIdImage,
    required this.backIdImage,
    required this.docNumber,
    required this.issuedDate,
    required this.issuedPlace,
    required this.onEditStep,
  });

  final IdentityImageFile? portraitImage;
  final IdentityImageFile? frontIdImage;
  final IdentityImageFile? backIdImage;
  final String docNumber;
  final DateTime? issuedDate;
  final String issuedPlace;
  final ValueChanged<IdentityDocumentStep> onEditStep;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'X\u00E1c nh\u1EADn h\u1ED3 s\u01A1',
            style: AppTypography.sectionTitle,
          ),
          const SizedBox(height: 12),
          _ReviewRow(
            key: const ValueKey('identity-review-portrait'),
            title: '\u1EA2nh ch\u00E2n dung',
            image: portraitImage,
            isPortrait: true,
            isReady: portraitImage != null,
            onEdit: () => onEditStep(IdentityDocumentStep.portrait),
          ),
          _ReviewRow(
            key: const ValueKey('identity-review-front-id'),
            title: 'CCCD m\u1EB7t tr\u01B0\u1EDBc',
            image: frontIdImage,
            isPortrait: false,
            isReady: frontIdImage != null,
            onEdit: () => onEditStep(IdentityDocumentStep.frontId),
          ),
          _ReviewRow(
            key: const ValueKey('identity-review-back-id'),
            title: 'CCCD m\u1EB7t sau',
            image: backIdImage,
            isPortrait: false,
            isReady: backIdImage != null,
            onEdit: () => onEditStep(IdentityDocumentStep.backId),
          ),
          const SizedBox(height: 4),
          _ReviewIdentityInfoRow(
            docNumber: docNumber,
            issuedDate: issuedDate,
            issuedPlace: issuedPlace,
            onEdit: () => onEditStep(IdentityDocumentStep.identityInfo),
          ),
        ],
      ),
    );
  }
}

class _ReviewIdentityInfoRow extends StatelessWidget {
  const _ReviewIdentityInfoRow({
    required this.docNumber,
    required this.issuedDate,
    required this.issuedPlace,
    required this.onEdit,
  });

  final String docNumber;
  final DateTime? issuedDate;
  final String issuedPlace;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('identity-review-info'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.successText,
            size: 20,
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.infoSurface,
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
            ),
            child: const Icon(
              Icons.badge_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Th\u00F4ng tin CCCD',
                  style: AppTypography.cardTitle,
                ),
                const SizedBox(height: 6),
                _ReviewIdentityValue(label: 'S\u1ED1 CCCD', value: docNumber),
                const SizedBox(height: 5),
                _ReviewIdentityValue(
                  label: 'Ng\u00E0y c\u1EA5p',
                  value: issuedDate == null
                      ? ''
                      : formatIdentityIssuedDate(issuedDate!),
                ),
                const SizedBox(height: 5),
                _ReviewIdentityValue(
                  label: 'N\u01A1i c\u1EA5p',
                  value: issuedPlace,
                ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey('identity-review-info-edit'),
            onPressed: onEdit,
            child: const Text('S\u1EEDa'),
          ),
        ],
      ),
    );
  }
}

class _ReviewIdentityValue extends StatelessWidget {
  const _ReviewIdentityValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.metaLabel),
        const SizedBox(height: 1),
        Text(value, style: AppTypography.metaValue),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    super.key,
    required this.title,
    required this.image,
    required this.isPortrait,
    required this.isReady,
    required this.onEdit,
  });

  final String title;
  final IdentityImageFile? image;
  final bool isPortrait;
  final bool isReady;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            isReady ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: isReady ? AppColors.successText : AppColors.danger,
            size: 20,
          ),
          const SizedBox(width: 10),
          _ReviewThumbnail(file: image, title: title, isPortrait: isPortrait),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.inputText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 20 / 14,
              ),
            ),
          ),
          TextButton(onPressed: onEdit, child: const Text('S\u1EEDa')),
        ],
      ),
    );
  }
}

class _ReviewThumbnail extends StatelessWidget {
  const _ReviewThumbnail({
    required this.file,
    required this.title,
    required this.isPortrait,
  });

  final IdentityImageFile? file;
  final String title;
  final bool isPortrait;

  @override
  Widget build(BuildContext context) {
    final content = file == null
        ? const Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.cardBorder,
            size: 22,
          )
        : Image.memory(file!.bytes, fit: BoxFit.cover);

    final thumbnail = isPortrait
        ? ClipOval(child: SizedBox(width: 44, height: 44, child: content))
        : ClipRRect(
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
            child: SizedBox(width: 56, height: 40, child: content),
          );

    return InkWell(
      onTap: file == null
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      _IdentityImagePreviewPage(title: title, file: file!),
                ),
              );
            },
      borderRadius: BorderRadius.circular(isPortrait ? 22 : 6),
      child: thumbnail,
    );
  }
}

class _IdentityImagePreviewPage extends StatelessWidget {
  const _IdentityImagePreviewPage({required this.title, required this.file});

  final String title;
  final IdentityImageFile file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Image.memory(file.bytes, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.showBackButton,
    required this.isEnabled,
    required this.isLoading,
    required this.actionLabel,
    required this.onBack,
    required this.onContinue,
  });

  final bool showBackButton;
  final bool isEnabled;
  final bool isLoading;
  final String actionLabel;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.45)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (showBackButton) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.bodyText,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                  ),
                  child: const Text('Tr\u1EDF v\u1EC1'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: ElevatedButton(
                key: const ValueKey('identity-action-continue'),
                onPressed: isEnabled ? onContinue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.actionBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFD8D9E5),
                  disabledForegroundColor: AppColors.bodyText,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        actionLabel,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
