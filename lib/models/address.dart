/// Suggerimento autocomplete (fase di ricerca).
class AddressSuggestion {
  final String placeId;
  final String primaryText;
  final String secondaryText;

  const AddressSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
  });

  String get label {
    if (secondaryText.isEmpty) return primaryText;
    return '$primaryText, $secondaryText';
  }
}

/// Indirizzo strutturato recuperato da Place Details.
class Address {
  final String formattedAddress;
  final String street;
  final String streetNumber;
  final String city;
  final String province;
  final String postalCode;
  final String region;
  final String country;
  final double? latitude;
  final double? longitude;
  final String placeId;

  const Address({
    required this.formattedAddress,
    this.street = '',
    this.streetNumber = '',
    this.city = '',
    this.province = '',
    this.postalCode = '',
    this.region = '',
    this.country = '',
    this.latitude,
    this.longitude,
    this.placeId = '',
  });

  bool get isEmpty => formattedAddress.trim().isEmpty && placeId.isEmpty;

  Address copyWith({
    String? formattedAddress,
    String? street,
    String? streetNumber,
    String? city,
    String? province,
    String? postalCode,
    String? region,
    String? country,
    double? latitude,
    double? longitude,
    String? placeId,
  }) {
    return Address(
      formattedAddress: formattedAddress ?? this.formattedAddress,
      street: street ?? this.street,
      streetNumber: streetNumber ?? this.streetNumber,
      city: city ?? this.city,
      province: province ?? this.province,
      postalCode: postalCode ?? this.postalCode,
      region: region ?? this.region,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeId: placeId ?? this.placeId,
    );
  }

  factory Address.fromJson(Map<String, dynamic> json, {String formattedKey = 'address'}) {
    return Address(
      formattedAddress: (json[formattedKey] as String?)?.trim().isNotEmpty == true
          ? (json[formattedKey] as String).trim()
          : ((json['localita'] as String?) ?? (json['location'] as String?) ?? '').trim(),
      street: (json['street'] as String?) ?? '',
      streetNumber: (json['street_number'] as String?) ?? '',
      city: (json['city'] as String?) ?? '',
      province: (json['province'] as String?) ?? '',
      postalCode: (json['postal_code'] as String?) ?? '',
      region: (json['region'] as String?) ?? '',
      country: (json['country'] as String?) ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      placeId: (json['place_id'] as String?) ?? '',
    );
  }

  /// Payload per `profiles` (mantiene `localita` per retrocompatibilità).
  Map<String, dynamic> toProfileJson() {
    return {
      'localita': formattedAddress,
      'address': formattedAddress,
      'street': street,
      'street_number': streetNumber,
      'city': city,
      'province': province,
      'postal_code': postalCode,
      'region': region,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'place_id': placeId,
    };
  }

  /// Payload per `listings` (mantiene `location` per retrocompatibilità).
  Map<String, dynamic> toListingJson() {
    return {
      'location': formattedAddress,
      'street': street,
      'street_number': streetNumber,
      'city': city,
      'province': province,
      'postal_code': postalCode,
      'region': region,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'place_id': placeId,
    };
  }
}
