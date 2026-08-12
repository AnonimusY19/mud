import 'package:flutter/material.dart';
import 'models/listing.dart';
import 'models/profile.dart';
import 'services/listing_service.dart';
import 'services/profile_service.dart';

enum AppMode { compra, vendi }

class AppState extends ChangeNotifier {
  AppState({
    ListingService? listingService,
    ProfileService? profileService,
  })  : _listingService = listingService ?? ListingService(),
        _profileService = profileService ?? ProfileService();

  final ListingService _listingService;
  final ProfileService _profileService;

  AppMode mode = AppMode.compra;
  Profile? profile;
  final List<Listing> listings = [];
  bool listingsLoading = false;
  String? listingsError;

  String? get currentUserId => _listingService.currentUserId;
  String? get currentUserEmail => _profileService.currentUserEmail;

  List<Listing> get myListings {
    final userId = currentUserId;
    if (userId == null) return const [];
    return listings.where((l) => l.userId == userId).toList();
  }

  void setMode(AppMode value) {
    if (mode == value) return;
    mode = value;
    notifyListeners();
  }

  void setProfile(Profile value) {
    profile = value;
    mode = value.modalita;
    notifyListeners();
  }

  /// Carica il profilo della sessione corrente. Lancia se non accessibile.
  Future<Profile> loadProfile() async {
    final loaded = await _profileService.fetchCurrentProfile();
    if (loaded == null) {
      throw StateError('Profilo non disponibile');
    }
    profile = loaded;
    mode = loaded.modalita;
    notifyListeners();
    return loaded;
  }

  void clearSessionData() {
    profile = null;
    listings.clear();
    listingsError = null;
    listingsLoading = false;
    mode = AppMode.compra;
    notifyListeners();
  }

  Future<void> loadListings() async {
    listingsLoading = true;
    listingsError = null;
    notifyListeners();
    try {
      final items = await _listingService.fetchAll();
      listings
        ..clear()
        ..addAll(items);
    } catch (_) {
      listingsError = 'Impossibile caricare gli annunci';
    } finally {
      listingsLoading = false;
      notifyListeners();
    }
  }

  Future<void> addListing(Listing listing) async {
    final created = await _listingService.create(listing);
    listings.insert(0, created);
    notifyListeners();
  }

  Future<void> updateListing(Listing listing) async {
    final updated = await _listingService.update(listing);
    final index = listings.indexWhere((l) => l.id == updated.id);
    if (index != -1) {
      listings[index] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteListing(String id) async {
    await _listingService.delete(id);
    listings.removeWhere((l) => l.id == id);
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({Key? key, required AppState state, required Widget child})
      : super(key: key, notifier: state, child: child);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope non trovato nell\'albero dei widget');
    return scope!.notifier!;
  }
}
