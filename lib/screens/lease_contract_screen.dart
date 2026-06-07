import 'package:flutter/material.dart';
import 'notification_list_screen.dart';

import '../config/api_config.dart';
import '../models/lease_contract_model.dart';
import '../services/lease_contract_service.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/tenant_bottom_navigation.dart';
import 'bill_selection_page.dart';
import 'contract_pdf_viewer_screen.dart';
import 'maintenance_ticket_list_screen.dart';
import 'tenant_profile_screen.dart';

class LeaseContractScreen extends StatefulWidget {
  const LeaseContractScreen({
    super.key,
    this.contractId,
    this.contractService = const LeaseContractService(),
  });

  final int? contractId;
  final LeaseContractService contractService;

  @override
  State<LeaseContractScreen> createState() => _LeaseContractScreenState();
}

class _LeaseContractScreenState extends State<LeaseContractScreen> {
  late Future<LeaseContract> _contractFuture;

  @override
  void initState() {
    super.initState();
    _contractFuture = _loadContract();
  }

  Future<LeaseContract> _loadContract() {
    final id = widget.contractId;
    if (id != null) {
      return widget.contractService.getContractById(id);
    }
    return widget.contractService.getMyActiveContract();
  }

  void _retry() {
    setState(() {
      _contractFuture = _loadContract();
    });
  }

  Future<void> _refresh() async {
    final future = _loadContract();
    setState(() {
      _contractFuture = future;
    });
    await future;
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
                const _ContractHeader(),
                Expanded(
                  child: FutureBuilder<LeaseContract>(
                    future: _contractFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const _ContractLoadingState();
                      }

                      if (snapshot.hasError) {
                        final error = snapshot.error;
                        if (error is LeaseContractNotFoundException) {
                          return _ContractEmptyState(onRetry: _retry);
                        }
                        return _ContractErrorState(
                          message: _messageForError(error),
                          onRetry: _retry,
                        );
                      }

                      final contract = snapshot.data;
                      if (contract == null) {
                        return _ContractEmptyState(onRetry: _retry);
                      }

                      return RefreshIndicator(
                        color: AppColors.deepBlue,
                        onRefresh: _refresh,
                        child: _ContractContent(contract: contract),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const _ContractBottomNavigation(),
    );
  }
}

class _ContractHeader extends StatelessWidget {
  const _ContractHeader();

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
              'Thông tin hợp đồng',
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

class _ContractContent extends StatelessWidget {
  const _ContractContent({required this.contract});

  final LeaseContract contract;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ContractWarning(contract: contract),
          _RoomHeroCard(contract: contract),
          const SizedBox(height: 12),
          _ContractInfoGrid(contract: contract),
          const SizedBox(height: 12),
          _TermsSection(terms: contract.terms),
          const SizedBox(height: 12),
          _DocumentSection(contractFileUrl: contract.contractFileUrl),
        ],
      ),
    );
  }
}

class _ContractWarning extends StatelessWidget {
  const _ContractWarning({required this.contract});

  final LeaseContract contract;

  @override
  Widget build(BuildContext context) {
    final endDate = contract.endDate;
    if (endDate == null) {
      return const SizedBox.shrink();
    }

    final today = _dateOnly(DateTime.now());
    final end = _dateOnly(endDate);
    final remainingDays = end.difference(today).inDays;
    final isExpired = remainingDays < 0;
    final isExpiringSoon = remainingDays >= 0 && remainingDays <= 90;

    if (!isExpired && !isExpiringSoon) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD8D5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFA9A3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFB00020),
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isExpired
                        ? 'HĐ đã hết hạn, vui lòng liên hệ quản lý'
                        : 'HĐ sắp hết hạn, vui lòng phản hồi',
                    style: const TextStyle(
                      color: Color(0xFFB00020),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      height: 20 / 15,
                    ),
                  ),
                  if (!isExpired) ...[
                    const SizedBox(height: 7),
                    Text(
                      'Hợp đồng thuê phòng của bạn sẽ kết thúc vào ngày '
                      '${_formatDate(endDate)}. Vui lòng liên hệ ban quản lý '
                      'để gia hạn hoặc hoàn tất thủ tục trả phòng.',
                      style: const TextStyle(
                        color: Color(0xFFB00020),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 17 / 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomHeroCard extends StatelessWidget {
  const _RoomHeroCard({required this.contract});

  final LeaseContract contract;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveResourceUrl(contract.room.imageUrl);
    final roomName = _roomTitle(contract.room);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isEmpty)
              const _RoomPlaceholder()
            else
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _RoomPlaceholder(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }
                  return const _RoomPlaceholder();
                },
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatusBadge(status: contract.status),
                        const SizedBox(height: 7),
                        Text(
                          roomName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 27 / 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${_formatMoney(contract.monthlyRent)}/tháng',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 17 / 13,
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

class _RoomPlaceholder extends StatelessWidget {
  const _RoomPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE7E9F2),
      child: const Center(
        child: Icon(
          Icons.apartment_rounded,
          color: AppColors.deepBlue,
          size: 54,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFA7B4FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: const TextStyle(
          color: AppColors.deepBlue,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 13 / 10,
        ),
      ),
    );
  }
}

class _ContractInfoGrid extends StatelessWidget {
  const _ContractInfoGrid({required this.contract});

  final LeaseContract contract;

  @override
  Widget build(BuildContext context) {
    final items = [
      _InfoGridItem(
        label: 'Chu kỳ',
        value: contract.paymentCycleMonths == null
            ? ''
            : '${contract.paymentCycleMonths} tháng',
      ),
      _InfoGridItem(
        label: 'Diện tích',
        value: contract.room.area == null
            ? ''
            : '${_formatNumber(contract.room.area!)} m²',
      ),      
      _InfoGridItem(label: 'Bắt đầu', value: _formatDate(contract.startDate)),
      _InfoGridItem(label: 'Kết thúc', value: _formatDate(contract.endDate)),
      _InfoGridItem(
        label: 'Bắt đầu tính tiền',
        value: _formatDate(contract.rentStartDate),
      ),
      _InfoGridItem(
        label: 'Tiền cọc',
        value: _formatMoney(contract.depositAmount),
      ),
      _InfoGridItem(label: 'Mã phòng', value: contract.room.roomCode),
      _InfoGridItem(
        label: 'Ngày ký',
        value: contract.signedAt != null ? _formatDate(contract.signedAt!) : '--',
      ),
      _InfoGridItem(label: 'Trạng thái', value: _statusLabel(contract.status)),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: GridView.builder(
        itemCount: items.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.9,
          crossAxisSpacing: 14,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, index) => items[index],
      ),
    );
  }
}

