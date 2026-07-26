import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/screens/notification/notification_list_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_request_screen.dart';

import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/models/rules/property_rule_model.dart';
import 'package:hdbhms_mobile/services/rules/property_rule_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/utils/currency_formatter.dart';
import 'package:hdbhms_mobile/widgets/tenant_bottom_navigation.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_notification_bell.dart';
import 'package:hdbhms_mobile/screens/payment/bill_selection_page.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_list_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_profile_screen.dart';

class PropertyRulesScreen extends StatefulWidget {
  const PropertyRulesScreen({
    super.key,
    this.ruleService = const PropertyRuleService(),
  });

  final PropertyRuleService ruleService;

  @override
  State<PropertyRulesScreen> createState() => _PropertyRulesScreenState();
}

class _PropertyRulesScreenState extends State<PropertyRulesScreen> {
  late Future<PropertyRulesResponse> _rulesFuture;

  @override
  void initState() {
    super.initState();
    _rulesFuture = _loadRules();
  }

  Future<PropertyRulesResponse> _loadRules() {
    return widget.ruleService.getRules();
  }

  void _retry() {
    setState(() {
      _rulesFuture = _loadRules();
    });
  }

  Future<void> _refresh() async {
    final future = _loadRules();
    setState(() {
      _rulesFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(
          header: const _RulesHeader(),
          child: FutureBuilder<PropertyRulesResponse>(
            future: _rulesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _RulesLoadingState();
              }

              if (snapshot.hasError) {
                return _RulesErrorState(
                  message: _messageForError(snapshot.error),
                  onRetry: _retry,
                );
              }

              final response = snapshot.data;
              if (response == null || response.items.isEmpty) {
                return _RulesEmptyState(onRetry: _retry);
              }

              return RefreshIndicator(
                color: AppColors.deepBlue,
                onRefresh: _refresh,
                child: _RulesContent(response: response),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: TenantBottomNavigation(
        activeTab: TenantBottomNavTab.home,
        onHomeTap: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        onBillsTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const BillSelectionPage()),
          );
        },
        onSupportTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const MaintenanceTicketListScreen(),
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
          MaterialPageRoute(builder: (context) => const TenantRequestScreen()),
        ),
      ),
    );
  }
}

class _RulesHeader extends StatelessWidget {
  const _RulesHeader();

  @override
  Widget build(BuildContext context) {
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
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.deepBlue,
              size: 24,
            ),
            tooltip: 'Trở về',
          ),
          const Expanded(
            child: Text('Nội quy nhà trọ', style: AppColors.topBarTitleStyle),
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
              size: 24,
            ),
            tooltip: 'Thông báo',
          ),
        ],
      ),
    );
  }
}

class _RulesContent extends StatelessWidget {
  const _RulesContent({required this.response});

  final PropertyRulesResponse response;

  @override
  Widget build(BuildContext context) {
    final sections = _groupRules(response.items);
    final fineRules = sections[RuleCategory.fine] ?? const <PropertyRule>[];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        _RulesBanner(response: response),
        const SizedBox(height: 24),
        const Text(
          'Để đảm bảo không gian sống an toàn, văn minh và tiện nghi cho tất cả cư dân, vui lòng tuân thủ các quy định dưới đây.',
          style: TextStyle(
            color: AppColors.bodyText,
            fontSize: 17,
            fontWeight: FontWeight.w400,
            height: 24 / 17,
          ),
        ),
        if (response.isFromCache) ...[
          const SizedBox(height: 10),
          const Text(
            'Đang hiển thị dữ liệu đã lưu gần nhất.',
            style: TextStyle(
              color: AppColors.deepBlue,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 16 / 12,
            ),
          ),
        ],
        const SizedBox(height: 28),
        for (final config in _normalSectionConfigs) ...[
          if (sections[config.category]?.isNotEmpty == true) ...[
            _RuleSection(config: config, rules: sections[config.category]!),
            const SizedBox(height: 24),
          ],
        ],
        if (fineRules.isNotEmpty) _FineSection(rules: fineRules),
      ],
    );
  }
}

class _RulesBanner extends StatelessWidget {
  const _RulesBanner({required this.response});

