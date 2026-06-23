import 'package:flutter/material.dart';
import '../../models/payment/tenant_invoice_model.dart';
import '../../services/payment/tenant_invoice_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/tenant_bottom_navigation.dart';
import '../../widgets/app_screen_shell.dart';
import '../maintenance/maintenance_ticket_list_screen.dart';
import '../notification/notification_list_screen.dart';
import '../profile_request/tenant_profile_screen.dart';
import '../profile_request/tenant_request_screen.dart';
import 'payment_history_page.dart';
import 'qr_payment_page.dart';

class BillSelectionPage extends StatefulWidget {
  const BillSelectionPage({super.key});

  @override
  State<BillSelectionPage> createState() => _BillSelectionPageState();
}

class _BillSelectionPageState extends State<BillSelectionPage> {
  _BillFilter _activeFilter = _BillFilter.all;
  final TenantInvoiceService _invoiceService = const TenantInvoiceService();
  late Future<List<TenantInvoice>> _invoicesFuture;

  @override
  void initState() {
    super.initState();
    _invoicesFuture = _invoiceService.fetchMyInvoices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(
          header: const _BillHeader(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tất cả hoá đơn', style: AppTypography.pageTitle),
                const SizedBox(height: 14),
                _BillFilterBar(
                  active: _activeFilter,
                  onChanged: (filter) {
                    setState(() => _activeFilter = filter);
                  },
                ),
                const SizedBox(height: 18),
                FutureBuilder<List<TenantInvoice>>(
                  future: _invoicesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _BillLoadingState();
                    }
                    if (snapshot.hasError) {
                      return _BillErrorState(
                        message: snapshot.error is TenantInvoiceException
                            ? (snapshot.error as TenantInvoiceException).message
                            : 'Không tải được hóa đơn. Vui lòng thử lại.',
                        onRetry: _reloadInvoices,
                      );
                    }
                    final visibleInvoices = (snapshot.data ?? const [])
                        .where((invoice) => invoice.isTenantVisible)
                        .toList();
                    return Column(
                      children: _buildFilteredBills(context, visibleInvoices),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: TenantBottomNavigation(
        activeTab: TenantBottomNavTab.bills,
        onHomeTap: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        onBillsTap: () {},
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

  void _reloadInvoices() {
    setState(() {
      _invoicesFuture = _invoiceService.fetchMyInvoices();
    });
  }

  void _openPayment(BuildContext context, TenantInvoice invoice) {
    if (invoice.canPay &&
        (invoice.qrCode.isNotEmpty || invoice.transferDescription.isNotEmpty)) {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => QrPaymentPage(invoice: invoice),
            ),
          )
          .then((_) => _reloadInvoices());
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hóa đơn chưa thể thanh toán. Vui lòng liên hệ quản lý.'),
      ),
    );
  }

  List<Widget> _buildFilteredBills(
    BuildContext context,
    List<TenantInvoice> invoices,
  ) {
    final pendingBills = _withSpacing(
      invoices
          .where((invoice) => !invoice.isPaid)
          .map(
            (invoice) => _PendingBillCard(
              invoice: invoice,
              onTap: () => _openPayment(context, invoice),
            ),
          )
          .toList(),
      16,
    );

    final paidBills = _withSpacing(
      invoices
          .where((invoice) => invoice.isPaid)
          .map((invoice) => _PaidBillCard(invoice: invoice))
          .toList(),
      12,
    );

    final historyButton = _ViewHistoryButton(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const PaymentHistoryPage()),
        );
      },
    );

    if (invoices.isEmpty) {
      return const [_BillEmptyState(message: 'Chưa có hóa đơn đã phát hành.')];
    }

    return switch (_activeFilter) {
      _BillFilter.all => [
        if (pendingBills.isNotEmpty) ...pendingBills,
        if (paidBills.isNotEmpty) ...[
          const SizedBox(height: 28),
          const _PaidDivider(),
          const SizedBox(height: 22),
          ...paidBills,
        ],
        const SizedBox(height: 18),
        historyButton,
      ],
      _BillFilter.unpaid =>
        pendingBills.isEmpty
            ? const [
                _BillEmptyState(message: 'Không có hóa đơn chờ thanh toán.'),
              ]
            : pendingBills,
      _BillFilter.paid =>
        paidBills.isEmpty
            ? const [_BillEmptyState(message: 'Chưa có hóa đơn đã thanh toán.')]
            : [...paidBills, const SizedBox(height: 18), historyButton],
    };
  }
}

enum _BillFilter { all, unpaid, paid }

List<Widget> _withSpacing(List<Widget> widgets, double spacing) {
  if (widgets.isEmpty) return const [];
  return [
    for (var index = 0; index < widgets.length; index++) ...[
      if (index > 0) SizedBox(height: spacing),
      widgets[index],
    ],
  ];
}

