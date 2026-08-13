/// Codice destinatario SDI (Sistema di Interscambio), 7 caratteri alfanumerici.
class CodiceSdi {
  CodiceSdi._();

  static String normalize(String raw) => raw.trim().toUpperCase();

  /// Restituisce `null` se valido, altrimenti un messaggio di errore.
  static String? validate(String raw) {
    final code = normalize(raw);
    if (code.isEmpty) return 'Inserisci il codice destinatario SDI';
    if (code.length != 7) return 'Il codice SDI deve avere esattamente 7 caratteri';
    if (!RegExp(r'^[A-Z0-9]{7}$').hasMatch(code)) {
      return 'Il codice SDI può contenere solo lettere e numeri';
    }
    return null;
  }

  static bool isValid(String raw) => validate(raw) == null;
}
