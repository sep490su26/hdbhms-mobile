import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';

import '../../models/change_request/change_request_model.dart';
import '../../models/payment/tenant_invoice_model.dart';
import '../../models/profile_request/tenant_request_model.dart';
import '../../models/room_transfer/room_transfer_model.dart';
import '../../services/payment/tenant_invoice_service.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_screen_shell.dart';
import '../../widgets/app_top_bar.dart';
import 'bill_detail_screen.dart';
import 'bill_selection_page.dart';
import 'payment_success_page.dart';
import 'payment_history_page.dart';
import 'qr_payment_page.dart';
import 'qr_receipt_download_page.dart';
import 'utility_complaint_screen.dart';
import '../profile_request/tenant_request_screen.dart';

/// Internal launcher for validating production payment flows with sample data.
class PaymentPreviewPage extends StatelessWidget {
  const PaymentPreviewPage({super.key});

  static const TenantInvoiceService _invoiceService =
      _PreviewTenantInvoiceService();

  static final TenantInvoice _rentInvoice = _invoice(
    id: -101,
    invoiceCode: 'RENT-DEMO-001',
    invoiceType: 'RENT',
    totalAmount: 13300000,
    subtotalAmount: 13800000,
    discountAmount: 500000,
    transferDescription: 'THANHTOAN RENT DEMO 001',
    lines: const [
      TenantInvoiceLine(
        id: -101,
        lineType: 'ROOM_RENT',
        description: 'Tiền phòng',
        quantity: 3,
        unitPrice: 4500000,
        amount: 13500000,
      ),
      TenantInvoiceLine(
        id: -105,
        lineType: 'SERVICE_FEE',
        description: 'Phí dịch vụ',
        quantity: 6,
        unitPrice: 50000,
        amount: 300000,
      ),
    ],
  );

  static final TenantInvoice _utilityInvoice = _invoice(
    id: -102,
    invoiceCode: 'UTILITY-DEMO-001',
    invoiceType: 'UTILITY',
    totalAmount: 600000,
    subtotalAmount: 630000,
    discountAmount: 30000,
    transferDescription: 'THANHTOAN UTILITY DEMO 001',
    lines: const [
      TenantInvoiceLine(
        id: -102,
        lineType: 'ELECTRICITY',
        description: 'Tiền điện',
        quantity: 180,
        unitPrice: 3500,
        amount: 630000,
        previousValue: 1010,
        currentValue: 1190,
        usageAmount: 180,
        canComplain: true,
      ),
    ],
  );

  static final TenantInvoice _maintenanceInvoice = _invoice(
    id: -107,
    invoiceCode: 'OTHER-DEMO-001',
    invoiceType: 'OTHER',
    totalAmount: 450000,
    subtotalAmount: 500000,
    discountAmount: 50000,
    transferDescription: 'THANHTOAN OTHER DEMO 001',
    lines: const [
      TenantInvoiceLine(
        id: -107,
        lineType: 'MAINTENANCE_COMPENSATION',
        description: 'Chi phí sửa chữa thiết bị',
        quantity: 1,
        unitPrice: 500000,
        amount: 500000,
      ),
    ],
  );

  static final TenantInvoice _reviewableUtilityInvoice = _invoice(
    id: -104,
    invoiceCode: 'UTILITY-DEMO-002',
    invoiceType: 'UTILITY',
    totalAmount: 735000,
    transferDescription: 'THANHTOAN UTILITY DEMO 002',
    lines: const [
      TenantInvoiceLine(
        id: -104,
        lineType: 'ELECTRICITY',
        description: 'Tiền điện',
        quantity: 210,
        unitPrice: 3500,
        amount: 735000,
        previousValue: 1240,
        currentValue: 1450,
        usageAmount: 210,
        canComplain: true,
        reviewStatus: 'NONE',
      ),
    ],
  );

