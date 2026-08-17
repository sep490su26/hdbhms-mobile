import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/payment/tenant_invoice_model.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';

/// Display-only metadata for payment surfaces. It preserves the separate RENT,
/// UTILITY and OTHER detail experiences and never affects payment behaviour.
class InvoicePaymentPresentation {
  const InvoicePaymentPresentation({
    required this.displayName,
    required this.paymentPageTitle,
    required this.receiptHeading,
    required this.icon,
    required this.accentColor,
  });

  final String displayName;
  final String paymentPageTitle;
  final String receiptHeading;
  final IconData icon;
  final Color accentColor;

  static InvoicePaymentPresentation fromInvoice(TenantInvoice invoice) {
    final lineTypes = invoice.lines
        .map((line) => line.lineType.trim().toUpperCase())
        .toSet();
    if (invoice.isRentType) {
      return const InvoicePaymentPresentation(
        displayName: 'Tiền phòng & dịch vụ',
        paymentPageTitle: 'Thanh toán tiền phòng & dịch vụ',
        receiptHeading: 'THANH TOÁN TIỀN PHÒNG & DỊCH VỤ',
        icon: Icons.home_work_outlined,
        accentColor: AppColors.primary,
      );
    }
    if (invoice.isUtilityType) {
      if (invoice.isLegacyUtilityWithService) {
        return const InvoicePaymentPresentation(
          displayName: 'Tiền điện & dịch vụ',
          paymentPageTitle: 'Thanh toán tiền điện & dịch vụ',
          receiptHeading: 'THANH TOÁN TIỀN ĐIỆN & DỊCH VỤ',
          icon: Icons.bolt_rounded,
          accentColor: AppColors.actionOrange,
        );
      }
      if (invoice.isLegacyUtilityWithWater) {
        return const InvoicePaymentPresentation(
          displayName: 'Tiền điện & nước',
          paymentPageTitle: 'Thanh toán tiền điện & nước',
          receiptHeading: 'THANH TOÁN TIỀN ĐIỆN & NƯỚC',
          icon: Icons.bolt_rounded,
          accentColor: AppColors.actionOrange,
        );
      }
      return const InvoicePaymentPresentation(
        displayName: 'Tiền điện',
        paymentPageTitle: 'Thanh toán tiền điện',
        receiptHeading: 'THANH TOÁN TIỀN ĐIỆN',
        icon: Icons.bolt_rounded,
        accentColor: AppColors.actionOrange,
      );
    }
    if (lineTypes.contains('MAINTENANCE_COMPENSATION')) {
      return const InvoicePaymentPresentation(
        displayName: 'Chi phí sửa chữa',
        paymentPageTitle: 'Thanh toán chi phí sửa chữa',
        receiptHeading: 'THANH TOÁN CHI PHÍ SỬA CHỮA',
        icon: Icons.handyman_rounded,
        accentColor: AppColors.actionOrange,
      );
    }
    if (lineTypes.contains('VIOLATION_FINE')) {
      return const InvoicePaymentPresentation(
        displayName: 'Phạt vi phạm nội quy',
        paymentPageTitle: 'Thanh toán phạt vi phạm',
        receiptHeading: 'THANH TOÁN PHẠT VI PHẠM',
        icon: Icons.gavel_rounded,
        accentColor: AppColors.danger,
      );
    }
    if (invoice.priceDifferenceSettlementType?.trim().isNotEmpty == true) {
      return const InvoicePaymentPresentation(
        displayName: 'Chênh lệch chuyển phòng',
        paymentPageTitle: 'Thanh toán chênh lệch chuyển phòng',
        receiptHeading: 'THANH TOÁN CHÊNH LỆCH CHUYỂN PHÒNG',
        icon: Icons.swap_horiz_rounded,
        accentColor: AppColors.actionCyan,
      );
    }
    return const InvoicePaymentPresentation(
      displayName: 'Khoản phát sinh',
      paymentPageTitle: 'Thanh toán khoản phát sinh',
      receiptHeading: 'THANH TOÁN KHOẢN PHÁT SINH',
      icon: Icons.receipt_long_rounded,
      accentColor: AppColors.actionCyan,
    );
  }
}
