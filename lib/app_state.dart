import 'package:flutter/material.dart';
import 'data/mock_data.dart';
import 'models/listing.dart';

enum AppMode { compra, vendi }

class AppState extends ChangeNotifier {
  AppMode mode = AppMode.compra;
  final List<Listing> listings = List.of(mockListings);

  void setMode(AppMode value) {
    if (mode == value) return;
    mode = value;
    notifyListeners();
  }

  void addListing(Listing listing) {
    listings.insert(0, listing);
    notifyListeners();
  }

  void updateListing(Listing listing) {
    final index = listings.indexWhere((l) => l.id == listing.id);
    if (index != -1) {
      listings[index] = listing;
      notifyListeners();
    }
  }

  void deleteListing(String id) {
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