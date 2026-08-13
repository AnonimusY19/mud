import '../app_state.dart';
import 'address.dart';

class Profile {
  final String id;
  final String nome;
  final String cognome;
  final String codiceFiscale;
  final String nomeAzienda;
  final String partitaIva;
  final String codiceSdi;
  final String tipoAttivita;
  final String descrizione;
  final String localita;
  final String telefono;
  final String? logoUrl;
  final AppMode modalita;
  final Address address;

  const Profile({
    required this.id,
    required this.nome,
    required this.cognome,
    required this.codiceFiscale,
    required this.nomeAzienda,
    this.partitaIva = '',
    this.codiceSdi = '',
    required this.tipoAttivita,
    required this.descrizione,
    required this.localita,
    required this.telefono,
    this.logoUrl,
    this.modalita = AppMode.compra,
    this.address = const Address(formattedAddress: ''),
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    final address = Address.fromJson(json, formattedKey: 'address');
    final localita = (json['localita'] as String?) ?? '';
    return Profile(
      id: json['id'] as String,
      nome: (json['nome'] as String?) ?? '',
      cognome: (json['cognome'] as String?) ?? '',
      codiceFiscale: (json['codice_fiscale'] as String?) ?? '',
      nomeAzienda: (json['nome_azienda'] as String?) ?? '',
      partitaIva: (json['partita_iva'] as String?) ?? '',
      codiceSdi: (json['codice_sdi'] as String?) ?? '',
      tipoAttivita: (json['tipo_attivita'] as String?) ?? 'Entrambi',
      descrizione: (json['descrizione'] as String?) ?? '',
      localita: localita.isNotEmpty ? localita : address.formattedAddress,
      telefono: (json['telefono'] as String?) ?? '',
      logoUrl: json['logo_url'] as String?,
      modalita: (json['modalita'] as String?) == 'vendi' ? AppMode.vendi : AppMode.compra,
      address: address.formattedAddress.isNotEmpty
          ? address
          : address.copyWith(formattedAddress: localita),
    );
  }
}