  static final List<TenantInvoice> _paidHistoryInvoices = [
    _paidHistoryInvoice(
      id: -201,
      invoiceCode: 'RENT-2025-01',
      invoiceType: 'RENT',
      amount: 4200000,
      month: DateTime(2025, 1, 18),
    ),
    _paidHistoryInvoice(
      id: -202,
      invoiceCode: 'UTILITY-2025-04',
      invoiceType: 'UTILITY',
      amount: 884000,
      month: DateTime(2025, 4, 12),
    ),
    _paidHistoryInvoice(
      id: -203,
      invoiceCode: 'RENT-2025-08',
      invoiceType: 'RENT',
      amount: 4400000,
      month: DateTime(2025, 8, 5),
    ),
    _paidHistoryInvoice(
      id: -204,
      invoiceCode: 'UTILITY-2025-12',
      invoiceType: 'UTILITY',
      amount: 965000,
      month: DateTime(2025, 12, 22),
    ),
    _paidHistoryInvoice(
      id: -205,
      invoiceCode: 'RENT-2026-03',
      invoiceType: 'RENT',
      amount: 4500000,
      month: DateTime(2026, 3, 9),
    ),
    _paidHistoryInvoice(
      id: -206,
      invoiceCode: 'UTILITY-2026-07',
      invoiceType: 'UTILITY',
      amount: 1037000,
      month: DateTime(2026, 7, 20),
    ),
  ];

  /// API-shaped fixtures ensure every request preview takes the same list and
  /// detail route that a real request uses.
  static final List<ChangeRequest> _processingRequestPreviews = [
    ChangeRequest(
      id: -300,
      requestCode: 'PREVIEW-RENEW-01',
      requestType: ChangeRequestType.contractRenewal,
      title: 'Gia hạn hợp đồng phòng P.203',
      description:
          'Yêu cầu gia hạn đang được quản lý kiểm tra trước khi lập phụ lục hợp đồng.',
      status: ChangeRequestStatus.processing,
      requesterId: -1001,
      createdAt: DateTime(2026, 7, 22, 9, 15),
      requestPayload: jsonEncode({
        'contractCode': 'HD-P203-2026',
        'roomCode': 'P.203',
        'startDate': '2025-10-01',
        'oldEndDate': '2026-09-30',
        'renewalTermMonths': 12,
        'newStartDate': '2026-10-01',
        'newEndDate': '2027-09-30',
        'monthlyRent': 4500000,
        'paymentCycleMonths': 1,
        'depositAmount': 4500000,
      }),
    ),
    ChangeRequest(
      id: -301,
      requestCode: 'PREVIEW-LIQUIDATION-01',
      requestType: ChangeRequestType.contractLiquidation,
      title: 'Thanh lý hợp đồng phòng P.203',
      description:
          'Quản lý đã tiếp nhận yêu cầu và đang lập hóa đơn tất toán trước khi hoàn tất thủ tục.',
      status: ChangeRequestStatus.processing,
      requesterId: -1,
      createdAt: DateTime(2026, 7, 18, 14, 40),
      requestPayload: jsonEncode({
        'contractCode': 'HD-P203-2026',
        'roomCode': 'P.203',
        'liquidationDate': '2026-08-15',
        'liquidationStage': 'WAITING_FINAL_INVOICE',
        'depositRefundStatus': 'NOT_STARTED',
      }),
    ),
    ChangeRequest(
      id: -302,
      requestCode: 'PREVIEW-TRANSFER-01',
      requestType: ChangeRequestType.roomTransfer,
      title: 'Chuyển phòng P.203 sang P.305',
      description:
          'Yêu cầu chuyển phòng đang được kiểm tra tình trạng phòng và lịch bàn giao.',
      status: ChangeRequestStatus.processing,
      requesterId: -1001,
      createdAt: DateTime(2026, 7, 16, 10, 5),
      requestPayload: jsonEncode({
        'transferRequestId': -303,
        'transferRequestCode': 'PREVIEW-TRANSFER-01',
        'currentRoom': 'P.203',
        'targetRoom': 'P.305',
        'requestedTransferDate': '2026-08-01',
      }),
    ),
    ChangeRequest(
      id: -304,
      requestCode: 'PREVIEW-ROOMMATE-01',
      requestType: ChangeRequestType.addCoOccupant,
      title: 'Đăng ký người ở cùng phòng P.203',
      description:
          'Thông tin người ở cùng đang được kiểm tra để hoàn tất đăng ký lưu trú.',
      status: ChangeRequestStatus.processing,
      requesterId: -1001,
      createdAt: DateTime(2026, 7, 12, 16, 25),
      requestPayload: jsonEncode({
        'contractCode': 'HD-P203-2026',
        'roomCode': 'P.203',
        'fullName': 'Nguyễn Minh Anh',
        'phone': '0901 234 567',
        'email': 'minhanh@example.com',
        'moveInDate': '2026-08-01',
      }),
    ),
    ChangeRequest(
      id: -305,
      requestCode: 'PREVIEW-ELECTRIC-METER-01',
      requestType: ChangeRequestType.meterReadingCorrection,
      title: 'Khiếu nại số điện tháng 07/2026',
      description:
          'Chỉ số điện trên hóa đơn cao hơn mức sử dụng thực tế. Vui lòng kiểm tra lại chỉ số công tơ.',
      status: ChangeRequestStatus.processing,
      requesterId: -1001,
      createdAt: DateTime(2026, 7, 24, 11, 20),
      requestPayload: jsonEncode({
        'invoiceCode': 'UTILITY-DEMO-002',
        'roomCode': 'P.203',
        'billingPeriod': '2026-07',
        'meterType': 'ELECTRICITY',
        'previousValue': 1240,
        'currentValue': 1450,
        'reportedCurrentValue': 1325,
        'usageAmount': 210,
        'unitPrice': 3500,
        'lineAmount': 735000,
        'description':
            'Chỉ số trên hóa đơn là 1.450 kWh, nhưng chỉ số tôi ghi nhận là 1.325 kWh.',
      }),
    ),
  ];

