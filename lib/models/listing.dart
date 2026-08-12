import 'address.dart';

class Listing {
  final String id;
  final String userId;
  String type; // 'Vendo' oppure 'Cerco'
  String title;
  String description;
  String category;
  String location;
  double price;
  String unit;
  int quantity;
  String? imageUrl;
  Address address;
  // Backing field nullable: dopo hot reload gli oggetti già in memoria possono avere null.
  String? _companyName;

  String get companyName => _companyName ?? '';
  set companyName(String value) => _companyName = value;

  Listing({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.price,
    required this.unit,
    required this.quantity,
    this.imageUrl,
    Address? address,
    String companyName = '',
  })  : address = address ?? Address(formattedAddress: location),
        _companyName = companyName;

  Listing copyWith({
    String? companyName,
    Address? address,
    String? location,
    String? imageUrl,
  }) {
    return Listing(
      id: id,
      userId: userId,
      type: type,
      title: title,
      description: description,
      category: category,
      location: location ?? this.location,
      price: price,
      unit: unit,
      quantity: quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      address: address ?? this.address,
      companyName: companyName ?? this.companyName,
    );
  }

  factory Listing.fromJson(Map<String, dynamic> json) {
    final address = Address.fromJson(json, formattedKey: 'location');
    final location = (json['location'] as String?) ?? '';

    String companyName = '';
    final profile = json['profiles'];
    if (profile is Map) {
      companyName = (profile['nome_azienda'] as String?) ?? '';
    }

    return Listing(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'Altro',
      location: location.isNotEmpty ? location : address.formattedAddress,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      unit: (json['unit'] as String?) ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      imageUrl: json['image_url'] as String?,
      address: address.formattedAddress.isNotEmpty
          ? address
          : address.copyWith(formattedAddress: location),
      companyName: companyName,
    );
  }

  Map<String, dynamic> toInsertJson(String userId) {
    return {
      'user_id': userId,
      'type': type,
      'title': title,
      'description': description,
      'category': category,
      'price': price,
      'unit': unit,
      'quantity': quantity,
      'image_url': imageUrl,
      ...address.toListingJson(),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'type': type,
      'title': title,
      'description': description,
      'category': category,
      'price': price,
      'unit': unit,
      'quantity': quantity,
      'image_url': imageUrl,
      ...address.toListingJson(),
    };
  }
}

const List<String> kCategories = [
  'Alimentari',
  'Elettronica',
  'Abbigliamento',
  'Materie Prime',
  'Macchinari',
  'Servizi',
  'Logistica',
  'Altro',
];
