class Listing {
  final String id;
  String type; // 'Vendo' oppure 'Cerco'
  String title;
  String description;
  String category;
  String location;
  double price;
  String unit;
  int quantity;
  String? imageUrl;

  Listing({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.price,
    required this.unit,
    required this.quantity,
    this.imageUrl,
  });
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