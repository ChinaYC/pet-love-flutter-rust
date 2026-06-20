import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../src/rust/api/system.dart';
import '../settings/settings_drawer.dart';
import '../home/pages/time_machine_page.dart';
import '../home/pages/pet_status_page.dart';
import '../home/pages/account_page.dart';
import '../home/pages/inventory/inventory_page.dart';

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
  late PageController _pageController;

  final List<Widget> _pages = [
    const TimeMachinePage(),
    const PetStatusPage(),
    const AccountPage(),
    const InventoryPage(),
  ];

  final List<String> _routes = [
    '/time-machine',
    '/pet-status',
    '/account',
    '/inventory',
  ];

  @override
  void initState() {
    super.initState();
    _pageController =
        PageController(initialPage: widget.navigationShell.currentIndex);
  }

  @override
  void didUpdateWidget(MainLayoutPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationShell.currentIndex !=
        oldWidget.navigationShell.currentIndex) {
      _pageController.jumpToPage(widget.navigationShell.currentIndex);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (index != widget.navigationShell.currentIndex) {
      widget.navigationShell.goBranch(
        index,
        initialLocation: index == widget.navigationShell.currentIndex,
      );
    }
    // 保存当前页面状态到数据库
    setAppSetting(key: 'last_route', value: _routes[index]);
  }

  void _onItemTapped(int index) {
    if (index != widget.navigationShell.currentIndex) {
      widget.navigationShell.goBranch(
        index,
        initialLocation: index == widget.navigationShell.currentIndex,
      );
    }
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
          builder: (context) => GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.pinkAccent,
                child: Icon(Icons.favorite, color: Colors.white, size: 16),
              ),
            ),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _pages,
      ),
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