  final PropertyRulesResponse response;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveImageUrl(response.bannerImageUrl);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: SizedBox(
        height: 193,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isEmpty)
              const _HallwayPlaceholder()
            else
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _HallwayPlaceholder(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }
                  return const _HallwayPlaceholder();
                },
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.04),
                    Colors.black.withValues(alpha: 0.62),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 28,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CẬP NHẬT: ${_formatDate(response.updatedAt)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 17 / 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nội Quy Lưu Trú',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 29 / 24,
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

class _HallwayPlaceholder extends StatelessWidget {
  const _HallwayPlaceholder();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HallwayPainter(),
      child: Container(color: const Color(0xFF2F355F).withValues(alpha: 0.32)),
    );
  }
}

class _HallwayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wall = Paint()..color = const Color(0xFF4B4568);
    final floor = Paint()..color = const Color(0xFF1B1C34);
    final light = Paint()..color = const Color(0xFFE9D8C4);
    final door = Paint()..color = const Color(0xFF2D2341);
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRect(Offset.zero & size, wall);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.42, size.height * 0.08)
        ..lineTo(size.width * 0.58, size.height * 0.08)
        ..lineTo(size.width * 0.72, size.height)
        ..lineTo(size.width * 0.28, size.height)
        ..close(),
      floor,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.43, 0, size.width * 0.14, size.height),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );

    for (final x in [0.05, 0.2, 0.75, 0.9]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * x,
            size.height * 0.12,
            size.width * 0.12,
            size.height * 0.76,
          ),
          const Radius.circular(4),
        ),
        door,
      );
    }

    for (final x in [0.16, 0.81]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * x, size.height * 0.32),
          width: 18,
          height: 28,
        ),
        light,
      );
    }

    canvas.drawLine(
      Offset(size.width * 0.5, 0),
      Offset(size.width * 0.5, size.height),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RuleSection extends StatelessWidget {
  const _RuleSection({required this.config, required this.rules});

  final _RuleSectionConfig config;
  final List<PropertyRule> rules;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _sectionDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
            child: Row(
              children: [
                Icon(config.icon, color: AppColors.deepBlue, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(config.title, style: AppTypography.sectionTitle),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFE4E1E8), height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 23, 24, 23),
            child: Column(
              children: [
                for (var i = 0; i < rules.length; i++) ...[
                  if (i > 0) const SizedBox(height: 20),
                  _RuleRow(rule: rules[i], fallbackIndex: i + 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule, required this.fallbackIndex});

  final PropertyRule rule;
  final int fallbackIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 40,
          child: Text(
            '${_ruleNumber(rule, fallbackIndex)}.',
            style: const TextStyle(
              color: AppColors.deepBlue,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 23 / 16,
            ),
          ),
        ),
        Expanded(
          child: Text(
            _ruleText(rule),
            style: const TextStyle(
              color: AppColors.inputText,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 23 / 16,
            ),
          ),
        ),
      ],
    );
  }
}

class _FineSection extends StatelessWidget {
  const _FineSection({required this.rules});

  final List<PropertyRule> rules;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EF),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: const Color(0xFFFFB8B2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 18),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFC8171F),
                  size: 24,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Các khoản phạt',
                    style: TextStyle(
                      color: Color(0xFFC8171F),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 24 / 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFFFD4D0), height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              children: [
                for (var i = 0; i < rules.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  _FineTile(rule: rules[i]),
                ],
                const SizedBox(height: 18),
                const Text(
                  '* Các khoản phạt sẽ được cộng trực tiếp vào hóa đơn tiền phòng tháng kế tiếp.',
                  style: TextStyle(
                    color: Color(0xFFC8171F),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    height: 18 / 13,
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

class _FineTile extends StatelessWidget {
  const _FineTile({required this.rule});

  final PropertyRule rule;

  @override
  Widget build(BuildContext context) {
    final fineText = _fineText(rule);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.do_not_disturb_on_outlined,
                color: Color(0xFFC8171F),
                size: 23,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  _display(rule.title),
                  style: const TextStyle(
                    color: Color(0xFFC8171F),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 20 / 16,
                  ),
                ),
              ),
              if (fineText.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  fineText,
                  style: const TextStyle(
                    color: Color(0xFFC8171F),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 20 / 16,
                  ),
                ),
              ],
            ],
          ),
          if (rule.description.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Text(
                rule.description.trim(),
                style: TextStyle(
                  color: const Color(0xFFC8171F),
                  fontSize: 13,
                  fontStyle: rule.defaultFineAmount == null
                      ? FontStyle.italic
                      : FontStyle.normal,
                  fontWeight: FontWeight.w500,
                  height: 18 / 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RulesLoadingState extends StatelessWidget {
  const _RulesLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.deepBlue),
    );
  }
}

