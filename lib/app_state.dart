import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/listing.dart';
import 'models/profile.dart';
import 'services/listing_service.dart';
import 'services/profile_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

enum AppMode { compra, vendi }

class AppState extends ChangeNotifier {
  AppState({
    ListingService? listingService,
    ProfileService? profileService,
  })  : _listingService = listingService ?? ListingService(),
        _profileService = profileService ?? ProfileService();

  static const _themeModeKey = 'mud_theme_mode';

  final ListingService _listingService;
  final ProfileService _profileService;

  AppMode mode = AppMode.compra;
  ThemeMode themeMode = ThemeMode.dark;
  Profile? profile;
  final List<Listing> listings = [];
  bool listingsLoading = false;
  String? listingsError;

  String? get currentUserId => _listingService.currentUserId;
  String? get currentUserEmail => _profileService.currentUserEmail;

  bool get isDarkTheme => themeMode != ThemeMode.light;

  Future<void> loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themeModeKey);
    final loaded = switch (raw) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    await setThemeMode(loaded, persist: false);
  }

  Future<void> setThemeMode(ThemeMode value, {bool persist = true}) async {
    themeMode = value;
    final brightness = value == ThemeMode.light
        ? Brightness.light
        : value == ThemeMode.dark
            ? Brightness.dark
            : WidgetsBinding.instance.platformDispatcher.platformBrightness;
    AppColors.applyBrightness(brightness);
    syncSystemUiOverlay(value == ThemeMode.system
        ? (brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light)
        : value);
    notifyListeners();
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _themeModeKey,
        switch (value) {
          ThemeMode.light => 'light',
          ThemeMode.system => 'system',
          ThemeMode.dark => 'dark',
        },
      );
    }
  }

  Future<void> setDarkTheme(bool dark) =>
      setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);

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