  static final RoomTransferRequest _roomTransferProgressPreview =
      RoomTransferRequest(
        id: -303,
        requestCode: 'PREVIEW-TRANSFER-01',
        requesterId: -1001,
        oldContractId: -401,
        oldRoomId: -203,
        targetRoomId: -305,
        transferringTenantProfileIds: const [-1001],
        transferringTenantNames: const {-1001: 'Nguyễn Hoàng Minh'},
        sourceHolderCandidateProfileIds: const [],
        sourceHolderCandidateNames: const {},
        targetTransferType: TargetTransferType.newContract,
        requestedTransferDate: DateTime(2026, 8, 1),
        status: TransferRequestStatus.waitingExecution,
        oldRoomName: 'Phòng 203 · Khu A',
        oldRoomCode: 'P.203',
        oldContractCode: 'HD-P203-2026',
        targetRoomName: 'Phòng 305 · Khu A',
        targetRoomCode: 'P.305',
        oldRoomPrice: 4500000,
        newRoomPrice: 4800000,
        priceDifferenceAmount: 300000,
        priceDifferenceToPay: 300000,
        reason: 'Cần chuyển sang phòng có không gian rộng hơn.',
        remainingOccupantCountAfterTransfer: 0,
        sourceRoomWillBeEmptyAfterTransfer: true,
        paymentBranch: 'ADD_TO_NEXT_INVOICE',
        eligibleAtCreation: true,
        eligibilityCheckedAt: DateTime(2026, 7, 16, 10, 5),
        transferCountThisYear: 1,
      );

