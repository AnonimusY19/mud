import 'package:flutter/material.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/listings_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/profile_screen.dart';
import 'app_state.dart';
import 'theme/app_colors.dart';
import 'widgets/mud_app_drawer.dart';
import 'widgets/mud_site_header.dart';
import 'widgets/stripe_seller_gate.dart';

class MainShell extends StatefulWidget {
  final bool isGuest;

  const MainShell({super.key, this.isGuest = false});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;
  bool _stripePromptShown = false;

  List<Widget> get _pages => [
        HomeScreen(isGuest: widget.isGuest),
        if (!widget.isGuest) const ListingsScreen(),
        if (!widget.isGuest) const OrdersScreen(),
        if (!widget.isGuest) const ChatScreen(),
        if (!widget.isGuest) const ProfileScreen(),
      ];

  int _mapDrawerIndexToStack(int drawerIndex) {
    if (widget.isGuest) return 0;
    return drawerIndex.clamp(0, 4);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppScope.of(context).loadListings();
      _maybePromptStripe();
    });
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isGuest && !widget.isGuest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppScope.of(context).loadListings();
        _stripePromptShown = false;
        _maybePromptStripe();
      });
    }
  }

  void _maybePromptStripe() {
    if (widget.isGuest || _stripePromptShown || !mounted) return;
    final profile = AppScope.of(context).profile;
    if (profile?.needsStripeOnboarding != true) return;
    _stripePromptShown = true;
    showStripeRequiredDialogIfNeeded(context);
  }

  void _selectTab(int drawerIndex) {
    setState(() => _index = _mapDrawerIndexToStack(drawerIndex));
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    final safeIndex = _index.clamp(0, pages.length - 1);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: MudAppDrawer(
        isGuest: widget.isGuest,
        currentIndex: widget.isGuest ? 0 : safeIndex,
        onSelect: _selectTab,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (!widget.isGuest) const StripeSellerGateBanner(),
            MudSiteHeader(
              isGuest: widget.isGuest,
              onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
              onSelectTab: _selectTab,
            ),
            Expanded(
              child: IndexedStack(
                index: safeIndex,
                children: pages,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
