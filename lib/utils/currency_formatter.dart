class CurrencyFormatter {
  const CurrencyFormatter._();

  static String vnd(num amount) {
    final value = amount.round().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < value.length; i++) {
      final reverseIndex = value.length - i;
      buffer.write(value[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }

    return '${buffer.toString()} đ';
  }
}