class _RulesEmptyState extends StatelessWidget {
  const _RulesEmptyState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateMessage(
      icon: Icons.rule_folder_outlined,
      title: 'Chưa có nội quy',
      onRetry: onRetry,
    );
  }
}

class _RulesErrorState extends StatelessWidget {
  const _RulesErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateMessage(
      icon: Icons.error_outline_rounded,
      title: message,
      onRetry: onRetry,
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.deepBlue,
      onRefresh: () async => onRetry(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 140),
          Icon(icon, color: AppColors.deepBlue, size: 48),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.inputText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 21 / 16,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleSectionConfig {
  const _RuleSectionConfig({
    required this.category,
    required this.title,
    required this.icon,
  });

  final RuleCategory category;
  final String title;
  final IconData icon;
}

const _normalSectionConfigs = [
  _RuleSectionConfig(
    category: RuleCategory.general,
    title: 'Quy định chung',
    icon: Icons.info_outline_rounded,
  ),
  _RuleSectionConfig(
    category: RuleCategory.security,
    title: 'An ninh',
    icon: Icons.shield_outlined,
  ),
  _RuleSectionConfig(
    category: RuleCategory.hygiene,
    title: 'Vệ sinh',
    icon: Icons.cleaning_services_outlined,
  ),
  _RuleSectionConfig(
    category: RuleCategory.utility,
    title: 'Tiện ích',
    icon: Icons.settings_input_component_outlined,
  ),
];

Map<RuleCategory, List<PropertyRule>> _groupRules(List<PropertyRule> rules) {
  final grouped = <RuleCategory, List<PropertyRule>>{};
  for (final rule in rules) {
    grouped.putIfAbsent(rule.category, () => []).add(rule);
  }
  for (final values in grouped.values) {
    values.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }
  return grouped;
}

BoxDecoration _sectionDecoration() {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppColors.radiusMd),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 14,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

String _ruleNumber(PropertyRule rule, int fallbackIndex) {
  final value = rule.sortOrder == 9999 ? fallbackIndex : rule.sortOrder;
  return value.toString().padLeft(2, '0');
}

String _ruleText(PropertyRule rule) {
  final parts = [
    rule.title.trim(),
    rule.description.trim(),
  ].where((part) => part.isNotEmpty).toList(growable: false);
  return parts.isEmpty ? 'Chưa cập nhật' : parts.join('. ');
}

String _fineText(PropertyRule rule) {
  final amount = rule.defaultFineAmount;
  if (amount == null) {
    return '';
  }
  final money = CurrencyFormatter.vnd(amount).replaceAll(' đ', 'đ');
  final unit = rule.fineUnit.trim();
  return unit.isEmpty ? money : '$money/$unit';
}

String _display(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? 'Chưa cập nhật' : trimmed;
}

String _formatDate(DateTime? date) {
  if (date == null) {
    return 'Chưa cập nhật';
  }
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String _resolveImageUrl(String value) {
  final url = value.trim();
  if (url.isEmpty) {
    return '';
  }
  final uri = Uri.tryParse(url);
  if (uri != null && uri.hasScheme) {
    return url;
  }

  final baseUri = Uri.parse(ApiConfig.baseUrl);
  if (url.startsWith('/')) {
    return baseUri.replace(path: url).toString();
  }
  final base = ApiConfig.baseUrl.endsWith('/')
      ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
      : ApiConfig.baseUrl;
  return '$base/$url';
}

String _messageForError(Object? error) {
  if (error is PropertyRuleException) {
    return error.message;
  }
  return 'Không tải được nội quy';
}
