/// Utilitário de formatação monetária em Real Brasileiro (BRL).
/// Evita dependências externas pesadas e garante padrão único em todo o app.
class CurrencyFormatter {
  CurrencyFormatter._();

  /// Formata um valor `double` para o padrão `R$ 20,00`.
  static String formatBRL(double value) {
    final isNegative = value < 0;
    final absoluteValue = value.abs();
    final parts = absoluteValue.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    final buffer = StringBuffer();
    for (int i = 0; i < integerPart.length; i++) {
      final positionFromRight = integerPart.length - i;
      buffer.write(integerPart[i]);
      if (positionFromRight > 1 && positionFromRight % 3 == 1) {
        buffer.write('.');
      }
    }

    final sign = isNegative ? '-' : '';
    return '${sign}R\$ ${buffer.toString()},$decimalPart';
  }
}
