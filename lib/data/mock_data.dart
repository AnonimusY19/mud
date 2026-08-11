import '../models/listing.dart';

final List<Listing> mockListings = [
  Listing(
    id: '1',
    type: 'Vendo',
    title: 'Olio EVO extravergine toscano',
    description:
        'Olio extravergine di oliva toscano, prima spremitura a freddo. Confezioni da 5L.',
    category: 'Alimentari',
    location: 'Firenze',
    price: 45,
    unit: 'tanica 5L',
    quantity: 80,
    imageUrl: 'https://picsum.photos/seed/olio-evo-mud/800/600',
  ),
  Listing(
    id: '2',
    type: 'Cerco',
    title: 'Cerco forniture di caffè verde',
    description:
        'Ristorante cerca fornitore continuativo di caffè verde in grani, qualità arabica.',
    category: 'Alimentari',
    location: 'Milano',
    price: 4.20,
    unit: 'kg',
    quantity: 200,
    imageUrl: null,
  ),
  Listing(
    id: '3',
    type: 'Vendo',
    title: 'Pannelli solari monocristallini 450W',
    description:
        'Pannelli fotovoltaici monocristallini 450W, certificazione IEC. Stock pronto per consegna immediata.',
    category: 'Elettronica',
    location: 'Torino',
    price: 180,
    unit: 'pannello',
    quantity: 500,
    imageUrl: 'https://picsum.photos/seed/pannelli-solari-mud/800/600',
  ),
  Listing(
    id: '4',
    type: 'Cerco',
    title: 'Cerco tessuti di cotone biologico',
    description:
        'Azienda di abbigliamento cerca fornitore di tessuti in cotone biologico certificato GOTS.',
    category: 'Abbigliamento',
    location: 'Prato',
    price: 8.50,
    unit: 'metro',
    quantity: 1000,
    imageUrl: null,
  ),
  Listing(
    id: '5',
    type: 'Vendo',
    title: 'Trasporto refrigerato su gomma',
    description:
        'Servizio di trasporto con furgoni isotermici su tutto il territorio nazionale. Tariffe per chilometro.',
    category: 'Logistica',
    location: 'Bologna',
    price: 1.20,
    unit: 'km',
    quantity: 0,
    imageUrl: null,
  ),
];