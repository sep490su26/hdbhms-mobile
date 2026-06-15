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
    required this.paidAt,
    required this.totalAmount,
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
  });

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
  final DateTime? paidAt;
  final int totalAmount;
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

  bool get isPaid => status.toUpperCase() == 'PAID' || remainingAmount <= 0;

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
    final hasViolation = lines.any((line) => line.lineType == 'VIOLATION_FINE');
    if (hasViolation) {
      return 'Phạt vi phạm nội quy';
    }
    final hasMaintenanceCompensation = lines.any(
      (line) => line.lineType == 'MAINTENANCE_COMPENSATION',
    );
    if (hasMaintenanceCompensation) {
      return 'Bồi thường chi phí bảo trì';
    }
    if (invoiceType == 'UTILITY') {
      return 'Hóa đơn Điện & Nước ${_periodLabel(billingPeriod)}';
    }
    if (invoiceType == 'RENT') {
      return 'Hóa đơn tiền phòng ${_periodLabel(billingPeriod)}';
    }
    final period = _periodLabel(billingPeriod);
    return period.isEmpty ? 'Hóa đơn phát sinh' : 'Hóa đơn $period';
  }

  factory TenantInvoice.fromJson(Map<String, dynamic> json) {
    return TenantInvoice(
      id: int.tryParse(json['id']?.toString() ?? ''),
      invoiceCode: _firstString(json, ['invoiceCode', 'invoice_code']),
      invoiceType: _firstString(json, ['invoiceType', 'invoice_type']),
      billingPeriod: _firstString(json, ['billingPeriod', 'billing_period']),
      status: _firstString(json, ['status']),
      roomId: int.tryParse(_firstString(json, ['roomId', 'room_id'])),
      roomCode: _firstString(json, ['roomCode', 'room_code']),
      contractId: int.tryParse(
        _firstString(json, ['contractId', 'contract_id']),
      ),
      contractCode: _firstString(json, ['contractCode', 'contract_code']),
      dueDate: DateTime.tryParse(_firstString(json, ['dueDate', 'due_date'])),
      issuedAt: DateTime.tryParse(
        _firstString(json, ['issuedAt', 'issued_at']),
      ),
      paidAt: DateTime.tryParse(_firstString(json, ['paidAt', 'paid_at'])),
      totalAmount: _intField(json, ['totalAmount', 'total_amount']),
      paidAmount: _intField(json, ['paidAmount', 'paid_amount']),
      remainingAmount: _intField(json, ['remainingAmount', 'remaining_amount']),
      paymentIntentId: int.tryParse(
        _firstString(json, ['paymentIntentId', 'payment_intent_id']),
      ),
      checkoutUrl: _firstString(json, [
        'checkoutUrl',
        'checkout_url',
        'checkOutUrl',
      ]),
      qrCode: _firstString(json, ['qrCode', 'qr_code']),
      providerOrderCode: _firstString(json, [
        'providerOrderCode',
        'provider_order_code',
      ]),
      paymentLinkId: _firstString(json, ['paymentLinkId', 'payment_link_id']),
      bankBin: _firstString(json, ['bankBin', 'bank_bin']),
      bankShortName: _firstString(json, ['bankShortName', 'bank_short_name']),
      accountNumber: _firstString(json, ['accountNumber', 'account_number']),
      accountName: _firstString(json, ['accountName', 'account_name']),
      transferDescription: _firstString(json, [
        'transferDescription',
        'transfer_description',
      ]),
      lines: (json['lines'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(TenantInvoiceLine.fromJson)
          .toList(),
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
  });

  final int? id;
  final String lineType;
  final String description;
  final int quantity;
  final int unitPrice;
  final int amount;

  factory TenantInvoiceLine.fromJson(Map<String, dynamic> json) {
    return TenantInvoiceLine(
      id: int.tryParse(json['id']?.toString() ?? ''),
      lineType: _firstString(json, ['lineType', 'line_type']),
      description: _firstString(json, ['description']),
      quantity: _intField(json, ['quantity']),
      unitPrice: _intField(json, ['unitPrice', 'unit_price']),
      amount: _intField(json, ['amount']),
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

String _periodLabel(String value) {
  if (value.length == 7 && value.contains('-')) {
    final parts = value.split('-');
    return 'tháng ${parts[1]}/${parts[0]}';
  }
  return value;
}
