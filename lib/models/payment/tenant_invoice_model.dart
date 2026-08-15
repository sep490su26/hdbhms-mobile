class TenantInvoice {
  const TenantInvoice({
    required this.id,
    required this.invoiceCode,
    required this.invoiceType,
    required this.billingPeriod,
    required this.status,
    required this.roomId,
    required this.roomCode,
    required this.contractId,
    required this.contractCode,
    required this.dueDate,
    required this.issuedAt,
    this.issueDate,
    required this.paidAt,
    required this.totalAmount,
    int? subtotalAmount,
    this.discountAmount = 0,
    required this.paidAmount,
    required this.remainingAmount,
    required this.paymentIntentId,
    required this.checkoutUrl,
    required this.qrCode,
    required this.providerOrderCode,
    required this.paymentLinkId,
    required this.bankBin,
    required this.bankShortName,
    required this.accountNumber,
    required this.accountName,
    required this.transferDescription,
    required this.lines,
    required this.priceDifferenceSettlementType,
    this.hasOpenMeterReadingReview = false,
  }) : subtotalAmount = subtotalAmount ?? totalAmount + discountAmount;

  final int? id;
  final String invoiceCode;
  final String invoiceType;
  final String billingPeriod;
  final String status;
  final int? roomId;
  final String roomCode;
  final int? contractId;
  final String contractCode;
  final DateTime? dueDate;
  final DateTime? issuedAt;
  final DateTime? issueDate;
  final DateTime? paidAt;
  final int totalAmount;
  final int subtotalAmount;
  final int discountAmount;
  final int paidAmount;
  final int remainingAmount;
  final int? paymentIntentId;
  final String checkoutUrl;
  final String qrCode;
  final String providerOrderCode;
  final String paymentLinkId;
  final String bankBin;
  final String bankShortName;
  final String accountNumber;
  final String accountName;
  final String transferDescription;
  final List<TenantInvoiceLine> lines;
  final String? priceDifferenceSettlementType;
  final bool hasOpenMeterReadingReview;

  bool get isPaid => status.toUpperCase() == 'PAID' || remainingAmount <= 0;

  List<TenantInvoiceLine> get utilityMeterLines => lines
      .where(
        (line) =>
            line.normalizedLineType == 'ELECTRICITY' ||
            line.normalizedLineType == 'WATER',
      )
      .toList(growable: false);

  List<TenantInvoiceLine> get reviewableUtilityLines => utilityMeterLines
      .where((line) => line.canComplain && line.id != null)
      .toList(growable: false);

  bool get isTenantVisible {
    final normalized = status.toUpperCase();
    return normalized == 'ISSUED' ||
        normalized == 'PARTIALLY_PAID' ||
        normalized == 'PAID' ||
        normalized == 'OVERDUE';
  }

  bool get canPay {
    final normalized = status.toUpperCase();
    return normalized == 'ISSUED' ||
        normalized == 'PARTIALLY_PAID' ||
        normalized == 'OVERDUE';
  }

  String get payosQrValue {
    final value = qrCode.trim();
    if (value.isNotEmpty) return value;
    return checkoutUrl.trim();
  }

  bool get hasPayosQr => payosQrValue.isNotEmpty;

  String get normalizedInvoiceType => invoiceType.trim().toUpperCase();

  bool get isRentType => normalizedInvoiceType == 'RENT';

  bool get isUtilityType => normalizedInvoiceType == 'UTILITY';

  bool get isOtherType => !isRentType && !isUtilityType;

  /// Legacy responses did not return a subtotal. The total stays authoritative;
  /// this only supplies a presentation fallback for the discount summary.
  int get resolvedSubtotalAmount => subtotalAmount;

  String get invoiceTypeLabel {
    return switch (normalizedInvoiceType) {
      'RENT' => 'Tiền phòng',
      'UTILITY' => 'Tiền điện & dịch vụ',
      _ => 'Khác',
    };
  }

  String get displayAccountNumber {
    final raw = accountNumber.trim();
    if (raw.isEmpty) return '';
    if (!RegExp(r'[A-Za-z]').hasMatch(raw)) return raw;
    final lastLetterIndex = raw.lastIndexOf(RegExp(r'[A-Za-z]'));
    final suffix = raw.substring(lastLetterIndex + 1).trim();
    if (RegExp(r'^\d{6,}$').hasMatch(suffix)) {
      return suffix;
    }
    return raw;
  }

  String get title {
    final hasViolation = lines.any(
      (line) => line.normalizedLineType == 'VIOLATION_FINE',
    );
    if (hasViolation) {
      return 'Phạt vi phạm nội quy';
    }
    final hasMaintenanceCompensation = lines.any(
      (line) => line.normalizedLineType == 'MAINTENANCE_COMPENSATION',
    );
    if (hasMaintenanceCompensation) {
      return 'Bồi thường chi phí bảo trì';
    }
    if (isUtilityType) {
      return 'Hóa đơn tiền điện & dịch vụ ${_periodLabel(billingPeriod)}';
    }
    if (isRentType) {
      return 'Hóa đơn tiền phòng ${_periodLabel(billingPeriod)}';
    }
    final period = _periodLabel(billingPeriod);
    return period.isEmpty ? 'Hóa đơn khác' : 'Hóa đơn khác $period';
  }

  factory TenantInvoice.fromJson(Map<String, dynamic> json) {
    return TenantInvoice(
      id: int.tryParse(json['id']?.toString() ?? ''),
      invoiceCode: _firstString(json, ['invoiceCode']),
      invoiceType: _firstString(json, ['invoiceType']),
      billingPeriod: _firstString(json, ['billingPeriod']),
      status: _firstString(json, ['status']),
      roomId: int.tryParse(_firstString(json, ['roomId'])),
      roomCode: _firstString(json, ['roomCode']),
      contractId: int.tryParse(_firstString(json, ['contractId'])),
      contractCode: _firstString(json, ['contractCode']),
      dueDate: DateTime.tryParse(_firstString(json, ['dueDate'])),
      issuedAt: DateTime.tryParse(_firstString(json, ['issuedAt'])),
      issueDate: DateTime.tryParse(
        _firstString(json, ['issueDate', 'createdAt']),
      ),
      paidAt: DateTime.tryParse(_firstString(json, ['paidAt'])),
      totalAmount: _intField(json, ['totalAmount']),
      subtotalAmount: json.containsKey('subtotalAmount')
          ? _intField(json, ['subtotalAmount'])
          : null,
      discountAmount: _intField(json, ['discountAmount']),
      paidAmount: _intField(json, ['paidAmount']),
      remainingAmount: _intField(json, ['remainingAmount']),
      paymentIntentId: int.tryParse(_firstString(json, ['paymentIntentId'])),
      checkoutUrl: _firstString(json, ['checkoutUrl', 'checkOutUrl']),
      qrCode: _firstString(json, ['qrCode', 'qrPayload']),
      providerOrderCode: _firstString(json, ['providerOrderCode']),
      paymentLinkId: _firstString(json, ['paymentLinkId']),
      bankBin: _firstString(json, ['bankBin']),
      bankShortName: _firstString(json, ['bankShortName']),
      accountNumber: _firstString(json, ['accountNumber']),
      accountName: _firstString(json, ['accountName']),
      transferDescription: _firstString(json, ['transferDescription']),
      lines: (json['lines'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(TenantInvoiceLine.fromJson)
          .toList(),
      priceDifferenceSettlementType: _firstString(json, [
        'priceDifferenceSettlementType',
      ]),
      hasOpenMeterReadingReview: _boolField(json, [
        'hasOpenMeterReadingReview',
      ]),
    );
  }
}

class TenantInvoiceLine {
  const TenantInvoiceLine({
    required this.id,
    required this.lineType,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    this.meterReadingId,
    this.meterType = '',
    this.readingPeriod = '',
    this.readingDate,
    this.previousValue,
    this.currentValue,
    this.usageAmount,
    this.reviewStatus = 'NONE',
    this.openReviewId,
    this.canComplain = false,
  });

  final int? id;
  final String lineType;
  final String description;
  final int quantity;
  final int unitPrice;
  final int amount;
  final int? meterReadingId;
  final String meterType;
  final String readingPeriod;
  final DateTime? readingDate;
  final double? previousValue;
  final double? currentValue;
  final double? usageAmount;
  final String reviewStatus;
  final int? openReviewId;
  final bool canComplain;

  /// Presentation-only compatibility layer. Keep [lineType] unchanged because
  /// it is the raw backend value used by existing API contracts.
  String get normalizedLineType {
    return switch (lineType.trim().toUpperCase()) {
      'ROOM_RENT' || 'RENT' => 'RENT',
      'SERVICE_FEE' || 'SERVICE' => 'SERVICE',
      'ELECTRICITY' => 'ELECTRICITY',
      'WATER' => 'WATER',
      'MAINTENANCE_COMPENSATION' => 'MAINTENANCE_COMPENSATION',
      'VIOLATION_FINE' => 'VIOLATION_FINE',
      'TRANSFER_DIFFERENCE' => 'TRANSFER_DIFFERENCE',
      'DEPOSIT_DEDUCTION' => 'DEPOSIT_DEDUCTION',
      'MANUAL_ADJUSTMENT' => 'MANUAL_ADJUSTMENT',
      _ => 'OTHER',
    };
  }

  bool get hasOpenReview =>
      openReviewId != null ||
      reviewStatus == 'PENDING' ||
      reviewStatus == 'UNDER_REVIEW' ||
      reviewStatus == 'PROCESSING';

  factory TenantInvoiceLine.fromJson(Map<String, dynamic> json) {
    return TenantInvoiceLine(
      id: int.tryParse(json['id']?.toString() ?? ''),
      lineType: _firstString(json, ['lineType']),
      description: _firstString(json, ['description']),
      quantity: _intField(json, ['quantity']),
      unitPrice: _intField(json, ['unitPrice']),
      amount: _intField(json, ['amount']),
      meterReadingId: int.tryParse(_firstString(json, ['meterReadingId'])),
      meterType: _firstString(json, ['meterType']),
      readingPeriod: _firstString(json, ['readingPeriod']),
      readingDate: DateTime.tryParse(_firstString(json, ['readingDate'])),
      previousValue: _doubleField(json, ['previousValue']),
      currentValue: _doubleField(json, ['currentValue']),
      usageAmount: _doubleField(json, ['usageAmount']),
      reviewStatus: _firstString(json, ['reviewStatus']),
      openReviewId: int.tryParse(_firstString(json, ['openReviewId'])),
      canComplain: _boolField(json, ['canComplain']),
    );
  }
}

String _firstString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null && value.toString().isNotEmpty) return value.toString();
  }
  return '';
}

int _intField(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final parsed = int.tryParse(value.toString());
    if (parsed != null) return parsed;
  }
  return 0;
}

double? _doubleField(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final parsed = double.tryParse(value.toString());
    if (parsed != null) return parsed;
  }
  return null;
}

bool _boolField(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
    if (value == null) continue;
    final normalized = value.toString().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
  }
  return false;
}

String _periodLabel(String value) {
  if (value.length == 7 && value.contains('-')) {
    final parts = value.split('-');
    return 'tháng ${parts[1]}/${parts[0]}';
  }
  return value;
}
