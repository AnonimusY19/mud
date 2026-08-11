import 'package:flutter/material.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/listings_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/mud_bottom_nav.dart';
import 'widgets/mud_header.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pages = [
    HomeScreen(),
    ListingsScreen(),
    OrdersScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const MudHeader(),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: IndexedStack(index: _index, children: _pages),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MudBottomNav(
        index: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}