class _InfoGridItem extends StatelessWidget {
  const _InfoGridItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.bodyText,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            height: 13 / 10,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _display(value),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.inputText,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 17 / 13,
          ),
        ),
      ],
    );
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection({required this.terms});

  final List<String> terms;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Điều khoản chính',
      icon: Icons.gavel_rounded,
      child: terms.isEmpty
          ? const _MutedText('Chưa có điều khoản hợp đồng')
          : Column(
              children: [
                for (var i = 0; i < terms.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _TermTile(text: terms[i]),
                ],
              ],
            ),
    );
  }
}

class _TermTile extends StatelessWidget {
  const _TermTile({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F0F0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.deepBlue,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.bodyText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 17 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentSection extends StatelessWidget {
  const _DocumentSection({required this.contractFileUrl});

  final String contractFileUrl;

  @override
  Widget build(BuildContext context) {
    final url = _resolveResourceUrl(contractFileUrl);

    return _SectionCard(
      title: 'Quản lý tài liệu',
      child: url.isEmpty
          ? const _MutedText('Chưa có tài liệu hợp đồng')
          : SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _showContractFile(context, url),
                icon: const Icon(Icons.description_outlined, size: 20),
                label: const Text('Xem hợp đồng'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.icon});

  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.deepBlue, size: 19),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.inputText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 20 / 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.bodyText,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        height: 18 / 13,
      ),
    );
  }
}

class _ContractLoadingState extends StatelessWidget {
  const _ContractLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.deepBlue),
    );
  }
}

class _ContractEmptyState extends StatelessWidget {
  const _ContractEmptyState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateMessage(
      icon: Icons.description_outlined,
      title: 'Bạn chưa có hợp đồng thuê phòng đang hiệu lực',
      buttonLabel: 'Thử lại',
      onRetry: onRetry,
    );
  }
}

class _ContractErrorState extends StatelessWidget {
  const _ContractErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateMessage(
      icon: Icons.error_outline_rounded,
      title: message,
      buttonLabel: 'Thử lại',
      onRetry: onRetry,
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.buttonLabel,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String buttonLabel;
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
          const SizedBox(height: 120),
          Icon(icon, color: AppColors.deepBlue, size: 46),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.inputText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 20 / 15,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(buttonLabel),
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

class _ContractBottomNavigation extends StatelessWidget {
  const _ContractBottomNavigation();

  @override
  Widget build(BuildContext context) {
    return TenantBottomNavigation(
      activeTab: TenantBottomNavTab.home,
      onHomeTap: () =>
          Navigator.of(context).popUntil((route) => route.isFirst),
      onSupportTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const MaintenanceTicketListScreen(),
          ),
        );
      },
      onBillsTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const BillSelectionPage(),
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
      onRequestsTap: () {},
    );
  }
}

void _showContractFile(BuildContext context, String url) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => ContractPdfViewerScreen(
        pdfUrl: url,
        title: 'Hợp đồng thuê phòng',
      ),
    ),
  );
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _roomTitle(LeaseRoom room) {
  if (room.roomName.trim().isNotEmpty) {
    return room.roomName.trim();
  }
  if (room.roomCode.trim().isNotEmpty) {
    return 'Phòng ${room.roomCode.trim()}';
  }
  return 'Phòng thuê';
}

String _display(String? value) {
  final trimmed = value?.trim() ?? '';
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

String _formatMoney(num? amount) {
  if (amount == null) {
    return 'Chưa cập nhật';
  }
  return CurrencyFormatter.vnd(amount).replaceAll(' đ', 'đ');
}

String _formatNumber(num value) {
  if (value % 1 == 0) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}

String _statusLabel(String status) {
  return switch (status.trim().toUpperCase()) {
    'ACTIVE' => 'Đang hiệu lực',
    'EXPIRING_SOON' => 'Sắp hết hạn',
    'EXPIRED' => 'Đã hết hạn',
    'TERMINATED' => 'Đã chấm dứt',
    'DRAFT' => 'Bản nháp',
    'PENDING_SIGNATURE' => 'Chờ ký',
    _ => _display(status),
  };
}

String _resolveResourceUrl(String value) {
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
  if (error is LeaseContractException) {
    return error.message;
  }
  return 'Không tải được dữ liệu hợp đồng';
}
