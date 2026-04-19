String formatCurrency(double amount) {
  return 'Rs ${amount.toStringAsFixed(2)}';
}

String formatDateTime(DateTime? value) {
  if (value == null) {
    return 'Unknown time';
  }

  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';

  return '$day/$month/$year $hour:$minute $suffix';
}
