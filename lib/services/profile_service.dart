import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../models/address.dart';
import '../models/profile.dart';

class ProfileService {
  ProfileService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;
  String? get currentUserEmail => _client.auth.currentUser?.email;

  String _metaString(Map<String, dynamic> meta, String key) {
    final value = meta[key];
    if (value == null) return '';
    return value.toString().trim();
  }

  Future<Profile?> fetchCurrentProfile() async {
    final userResponse = await _client.auth.getUser();
    final authUser = userResponse.user;
    if (authUser == null) {
      throw StateError('Sessione non valida');
    }

    final meta = Map<String, dynamic>.from(authUser.userMetadata ?? {});
    final metaNome = _metaString(meta, 'nome');
    final metaCognome = _metaString(meta, 'cognome');
    final metaTelefono = _metaString(meta, 'telefono');
    final metaCf = _metaString(meta, 'codice_fiscale').toUpperCase();

    var row = await _client.from('profiles').select().eq('id', authUser.id).maybeSingle();

    final patch = <String, dynamic>{};
    if (row == null) {
      patch.addAll({
        'id': authUser.id,
        'nome': metaNome,
        'cognome': metaCognome,
        'telefono': metaTelefono,
        'codice_fiscale': metaCf,
      });
      row = await _client.from('profiles').upsert(patch).select().single();
    } else {
      final dbNome = (row['nome'] as String?)?.trim() ?? '';
      final dbCognome = (row['cognome'] as String?)?.trim() ?? '';
      final dbTelefono = (row['telefono'] as String?)?.trim() ?? '';
      final dbCf = (row['codice_fiscale'] as String?)?.trim() ?? '';

      if (dbNome.isEmpty && metaNome.isNotEmpty) patch['nome'] = metaNome;
      if (dbCognome.isEmpty && metaCognome.isNotEmpty) patch['cognome'] = metaCognome;
      if (dbTelefono.isEmpty && metaTelefono.isNotEmpty) patch['telefono'] = metaTelefono;
      if (dbCf.isEmpty && metaCf.isNotEmpty) patch['codice_fiscale'] = metaCf;

      if (patch.isNotEmpty) {
        row = await _client.from('profiles').update(patch).eq('id', authUser.id).select().single();
      }
    }

    final profile = Profile.fromJson(row);
    return Profile(
      id: profile.id,
      nome: profile.nome.isNotEmpty ? profile.nome : metaNome,
      cognome: profile.cognome.isNotEmpty ? profile.cognome : metaCognome,
      codiceFiscale: profile.codiceFiscale.isNotEmpty ? profile.codiceFiscale : metaCf,
      nomeAzienda: profile.nomeAzienda,
      tipoAttivita: profile.tipoAttivita,
      descrizione: profile.descrizione,
      localita: profile.localita,
      telefono: profile.telefono.isNotEmpty ? profile.telefono : metaTelefono,
      logoUrl: profile.logoUrl,
      modalita: profile.modalita,
      address: profile.address,
    );
  }

  Future<void> saveIdentityFields({
    required String nome,
    required String cognome,
    required String telefono,
    required String codiceFiscale,
    String? nomeAzienda,
    String? tipoAttivita,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;

    final identity = <String, dynamic>{
      'nome': nome.trim(),
      'cognome': cognome.trim(),
      'telefono': telefono.trim(),
      'codice_fiscale': codiceFiscale.trim().toUpperCase(),
    };
    if (nomeAzienda != null && nomeAzienda.trim().isNotEmpty) {
      identity['nome_azienda'] = nomeAzienda.trim();
    }

    final existing = await _client.from('profiles').select('id, tipo_attivita').eq('id', userId).maybeSingle();
    if (existing == null) {
      if (tipoAttivita == 'Fornitore' || tipoAttivita == 'Acquirente') {
        identity['tipo_attivita'] = tipoAttivita;
      }
      await _client.from('profiles').insert({'id': userId, ...identity});
    } else {
      // tipo_attivita non si aggiorna dopo la creazione (salvo backfill del default legacy)
      await _client.from('profiles').update(identity).eq('id', userId);
      final currentTipo = (existing['tipo_attivita'] as String?) ?? '';
      if ((tipoAttivita == 'Fornitore' || tipoAttivita == 'Acquirente') && currentTipo == 'Entrambi') {
        try {
          await _client
              .from('profiles')
              .update({'tipo_attivita': tipoAttivita})
              .eq('id', userId)
              .eq('tipo_attivita', 'Entrambi');
        } catch (_) {
          // Bloccato dal trigger DB: la scelta resta quella già salvata
        }
      }
    }
  }

  Future<Profile> saveCompanyProfile({
    required String nomeAzienda,
    required String descrizione,
    required Address address,
    String? logoUrl,
    required AppMode modalita,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw StateError('Utente non autenticato');
    }

    final data = await _client
        .from('profiles')
        .update({
          'nome_azienda': nomeAzienda.trim(),
          'descrizione': descrizione.trim(),
          'logo_url': logoUrl,
          'modalita': modalita == AppMode.vendi ? 'vendi' : 'compra',
          ...address.toProfileJson(),
        })
        .eq('id', userId)
        .select()
        .single();

    return Profile.fromJson(data);
  }
}
