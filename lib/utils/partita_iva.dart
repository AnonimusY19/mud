/// Validazione Partita IVA italiana (11 cifre + carattere di controllo).
class PartitaIva {
  PartitaIva._();

  /// Normalizza: rimuove spazi e prefisso IT.
  static String normalize(String raw) {
    var value = raw.trim().toUpperCase().replaceAll(RegExp(r'[\s.]'), '');
    if (value.startsWith('IT')) {
      value = value.substring(2);
    }
    return value;
  }

  /// Restituisce `null` se valido, altrimenti un messaggio di errore.
  static String? validate(String raw) {
    final piva = normalize(raw);
    if (piva.isEmpty) return 'Inserisci la Partita IVA';
    if (!RegExp(r'^\d{11}$').hasMatch(piva)) {
      return 'La Partita IVA deve avere 11 cifre';
    }
    if (!_hasValidCheckDigit(piva)) {
      return 'Partita IVA non valida (cifra di controllo errata)';
    }
    return null;
  }

  static bool isValid(String raw) => validate(raw) == null;

  static bool _hasValidCheckDigit(String piva) {
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      var n = int.parse(piva[i]);
      if (i.isOdd) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
    }
    final check = (10 - (sum % 10)) % 10;
    return check == int.parse(piva[10]);
  }
}
