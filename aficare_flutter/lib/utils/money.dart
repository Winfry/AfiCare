import 'package:intl/intl.dart';

/// Kenyan shilling amounts, handled the same way everywhere.
///
/// Amounts are added up in whole cents, so a total is never a few cents
/// off from the amounts it is made of, and shown with cents only when
/// there are any: "KES 1,500", "KES 150.50".
class Money {
  Money._();

  /// The largest amount accepted for one expense.
  static const maxAmount = 100000000.0;

  static int toCents(double amount) => (amount * 100).round();

  /// The sum of [amounts], exact to the cent.
  static double sum(Iterable<double> amounts) => amounts.fold<int>(0, (c, a) => c + toCents(a)) / 100;

  /// "KES 1,500" or "KES 150.50".
  static String kes(double amount) {
    final cents = toCents(amount);
    final format = NumberFormat(cents % 100 == 0 ? '#,##0' : '#,##0.00', 'en');
    return 'KES ${format.format(cents / 100)}';
  }

  /// How an amount is put back in a box to edit: "1500" or "150.50",
  /// never rounded.
  static String forEditing(double amount) {
    final cents = toCents(amount);
    return cents % 100 == 0 ? '${cents ~/ 100}' : (cents / 100).toStringAsFixed(2);
  }

  /// What she typed as an amount, or null when it is not one. Accepts
  /// "1,500", "1 500", "KES 1500" and "150.50"; at most two decimals.
  static double? parse(String text) {
    var t = text.trim().replaceAll(RegExp(r'^(kes|ksh\.|ksh|sh\.|sh)\s*', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'[,\s]'), '');
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(t)) return null;
    return toCents(double.parse(t)) / 100;
  }

  /// Why [text] is not an acceptable expense amount, or null when it is.
  static String? problemWith(String text) {
    if (text.trim().isEmpty) return 'Enter the amount';
    final v = parse(text);
    if (v == null) return 'Enter an amount like 1500 or 150.50';
    if (v <= 0) return 'The amount must be more than 0';
    if (v > maxAmount) return 'That is more than KES 100,000,000. Please check the amount';
    return null;
  }
}
