/// Normalizzazione e validazione numeri telefono (E.164, default Italia).
class PhoneNumber {
  PhoneNumber._();

  /// Restituisce E.164 (es. +393331234567) oppure null se non valido.
  static String? normalize(String raw) {
    var value = raw.trim().replaceAll(RegExp(r'[\s\-./()]'), '');
    if (value.isEmpty) return null;

    if (value.startsWith('00')) {
      value = '+${value.substring(2)}';
    }
    if (!value.startsWith('+')) {
      if (value.startsWith('39') && value.length >= 11) {
        value = '+$value';
      } else {
        value = '+39$value';
      }
    }

    // Solo + e cifre
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value)) {
      return null;
    }
    return value;
  }

  static String? validate(String raw) {
    if (raw.trim().isEmpty) return 'Inserisci il numero di telefono';
    if (normalize(raw) == null) {
      return 'Numero non valido. Usa il formato +39...';
    }
    return null;
  }

  static String display(String e164) {
    if (e164.startsWith('+39') && e164.length == 13) {
      final rest = e164.substring(3);
      return '+39 ${rest.substring(0, 3)} ${rest.substring(3, 6)} ${rest.substring(6)}';
    }
    return e164;
  }
}
