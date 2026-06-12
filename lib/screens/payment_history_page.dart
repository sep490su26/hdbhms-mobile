import 'package:flutter/material.dart';

import '../models/tenant_invoice_model.dart';
import '../services/tenant_invoice_service.dart';
import '../theme/app_colors.dart';
import 'notification_list_screen.dart';
import 'tenant_profile_screen.dart';

class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({super.key});

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  final TenantInvoiceService _invoiceService = const TenantInvoiceService();
  final TextEditingController _searchController = TextEditingController();
  late Future<List<TenantInvoice>> _invoicesFuture;
  String _selectedMonthKey = 'all';

  @override
  void initState() {
    super.initState();
    _invoicesFuture = _invoiceService.fetchMyInvoices();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _invoicesFuture = _invoiceService.fetchMyInvoices();
    });
  }

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
                _HistoryHeader(onRefresh: _reload),
                Expanded(
                  child: FutureBuilder<List<TenantInvoice>>(
                    future: _invoicesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const _HistoryLoading();
                      }
                      if (snapshot.hasError) {
                        return _HistoryError(
                          message: snapshot.error is TenantInvoiceException
                              ? (snapshot.error as TenantInvoiceException)
                                    .message
                              : 'Không tải được lịch sử thanh toán.',
                          onRetry: _reload,
                        );
                      }
                      final paidInvoices = _paidInvoices(
                        snapshot.data ?? const [],
                      );
                      final monthOptions = _monthOptions(paidInvoices);
                      if (_selectedMonthKey != 'all' &&
                          !monthOptions.any(
                            (item) => item.key == _selectedMonthKey,
                          )) {
                        _selectedMonthKey = 'all';
                      }
                      final filteredInvoices = _filterInvoices(paidInvoices);

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(14, 22, 14, 22),
                        child: Column(
                          children: [
                            _SearchField(controller: _searchController),
                            const SizedBox(height: 16),
                            _FilterRow(
                              selectedMonthKey: _selectedMonthKey,
                              monthOptions: monthOptions,
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedMonthKey = value);
                              },
                            ),
                            const SizedBox(height: 24),
                            if (filteredInvoices.isEmpty)
                              _HistoryEmpty(
                                hasAnyPaidInvoice: paidInvoices.isNotEmpty,
                                onClearFilter: () {
                                  _searchController.clear();
                                  setState(() => _selectedMonthKey = 'all');
                                },
                              )
                            else
                              _HistoryListCard(invoices: filteredInvoices),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const _HistoryBottomNavigation(),
    );
  }

  List<TenantInvoice> _paidInvoices(List<TenantInvoice> invoices) {
    final result = invoices.where((invoice) => invoice.isPaid).toList()
      ..sort((a, b) => _historyDate(b).compareTo(_historyDate(a)));
    return List.unmodifiable(result);
  }

  List<TenantInvoice> _filterInvoices(List<TenantInvoice> invoices) {
    final keyword = _searchController.text.trim().toLowerCase();
    return invoices
        .where((invoice) {
          final date = _historyDate(invoice);
          final monthMatches =
              _selectedMonthKey == 'all' ||
              _monthKey(date) == _selectedMonthKey ||
              invoice.billingPeriod == _selectedMonthKey;
          if (!monthMatches) return false;
          if (keyword.isEmpty) return true;
          final haystack = [
            invoice.title,
            invoice.invoiceCode,
            invoice.roomCode,
            invoice.contractCode,
            invoice.billingPeriod,
            _formatAmount(_historyAmount(invoice)),
            ...invoice.lines.map((line) => line.description),
          ].join(' ').toLowerCase();
          return haystack.contains(keyword);
        })
        .toList(growable: false);
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
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
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.deepBlue,
              size: 24,
            ),
            tooltip: 'Quay lại',
          ),
          const Expanded(
            child: Text(
              'Lịch sử thanh toán',
              style: TextStyle(
                color: AppColors.deepBlue,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 20 / 16,
              ),
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.inputText,
              size: 22,
            ),
            tooltip: 'Làm mới',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NotificationListScreen(),
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.inputText,
              size: 24,
            ),
            tooltip: 'Thông báo',
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Tìm theo mã hóa đơn, phòng, nội dung...',
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.bodyText,
          size: 21,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: controller.clear,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
        filled: true,
        fillColor: const Color(0xFFF1F1F1),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(7),
        ),
      ),
      style: const TextStyle(
        color: AppColors.inputText,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selectedMonthKey,
    required this.monthOptions,
    required this.onChanged,
  });

  final String selectedMonthKey;
  final List<_MonthOption> monthOptions;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      const _MonthOption(key: 'all', label: 'Tất cả tháng'),
      ...monthOptions,
    ];
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 45,
            child: DropdownButtonFormField<String>(
              key: ValueKey(selectedMonthKey),
              initialValue: selectedMonthKey,
              items: options
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.key,
                      child: Text(item.label),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.deepBlue,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF1F1F1),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(
                color: AppColors.deepBlue,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 80,
          height: 45,
          decoration: BoxDecoration(
            color: const Color(0xFFA7B4FF),
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.filter_list_rounded,
                size: 18,
                color: AppColors.deepBlue,
              ),
              SizedBox(width: 5),
              Text(
                'Lọc',
                style: TextStyle(
                  color: AppColors.deepBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 20 / 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryListCard extends StatelessWidget {
  const _HistoryListCard({required this.invoices});

  final List<TenantInvoice> invoices;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var index = 0; index < invoices.length; index++) ...[
            _HistoryItem(invoice: invoices[index]),
            if (index < invoices.length - 1) const _HistoryDivider(),
          ],
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.invoice});

  final TenantInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final amount = _historyAmount(invoice);
    final date = _historyDate(invoice);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 16, 19),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: Color(0xFFEDEFFF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _historyIcon(invoice),
              color: AppColors.deepBlue,
              size: 25,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.inputText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 22 / 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (invoice.roomCode.isNotEmpty)
                      'Phòng ${invoice.roomCode}',
                    _formatDate(date),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.bodyText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 18 / 13,
                  ),
                ),
                if (invoice.invoiceCode.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    invoice.invoiceCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.hintText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatAmount(amount),
                style: const TextStyle(
                  color: AppColors.deepBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 24 / 18,
                ),
              ),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD7FBE4),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF16A34A),
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'ĐÃ THANH TOÁN',
                      style: TextStyle(
                        color: Color(0xFF15803D),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 13 / 10,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryDivider extends StatelessWidget {
  const _HistoryDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: Color(0xFFE9E9EF));
  }
}