String _formatAmount(int amount) {
  final raw = amount.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index += 1) {
    if (index > 0 && (raw.length - index) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(raw[index]);
  }
  return '${amount < 0 ? '-' : ''}${buffer.toString()}đ';
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Chưa có hạn';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _lineLabel(TenantInvoiceLine line) {
  if (line.lineType == 'VIOLATION_FINE') {
    return 'Phạt vi phạm nội quy: ${_formatAmount(line.amount)}';
  }
  if (line.lineType == 'MAINTENANCE_COMPENSATION') {
    return 'Bồi thường bảo trì: ${_formatAmount(line.amount)}';
  }
  return '${line.description}: ${_formatAmount(line.amount)}';
}

class _BillLoadingState extends StatelessWidget {
  const _BillLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _BillErrorState extends StatelessWidget {
  const _BillErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB5AE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFFB42318),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _BillEmptyState extends StatelessWidget {
  const _BillEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.bodyText,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BillFilterBar extends StatelessWidget {
  const _BillFilterBar({required this.active, required this.onChanged});

  final _BillFilter active;
  final ValueChanged<_BillFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _BillFilterChip(
            label: 'Tất cả',
            icon: Icons.list_rounded,
            isActive: active == _BillFilter.all,
            onTap: () => onChanged(_BillFilter.all),
          ),
          const SizedBox(width: 8),
          _BillFilterChip(
            label: 'Chưa thanh toán',
            icon: Icons.pending_actions_rounded,
            isActive: active == _BillFilter.unpaid,
            onTap: () => onChanged(_BillFilter.unpaid),
          ),
          const SizedBox(width: 8),
          _BillFilterChip(
            label: 'Đã thanh toán',
            icon: Icons.task_alt_rounded,
            isActive: active == _BillFilter.paid,
            onTap: () => onChanged(_BillFilter.paid),
          ),
        ],
      ),
    );
  }
}

class _BillFilterChip extends StatelessWidget {
  const _BillFilterChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.deepBlue.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive
                ? AppColors.deepBlue
                : AppColors.cardBorder.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? AppColors.deepBlue : AppColors.bodyText,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.deepBlue : AppColors.bodyText,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                height: 16 / 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillHeader extends StatelessWidget {
  const _BillHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
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
            child: Text(
              'Hóa đơn',
              style: TextStyle(
                color: AppColors.deepBlue,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 20 / 16,
              ),
            ),
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

class _PendingBillCard extends StatelessWidget {
  const _PendingBillCard({required this.invoice, required this.onTap});

  final TenantInvoice invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 98),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 3,
                    decoration: const BoxDecoration(
                      color: AppColors.deepBlue,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(10),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  invoice.title,
                                  style: const TextStyle(
                                    color: AppColors.inputText,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    height: 20 / 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _formatAmount(
                                  invoice.remainingAmount > 0
                                      ? invoice.remainingAmount
                                      : invoice.totalAmount,
                                ),
                                style: const TextStyle(
                                  color: AppColors.deepBlue,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  height: 21 / 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD6D6),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'CHỜ THANH TOÁN',
                                  style: TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    height: 14 / 10,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Flexible(
                                child: Text(
                                  'Hạn: ${_formatDate(invoice.dueDate)}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.bodyText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    height: 15 / 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.apartment_rounded,
                                color: AppColors.bodyText,
                                size: 14,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                invoice.roomCode.isEmpty
                                    ? 'Chưa có phòng'
                                    : 'Phòng ${invoice.roomCode}',
                                style: const TextStyle(
                                  color: AppColors.bodyText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 16 / 12,
                                ),
                              ),
                            ],
                          ),
                          if (invoice.lines.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              invoice.lines.take(2).map(_lineLabel).join('\n'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.bodyText,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 15 / 11,
                              ),
                            ),
                          ],
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
    );
  }
}

class _PaidDivider extends StatelessWidget {
  const _PaidDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFD7D7E0), height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'HÓA ĐƠN ĐÃ THANH TOÁN',
            style: TextStyle(
              color: AppColors.bodyText,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 14 / 10,
              letterSpacing: 0.9,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFD7D7E0), height: 1)),
      ],
    );
  }
}

class _PaidBillCard extends StatelessWidget {
  const _PaidBillCard({required this.invoice});

  final TenantInvoice invoice;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.48,
      child: Container(
        constraints: const BoxConstraints(minHeight: 86),
        padding: const EdgeInsets.fromLTRB(22, 16, 18, 15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: Color(0xFF8096FF))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF8096FF)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          invoice.title,
                          style: const TextStyle(
                            color: AppColors.inputText,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            height: 20 / 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatAmount(invoice.totalAmount),
                        style: const TextStyle(
                          color: AppColors.inputText,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          height: 20 / 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8096FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'ĐÃ THANH TOÁN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            height: 12 / 9,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          invoice.issuedAt == null
                              ? 'Đã thanh toán'
                              : 'Ngày: ${_formatDate(invoice.issuedAt)}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.bodyText,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 15 / 11,
                          ),
                        ),
                      ),
                    ],
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

class _ViewHistoryButton extends StatelessWidget {
  const _ViewHistoryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFF1EFEF),
          foregroundColor: AppColors.deepBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        ),
        child: const Text(
          'Xem toàn bộ lịch sử thanh toán',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 18 / 13,
          ),
        ),
      ),
    );
  }
}
