import 'package:flutter/material.dart';

import '../models/identity_image_file.dart';
import '../models/onboarding_state.dart';
import '../services/auth_service.dart';
import '../services/file_upload_service.dart';
import '../services/home_service.dart';
import '../services/identity_service.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';

enum IdentityDocumentStep {
  portrait,
  frontId,
  backId,
  confirm;

  String get title {
    switch (this) {
      case IdentityDocumentStep.portrait:
        return '\u1EA2nh ch\u00E2n dung';
      case IdentityDocumentStep.frontId:
        return 'CCCD m\u1EB7t tr\u01B0\u1EDBc';
      case IdentityDocumentStep.backId:
        return 'CCCD m\u1EB7t sau';
      case IdentityDocumentStep.confirm:
        return 'X\u00E1c nh\u1EADn';
    }
  }
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
  late final FileUploadService _fileUploadService;
  late final IdentityService _identityService;
  bool _isSubmitting = false;

  bool get _hasAllImages =>
      _portraitImage != null && _frontIdImage != null && _backIdImage != null;

  bool get _canContinue {
    if (_loadingStep != null || _isSubmitting) {
      return false;
    }
    return switch (_currentStep) {
      IdentityDocumentStep.portrait => _portraitImage != null,
      IdentityDocumentStep.frontId => _frontIdImage != null,
      IdentityDocumentStep.backId => _backIdImage != null,
      IdentityDocumentStep.confirm => _hasAllImages,
    };
  }

  @override
  void initState() {
    super.initState();
    _fileUploadService =
        widget.fileUploadService ?? ImagePickerFileUploadService();
    _identityService = widget.identityService ?? const IdentityService();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isRequired && !_isSubmitting,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: !widget.isRequired,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.deepBlue,
          elevation: 0,
          title: const Text(
            'Ho\u00E0n t\u1EA5t h\u1ED3 s\u01A1',
            style: TextStyle(
              color: AppColors.deepBlue,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.help_outline_rounded, size: 21),
              tooltip: 'Tr\u1EE3 gi\u00FAp',
            ),
          ],
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
                          onStepSelected: _selectStep,
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
      case IdentityDocumentStep.confirm:
        return _ReviewStepCard(
          portraitImage: _portraitImage,
          frontIdImage: _frontIdImage,
          backIdImage: _backIdImage,
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
      IdentityDocumentStep.confirm => IdentityDocumentStep.backId,
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

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _identityService.uploadIdentity(
        portrait: _portraitImage!,
        frontId: _frontIdImage!,
        backId: _backIdImage!,
      );

      if (!mounted) {
        return;
      }

      if (widget.onCompleted != null) {
        _showMessage('Hoàn tất hồ sơ thành công');
        widget.onCompleted!();
        return;
      }

      if (result.profileCompleted ||
          result.onboarding.nextStep == OnboardingState.home) {
        _showMessage('Hoàn tất hồ sơ thành công');
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              authService: widget.authService,
              homeService: widget.homeService,
            ),
          ),
        );
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
      IdentityDocumentStep.backId => IdentityDocumentStep.confirm,
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
      IdentityDocumentStep.confirm => _validateImages(),
    };
  }

  String? _validateImages() {
    if (_portraitImage == null) {
      return 'Vui lòng upload đủ ảnh chân dung và 2 mặt CCCD';
    }
    if (_frontIdImage == null) {
      return 'Vui lòng upload đủ ảnh chân dung và 2 mặt CCCD';
    }
    if (_backIdImage == null) {
      return 'Vui lòng upload đủ ảnh chân dung và 2 mặt CCCD';
    }
    return null;
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
            style: TextStyle(
              color: AppColors.deepBlue,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 28 / 22,
            ),
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
    required this.onStepSelected,
  });

  final IdentityDocumentStep currentStep;
  final bool portraitDone;
  final bool frontDone;
  final bool backDone;
  final ValueChanged<IdentityDocumentStep> onStepSelected;

  @override
  Widget build(BuildContext context) {
    final steps = IdentityDocumentStep.values;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (var index = 0; index < steps.length; index++) ...[
            Expanded(
              child: _StepPill(
                step: steps[index],
                status: _statusFor(steps[index]),
              ),
            ),
            if (index != steps.length - 1)
              Container(width: 10, height: 2, color: const Color(0xFFE0E3F2)),
          ],
        ],
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
      case IdentityDocumentStep.confirm:
        return portraitDone && frontDone && backDone
            ? _StepStatus.done
            : _StepStatus.pending;
    }
  }
}

enum _StepStatus { active, done, pending }

class _StepPill extends StatelessWidget {
  const _StepPill({required this.step, required this.status});

  final IdentityDocumentStep step;
  final _StepStatus status;

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
            color: isActive || isDone ? AppColors.deepBlue : AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive || isDone
                  ? AppColors.deepBlue
                  : AppColors.cardBorder,
            ),
          ),
          child: Icon(
            isDone ? Icons.check_rounded : Icons.circle,
            color: isActive || isDone ? Colors.white : AppColors.cardBorder,
            size: isDone ? 17 : 8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          step.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isActive || isDone ? AppColors.deepBlue : AppColors.bodyText,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
            height: 13 / 10,
          ),
        ),
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
        borderRadius: BorderRadius.circular(12),
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
              color: AppColors.deepBlue,
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.deepBlue,
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
    foregroundColor: AppColors.deepBlue,
    side: const BorderSide(color: AppColors.deepBlue),
    minimumSize: const Size.fromHeight(44),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          color: Color(0xFF16A34A),
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
        Text(
          '${(file!.sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
          style: const TextStyle(
            color: AppColors.bodyText,
            fontSize: 12,
            fontWeight: FontWeight.w500,
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
        borderRadius: BorderRadius.circular(8),
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
        color: const Color(0xFFF5F6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E3F7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.deepBlue,
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
                  color: AppColors.deepBlue,
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
              borderRadius: BorderRadius.circular(8),
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
    required this.onEditStep,
  });

  final IdentityImageFile? portraitImage;
  final IdentityImageFile? frontIdImage;
  final IdentityImageFile? backIdImage;
  final ValueChanged<IdentityDocumentStep> onEditStep;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
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
            style: TextStyle(
              color: AppColors.deepBlue,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 22 / 17,
            ),
          ),
          const SizedBox(height: 12),
          _ReviewRow(
            title: '\u1EA2nh ch\u00E2n dung',
            image: portraitImage,
            isPortrait: true,
            isReady: portraitImage != null,
            onEdit: () => onEditStep(IdentityDocumentStep.portrait),
          ),
          _ReviewRow(
            title: 'CCCD m\u1EB7t tr\u01B0\u1EDBc',
            image: frontIdImage,
            isPortrait: false,
            isReady: frontIdImage != null,
            onEdit: () => onEditStep(IdentityDocumentStep.frontId),
          ),
          _ReviewRow(
            title: 'CCCD m\u1EB7t sau',
            image: backIdImage,
            isPortrait: false,
            isReady: backIdImage != null,
            onEdit: () => onEditStep(IdentityDocumentStep.backId),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
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
            color: isReady ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
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
            borderRadius: BorderRadius.circular(6),
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
                      borderRadius: BorderRadius.circular(8),
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
                onPressed: isEnabled ? onContinue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFD8D9E5),
                  disabledForegroundColor: AppColors.bodyText,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