class _HistoryLoading extends StatelessWidget {
  const _HistoryLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.deepBlue),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});

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
              color: Color(0xFFC8171F),
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.bodyText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
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

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({
    required this.hasAnyPaidInvoice,
    required this.onClearFilter,
  });

  final bool hasAnyPaidInvoice;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.75)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            color: AppColors.deepBlue,
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            hasAnyPaidInvoice
                ? 'Không có giao dịch phù hợp bộ lọc.'
                : 'Chưa có lịch sử thanh toán.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.inputText,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (hasAnyPaidInvoice) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: onClearFilter,
              child: const Text('Xóa bộ lọc'),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryBottomNavigation extends StatelessWidget {
  const _HistoryBottomNavigation();

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(
              color: AppColors.cardBorder.withValues(alpha: 0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BottomNavItem(
                icon: Icons.home_outlined,
                label: 'Trang chủ',
                onTap: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
              const _BottomNavItem(
                icon: Icons.receipt_long_rounded,
                label: 'Hóa đơn',
                isSelected: true,
              ),
              const _BottomNavItem(
                icon: Icons.support_agent_outlined,
                label: 'Hỗ trợ',
              ),
              _BottomNavItem(
                icon: Icons.person_outline,
                label: 'Hồ sơ',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const TenantProfileScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.deepBlue : AppColors.bodyText;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFA7B4FF)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                height: 14 / 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthOption {
  const _MonthOption({required this.key, required this.label});

  final String key;
  final String label;
}

List<_MonthOption> _monthOptions(List<TenantInvoice> invoices) {
  final seen = <String>{};
  final options = <_MonthOption>[];
  for (final invoice in invoices) {
    final date = _historyDate(invoice);
    final key = _monthKey(date);
    if (seen.add(key)) {
      options.add(_MonthOption(key: key, label: _monthLabel(date)));
    }
  }
  return options;
}

DateTime _historyDate(TenantInvoice invoice) {
  return invoice.paidAt ??
      invoice.issuedAt ??
      invoice.dueDate ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

String _monthKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}';
}

String _monthLabel(DateTime date) {
  return 'Tháng ${date.month}/${date.year}';
}

String _formatDate(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return 'Chưa có ngày';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

int _historyAmount(TenantInvoice invoice) {
  if (invoice.paidAmount > 0) return invoice.paidAmount;
  return invoice.totalAmount;
}

String _formatAmount(int amount) {
  final value = amount.toString();
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

IconData _historyIcon(TenantInvoice invoice) {
  final lineTypes = invoice.lines.map((line) => line.lineType).toSet();
  if (lineTypes.contains('VIOLATION_FINE')) {
    return Icons.gavel_rounded;
  }
  if (lineTypes.contains('MAINTENANCE_COMPENSATION')) {
    return Icons.construction_rounded;
  }
  if (invoice.invoiceType == 'UTILITY') {
    return Icons.flash_on_outlined;
  }
  if (invoice.invoiceType == 'RENT') {
    return Icons.receipt_long_outlined;
  }
  return Icons.payments_outlined;
}
