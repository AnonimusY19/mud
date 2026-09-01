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
  final String? stripeAccountId;
  final bool stripeChargesEnabled;
  final bool stripeDetailsSubmitted;

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
    this.stripeAccountId,
    this.stripeChargesEnabled = false,
    this.stripeDetailsSubmitted = false,
  });

  bool get stripeReady => stripeChargesEnabled && (stripeAccountId?.isNotEmpty ?? false);

  /// Può pubblicare / vendere: Fornitore o Entrambi.
  bool get isSellerRole =>
      tipoAttivita == 'Fornitore' || tipoAttivita == 'Entrambi';

  /// Venditore senza Stripe completo: deve completare Connect.
  bool get needsStripeOnboarding => isSellerRole && !stripeReady;

  Profile copyWithStripe({
    String? stripeAccountId,
    bool? stripeChargesEnabled,
    bool? stripeDetailsSubmitted,
  }) {
    return Profile(
      id: id,
      nome: nome,
      cognome: cognome,
      codiceFiscale: codiceFiscale,
      nomeAzienda: nomeAzienda,
      partitaIva: partitaIva,
      codiceSdi: codiceSdi,
      tipoAttivita: tipoAttivita,
      descrizione: descrizione,
      localita: localita,
      telefono: telefono,
      logoUrl: logoUrl,
      modalita: modalita,
      address: address,
      stripeAccountId: stripeAccountId ?? this.stripeAccountId,
      stripeChargesEnabled: stripeChargesEnabled ?? this.stripeChargesEnabled,
      stripeDetailsSubmitted: stripeDetailsSubmitted ?? this.stripeDetailsSubmitted,
    );
  }

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
      stripeAccountId: json['stripe_account_id'] as String?,
      stripeChargesEnabled: json['stripe_charges_enabled'] == true,
      stripeDetailsSubmitted: json['stripe_details_submitted'] == true,
    );
  }
}
