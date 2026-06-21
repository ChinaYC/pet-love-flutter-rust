import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../src/rust/api/system.dart';
import '../settings/settings_drawer.dart';
import '../settings/widgets/user_avatar_header.dart';

class MainLayoutPage extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainLayoutPage({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<MainLayoutPage> createState() => _MainLayoutPageState();
}

class _MainLayoutPageState extends ConsumerState<MainLayoutPage> {
  final List<String> _routes = [
    '/time-machine',
    '/pet-status',
    '/account',
    '/inventory',
  ];

  void _onItemTapped(int index) {
    final isCurrentBranch = index == widget.navigationShell.currentIndex;
    widget.navigationShell.goBranch(
      index,
      initialLocation: isCurrentBranch,
    );
    setAppSetting(key: 'last_route', value: _routes[index]);
  }

  final List<String> _titles = [
    '时光机',
    '宠物状态',
    '账本统计',
    '囤货清单',
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;

    return Scaffold(
      drawer: const SettingsDrawer(),
      appBar: AppBar(
        title: Text(_titles[currentIndex]),
        leading: Builder(
          builder: (context) => const UserAvatarHeader(isExpanded: false),
        ),
      ),
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BottomNavigationBar(
            currentIndex: widget.navigationShell.currentIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Colors.grey,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.book), label: '时光机'),
              BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.paw_solid), label: '宠物'),
              BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.money_dollar), label: '账本'),
              BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.time), label: '囤货'),
            ],
          ),
        ),
      ),
    );
  }
}