  static final List<TenantInvoice> _allInvoicesPreview = [
    _rentInvoice,
    _utilityInvoice,
    _invoice(
      id: -103,
      invoiceCode: 'RENT-DEMO-OVERDUE',
      invoiceType: 'RENT',
      totalAmount: 4500000,
      transferDescription: 'THANHTOAN RENT DEMO OVERDUE',
      billingPeriod: '2026-05',
      status: 'OVERDUE',
      issuedAt: DateTime(2026, 5, 2),
      dueDate: DateTime(2026, 5, 20),
      lines: const [
        TenantInvoiceLine(
          id: -103,
          lineType: 'RENT',
          description: 'Tiền phòng tháng 05/2026',
          quantity: 1,
          unitPrice: 4500000,
          amount: 4500000,
        ),
      ],
    ),
    ..._paidHistoryInvoices.take(4),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(
          header: AppTopBar(
            title: 'Xem trước thanh toán',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 20, 14, 24),
            children: [
              const Text('Luồng hóa đơn', style: AppTypography.pageTitle),
              const SizedBox(height: 6),
              const Text(
                'Dữ liệu mẫu chỉ phục vụ kiểm tra giao diện và không tạo giao dịch.',
                style: AppTypography.body,
              ),
              const SizedBox(height: 20),
              const _PreviewSectionTitle('Danh sách hóa đơn'),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.receipt_long_rounded,
                title: 'Tất cả hóa đơn',
                subtitle: 'Có cả hóa đơn đã thanh toán và chưa thanh toán',
                onTap: () => _openAllInvoicesPreview(context),
              ),
              const SizedBox(height: 20),
              const _PreviewSectionTitle('Yêu cầu đang xử lý'),
              const SizedBox(height: 8),
              ..._buildRequestPreviewTiles(context),
              const SizedBox(height: 20),
              const _PreviewSectionTitle('Hóa đơn'),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.receipt_long_rounded,
                title: 'Chi tiết Tiền phòng & dịch vụ',
                subtitle: 'Kiểm tra loại, trạng thái và thanh toán',
                onTap: () => _openBillDetail(context, _rentInvoice),
              ),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.receipt_long_rounded,
                title: 'Chi tiết Tiền điện',
                subtitle: 'Hiển thị chỉ số và quyền khiếu nại',
                onTap: () => _openBillDetail(context, _utilityInvoice),
              ),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.report_problem_outlined,
                title: 'Khiếu nại số điện',
                subtitle: 'Kiểm tra form phản hồi chỉ số',
                onTap: () => _openComplaint(context, _reviewableUtilityInvoice),
              ),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.handyman_rounded,
                title: 'Chi tiết Chi phí sửa chữa',
                subtitle: 'Kiểm tra giảm giá và ngữ nghĩa chi phí sửa chữa',
                onTap: () => _openBillDetail(context, _maintenanceInvoice),
              ),
              const SizedBox(height: 20),
              const _PreviewSectionTitle('Thanh toán'),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.qr_code_rounded,
                title: 'QR Tiền phòng & dịch vụ',
                subtitle: 'Hóa đơn Tiền phòng & dịch vụ',
                onTap: () => _openQr(context, _rentInvoice),
              ),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.qr_code_rounded,
                title: 'QR Tiền điện',
                subtitle: 'Hóa đơn Tiền điện',
                onTap: () => _openQr(context, _utilityInvoice),
              ),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.handyman_rounded,
                title: 'QR chi phí sửa chữa',
                subtitle: 'Hóa đơn phát sinh từ phiếu sự cố',
                onTap: () => _openQr(context, _maintenanceInvoice),
              ),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.check_circle_outline_rounded,
                title: 'Thanh toán thành công — Tiền phòng & dịch vụ',
                subtitle:
                    'Trạng thái hoàn tất của hóa đơn Tiền phòng & dịch vụ',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        PaymentSuccessPage(invoice: _rentInvoice),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.check_circle_outline_rounded,
                title: 'Thanh toán thành công — sửa chữa',
                subtitle: 'Ngữ nghĩa hóa đơn phát sinh',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        PaymentSuccessPage(invoice: _maintenanceInvoice),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.check_circle_outline_rounded,
                title: 'Thanh toán thành công — Tiền điện',
                subtitle: 'Trạng thái hoàn tất của hóa đơn Tiền điện',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        PaymentSuccessPage(invoice: _utilityInvoice),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _PreviewSectionTitle('Lịch sử thanh toán'),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.history_rounded,
                title: 'Lịch sử thanh toán nhiều kỳ',
                subtitle:
                    'Dữ liệu từ 01/2025 đến 07/2026 để thử bộ lọc tháng/năm',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PaymentHistoryPage(
                      invoiceService: _invoiceService,
                      roomCode: 'P.203',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _PreviewSectionTitle('Mẫu QR tải xuống'),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.download_rounded,
                title: 'Mẫu QR Tiền phòng & dịch vụ',
                subtitle: 'Xem trước ảnh QR có thể tải về',
                onTap: () => _openReceiptPreview(context, _rentInvoice),
              ),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.download_rounded,
                title: 'Mẫu QR Tiền điện',
                subtitle: 'Xem trước ảnh QR có thể tải về',
                onTap: () => _openReceiptPreview(context, _utilityInvoice),
              ),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.download_rounded,
                title: 'Mẫu QR chi phí sửa chữa',
                subtitle: 'Ảnh QR của hóa đơn phát sinh',
                onTap: () => _openReceiptPreview(context, _maintenanceInvoice),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openQr(BuildContext context, TenantInvoice invoice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QrPaymentPage(
          invoice: invoice,
          pollInterval: const Duration(days: 1),
        ),
      ),
    );
  }

  List<Widget> _buildRequestPreviewTiles(BuildContext context) {
    const icons = [
      Icons.event_repeat_rounded,
      Icons.assignment_return_rounded,
      Icons.swap_horiz_rounded,
      Icons.person_add_alt_1_rounded,
      Icons.bolt_outlined,
    ];
    return List.generate(_processingRequestPreviews.length, (index) {
      final request = _processingRequestPreviews[index];
      return Padding(
        padding: EdgeInsets.only(
          bottom: index == _processingRequestPreviews.length - 1 ? 0 : 8,
        ),
        child: _PreviewTile(
          icon: icons[index],
          title: _previewRequestTitle(request),
          subtitle: 'Trạng thái: Đang xử lý',
          onTap: () => _openRequestPreview(context, request),
        ),
      );
    });
  }

  void _openRequestPreview(BuildContext context, ChangeRequest request) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TenantRequestScreen(
          previewChangeRequests: [request],
          previewRoomTransfers:
              request.requestType == ChangeRequestType.roomTransfer
              ? {request.id: _roomTransferProgressPreview}
              : const {},
          previewTenantProfileId:
              request.requestType == ChangeRequestType.roomTransfer
              ? -1001
              : null,
          initialFilterType: _tenantRequestTypeFor(request.requestType),
        ),
      ),
    );
  }

  TenantRequestType _tenantRequestTypeFor(ChangeRequestType type) {
    return switch (type) {
      ChangeRequestType.contractRenewal => TenantRequestType.renewContract,
      ChangeRequestType.contractLiquidation ||
      ChangeRequestType.moveOut => TenantRequestType.terminateContract,
      ChangeRequestType.roomTransfer => TenantRequestType.changeRoom,
      ChangeRequestType.addCoOccupant => TenantRequestType.addRoommate,
      ChangeRequestType.meterReadingCorrection =>
        TenantRequestType.utilityComplaint,
      _ => TenantRequestType.renewContract,
    };
  }

  String _previewRequestTitle(ChangeRequest request) {
    if (request.requestType == ChangeRequestType.meterReadingCorrection) {
      return 'Khiếu nại số điện';
    }
    return _tenantRequestTypeFor(request.requestType).fullLabel;
  }

  void _openAllInvoicesPreview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BillSelectionPage(
          previewInvoices: _allInvoicesPreview,
          previewServicePaymentCycleMonths: 3,
        ),
      ),
    );
  }

  void _openBillDetail(BuildContext context, TenantInvoice invoice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BillDetailScreen(
          invoice: invoice,
          invoiceService: _invoiceService,
          servicePaymentCycleMonths: invoice.id == _rentInvoice.id ? 3 : null,
        ),
      ),
    );
  }

  void _openComplaint(BuildContext context, TenantInvoice invoice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UtilityComplaintScreen(
          invoice: invoice,
          invoiceService: _invoiceService,
        ),
      ),
    );
  }

  void _openReceiptPreview(BuildContext context, TenantInvoice invoice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QrReceiptPreviewPage(invoice: invoice),
      ),
    );
  }

  static TenantInvoice _invoice({
    required int id,
    required String invoiceCode,
    required String invoiceType,
    required int totalAmount,
    required String transferDescription,
    required List<TenantInvoiceLine> lines,
    String billingPeriod = '2026-06',
    String status = 'ISSUED',
    DateTime? issuedAt,
    DateTime? dueDate,
    DateTime? paidAt,
    int? paidAmount,
    int? remainingAmount,
    int? subtotalAmount,
    int discountAmount = 0,
  }) {
    return TenantInvoice(
      id: id,
      invoiceCode: invoiceCode,
      invoiceType: invoiceType,
      billingPeriod: billingPeriod,
      status: status,
      roomId: -1,
      roomCode: 'P.203',
      contractId: -1,
      contractCode: 'HD-DEMO-001',
      dueDate: dueDate ?? DateTime(2026, 6, 30),
      issuedAt: issuedAt ?? DateTime(2026, 6, 22),
      paidAt: paidAt,
      totalAmount: totalAmount,
      subtotalAmount: subtotalAmount,
      discountAmount: discountAmount,
      paidAmount: paidAmount ?? 0,
      remainingAmount: remainingAmount ?? totalAmount,
      paymentIntentId: null,
      checkoutUrl: '',
      qrCode: 'HDBHMS:$invoiceCode:$totalAmount:$transferDescription',
      providerOrderCode: '',
      paymentLinkId: '',
      bankBin: '970436',
      bankShortName: 'Vietcombank',
      accountNumber: '001234567890',
      accountName: 'CONG TY HDBHMS',
      transferDescription: transferDescription,
      lines: lines,
      priceDifferenceSettlementType: null,
    );
  }

  static TenantInvoice _paidHistoryInvoice({
    required int id,
    required String invoiceCode,
    required String invoiceType,
    required int amount,
    required DateTime month,
  }) {
    final period = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    return _invoice(
      id: id,
      invoiceCode: invoiceCode,
      invoiceType: invoiceType,
      totalAmount: amount,
      transferDescription: 'THANHTOAN $invoiceCode',
      lines: const [],
      billingPeriod: period,
      status: 'PAID',
      issuedAt: DateTime(month.year, month.month, 1),
      dueDate: DateTime(month.year, month.month, 25),
      paidAt: month,
      paidAmount: amount,
      remainingAmount: 0,
    );
  }
}

class _PreviewTenantInvoiceService extends TenantInvoiceService {
  const _PreviewTenantInvoiceService();

  @override
  Future<List<TenantInvoice>> fetchMyInvoices({
    int? roomId,
    String? roomCode,
  }) async => PaymentPreviewPage._paidHistoryInvoices;

  @override
  Future<void> submitMeterReadingReview({
    required int invoiceId,
    required int lineId,
    required double reportedCurrentValue,
    required String description,
  }) async {}
}

class _PreviewSectionTitle extends StatelessWidget {
  const _PreviewSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTypography.sectionTitle);
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.cardTitle),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AppTypography.caption),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.bodyText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
