import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../../../src/rust/api/inventory.dart';
import '../../../../../../src/rust/api/system.dart';
import 'widgets/inventory_item_card.dart';
import 'widgets/inventory_item_skeleton.dart';
import 'widgets/add_inventory_dialog.dart';
import 'widgets/category_picker_sheet.dart';
import 'inventory_mutation_service.dart';
import 'inventory_settings_provider.dart';
import 'inventory_settings_page.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  List<GroupedInventoryItems> _groupedItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  // 搜索和选择模式
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  // 滚动和分类定位
  final ScrollController _scrollController = ScrollController();
  final ScrollController _topScrollController = ScrollController();
  final Map<String, GlobalKey> _categoryKeys = {};
  final Map<String, GlobalKey> _navKeys = {};
  String _activeCategory = '';

  @override
  void initState() {
    super.initState();
    _loadItems().then((_) {
      if (mounted) {
        _restoreDialogState();
      }
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _topScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // 简单的滚动监听，更新当前激活的分类
    if (_categoryKeys.isEmpty || _groupedItems.length <= 1) return;

    // 增加：如果是过度滚动（下拉刷新或底部回弹），不进行分类切换计算，避免抖动
    if (!_scrollController.hasClients ||
        _scrollController.offset < -20 ||
        _scrollController.offset >
            _scrollController.position.maxScrollExtent + 20) {
      return;
    }

    String? mostVisibleCategory;
    double minDistance = double.infinity;

    // 获取列表容器的顶部位置作为参考阈值
    // 考虑到顶部可能有 AppBar 和顶部导航栏
    final settings = ref.read(inventorySettingsProvider);
    final bool isTopNav =
        settings.navigationLayout == InventoryNavigationLayout.top;

    // 基础偏移：状态栏 + 两个 AppBar (外部 MainLayout + 内部 InventoryPage)
    // 内部 AppBar 高度为 kToolbarHeight (56)
    // 外部 AppBar 高度也为 kToolbarHeight
    final double threshold = MediaQuery.of(context).padding.top +
        kToolbarHeight +
        kToolbarHeight +
        (isTopNav ? 50 : 0);

    for (var entry in _categoryKeys.entries) {
      final context = entry.value.currentContext;
      if (context != null) {
        final renderObject = context.findRenderObject();
        if (renderObject is RenderBox) {
          final position = renderObject.localToGlobal(Offset.zero).dy;

          // 计算距离阈值的距离
          final distance = (position - threshold).abs();

          // 如果该分类头部在阈值附近，且是目前最接近阈值的
          // 我们给一个宽容度（-20），确保刚好滚过去一点也能识别
          if (position >= threshold - 40 && distance < minDistance) {
            minDistance = distance;
            mostVisibleCategory = entry.key;
          }
        }
      }
    }

    if (mostVisibleCategory != null && mostVisibleCategory != _activeCategory) {
      setState(() {
        _activeCategory = mostVisibleCategory!;
      });
      _syncCategoryNav(mostVisibleCategory);
    }
  }

  void _syncCategoryNav(String category) {
    final settings = ref.read(inventorySettingsProvider);
    if (settings.navigationLayout == InventoryNavigationLayout.top) {
      final key = _navKeys[category];
      if (key != null && key.currentContext != null) {
        // 使用 ensureVisible 而不是手动计算偏移
        // 这会确保项在视图内，但如果已经在视图内则不会滚动
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    }
  }

  void _scrollToCategory(String category) {
    final key = _categoryKeys[category];
    if (key != null && key.currentContext != null) {
      // 停止当前的滚动监听，避免循环触发
      _scrollController.removeListener(_onScroll);

      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ).then((_) {
        // 滚动完成后重新加上监听
        if (mounted) {
          _scrollController.addListener(_onScroll);
        }
      });

      setState(() {
        _activeCategory = category;
      });
      // 手动同步一次导航栏位置
      _syncCategoryNav(category);
    }
  }

  Future<void> _restoreDialogState() async {
    try {
      final stateJson = await getAppSetting(key: 'inventory_dialog_state');
      if (!mounted) return;
      if (stateJson != null && stateJson.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(stateJson);
        if (data['isOpen'] == true) {
          if (data['mode'] == 'add') {
            _showAddDialog(isRestoring: true);
          } else if (data['mode'] == 'edit' && data['itemId'] != null) {
            InventoryItem? foundItem;
            for (var group in _groupedItems) {
              for (var item in group.items) {
                if (item.id == data['itemId']) {
                  foundItem = item;
                  break;
                }
              }
              if (foundItem != null) break;
            }
            if (foundItem != null) {
              _showEditDialog(foundItem, isRestoring: true);
            } else {
              // Item no longer exists, clear state
              _updateDialogState(isOpen: false);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('恢复弹窗状态失败: $e');
    }
  }

  Future<void> _updateDialogState(
      {required bool isOpen, String? mode, String? itemId}) async {
    final state = {
      'isOpen': isOpen,
      'mode': mode,
      'itemId': itemId,
    };
    await setAppSetting(
        key: 'inventory_dialog_state', value: jsonEncode(state));
  }

  Future<void> _loadItems() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final groups = await searchAndGroupInventoryItems(query: _searchQuery);
      if (!mounted) return;
      setState(() {
        _groupedItems = groups;
        _isLoading = false;
        if (_activeCategory.isEmpty && groups.isNotEmpty) {
          _activeCategory = groups.first.category;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _batchDelete() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await AppDialog.show<bool>(
      context: context,
      title: const Text('确认批量删除'),
      content: Text('确定要删除选中的 ${_selectedIds.length} 条记录吗？'),
      actions: [
        Builder(
          builder: (dialogContext) => TextButton(
            onPressed: () {
              if (Navigator.canPop(dialogContext)) {
                Navigator.of(dialogContext).pop(false);
              }
            },
            child: const Text('取消'),
          ),
        ),
        Builder(
          builder: (dialogContext) => ElevatedButton(
            onPressed: () {
              if (Navigator.canPop(dialogContext)) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ),
      ],
    );

    if (confirm == true) {
      final deleteCount = _selectedIds.length;
      try {
        await ref
            .read(inventoryMutationServiceProvider)
            .batchDeleteItems(ids: _selectedIds.toList());
        setState(() {
          _isSelectionMode = false;
          _selectedIds.clear();
        });
        _loadItems();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已成功删除 $deleteCount 项'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('批量删除失败: $e')),
          );
        }
      }
    }
  }

  void _showAddDialog({bool isRestoring = false}) {
    if (!isRestoring) {
      _updateDialogState(isOpen: true, mode: 'add');
    }
    AppDialog.showRaw(
      context: context,
      child: AddInventoryDialog(
        onSaved: _loadItems,
      ),
    ).then((_) => _updateDialogState(isOpen: false));
  }

  void _showEditDialog(InventoryItem item, {bool isRestoring = false}) {
    if (!isRestoring) {
      _updateDialogState(isOpen: true, mode: 'edit', itemId: item.id);
    }
    AppDialog.showRaw(
      context: context,
      child: AddInventoryDialog(
        initialItem: item,
        onSaved: _loadItems,
      ),
    ).then((_) => _updateDialogState(isOpen: false));
  }

  Future<void> _batchUpdateCategory() async {
    if (_selectedIds.isEmpty) return;

    final settings = ref.read(inventorySettingsProvider);
    Map<String, int> categoryCounts = {};
    try {
      final stats = await getCategoryStats();
      for (final stat in stats) {
        categoryCounts[stat.name] = stat.count;
      }
    } catch (e) {
      debugPrint('Failed to get category stats: $e');
    }

    if (!mounted) return;

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CategoryPickerSheet(
        categories: settings.categoryGroups,
        categoryCounts: categoryCounts,
        sortByCount: settings.sortCategoryByCount,
      ),
    );

    if (result != null && result['parent'] != null) {
      final newCategory = result['sub'] != null
          ? '${result['parent']} / ${result['sub']}'
          : result['parent']!;
      try {
        await ref.read(inventoryMutationServiceProvider).batchUpdateCategory(
              ids: _selectedIds.toList(),
              category: newCategory,
            );
        setState(() {
          _isSelectionMode = false;
          _selectedIds.clear();
        });
        _loadItems();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('批量修改失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(inventorySettingsProvider);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      primary: false,
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedIds.clear();
                }),
              ),
              title: Text('已选择 ${_selectedIds.length} 项'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.drive_file_rename_outline),
                  onPressed: _batchUpdateCategory,
                  tooltip: '批量修改品类',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _batchDelete,
                  tooltip: '批量删除',
                ),
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: () {
                    setState(() {
                      final allIds = _groupedItems
                          .expand((g) => g.items.map((i) => i.id))
                          .toList();
                      final isAllSelected =
                          allIds.every((id) => _selectedIds.contains(id));
                      if (isAllSelected) {
                        for (var id in allIds) {
                          _selectedIds.remove(id);
                        }
                      } else {
                        _selectedIds.addAll(allIds);
                      }
                    });
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.grid_view),
                  tooltip: '视图与设置',
                  onSelected: (value) {
                    if (value.startsWith('grid_')) {
                      final count = int.parse(value.split('_')[1]);
                      ref
                          .read(inventorySettingsProvider.notifier)
                          .updateGridCount(count);
                    } else if (value == 'layout') {
                      final newLayout = settings.navigationLayout ==
                              InventoryNavigationLayout.sidebar
                          ? InventoryNavigationLayout.top
                          : InventoryNavigationLayout.sidebar;
                      ref
                          .read(inventorySettingsProvider.notifier)
                          .updateNavigationLayout(newLayout);
                    } else if (value == 'settings') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const InventorySettingsPage(),
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'grid_1',
                      child: ListTile(
                        leading: Icon(Icons.view_agenda_outlined),
                        title: Text('大卡片 (1列)'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'grid_2',
                      child: ListTile(
                        leading: Icon(Icons.grid_view),
                        title: Text('中卡片 (2列)'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'grid_3',
                      child: ListTile(
                        leading: Icon(Icons.grid_on),
                        title: Text('小卡片 (3列)'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'layout',
                      child: ListTile(
                        leading: Icon(
                          settings.navigationLayout ==
                                  InventoryNavigationLayout.sidebar
                              ? Icons.view_stream_outlined
                              : Icons.view_sidebar_outlined,
                        ),
                        title: Text(settings.navigationLayout ==
                                InventoryNavigationLayout.sidebar
                            ? '切换到顶部导航'
                            : '切换到侧边导航'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'settings',
                      child: ListTile(
                        leading: Icon(Icons.settings_outlined),
                        title: Text('分类与设置'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : AppBar(
              title: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索囤货...',
                  prefixIcon: const Icon(Icons.search),
                  border: InputBorder.none,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _searchQuery = '';
                            _loadItems();
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  _searchQuery = value;
                  _loadItems();
                },
              ),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.library_add_check_outlined),
                  tooltip: '管理与设置',
                  onSelected: (value) {
                    switch (value) {
                      case 'select':
                        setState(() => _isSelectionMode = true);
                        break;
                      case 'layout':
                        final newLayout = settings.navigationLayout ==
                                InventoryNavigationLayout.sidebar
                            ? InventoryNavigationLayout.top
                            : InventoryNavigationLayout.sidebar;
                        ref
                            .read(inventorySettingsProvider.notifier)
                            .updateNavigationLayout(newLayout);
                        break;
                      case 'settings':
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const InventorySettingsPage(),
                          ),
                        );
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'select',
                      child: ListTile(
                        leading: Icon(Icons.library_add_check_outlined),
                        title: Text('批量管理'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'layout',
                      child: ListTile(
                        leading: Icon(
                          settings.navigationLayout ==
                                  InventoryNavigationLayout.sidebar
                              ? Icons.view_stream_outlined
                              : Icons.view_sidebar_outlined,
                        ),
                        title: Text(settings.navigationLayout ==
                                InventoryNavigationLayout.sidebar
                            ? '切换到顶部导航'
                            : '切换到侧边导航'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'settings',
                      child: ListTile(
                        leading: Icon(Icons.settings_outlined),
                        title: Text('分类与设置'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: _buildBody(settings),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: _showAddDialog,
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildBody(InventorySettingsState settings) {
    if (_isLoading) {
      return _buildLoadingSkeleton(settings);
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadItems,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_groupedItems.isEmpty) {
      return Center(
        child: Text(_searchQuery.isEmpty ? '暂无囤货记录，点击右下角添加吧！' : '未找到相关物品'),
      );
    }

    final isSidebar =
        settings.navigationLayout == InventoryNavigationLayout.sidebar;

    return Column(
      children: [
        // 顶部导航 (当选择顶部布局时)
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: !isSidebar && _groupedItems.length > 1 ? 50 : 0,
          child: !isSidebar && _groupedItems.length > 1
              ? Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    border: Border(
                      bottom: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: ListView.builder(
                    controller: _topScrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: _groupedItems.length,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemBuilder: (context, index) {
                      final group = _groupedItems[index];
                      final cat = group.category;
                      final isActive = cat == _activeCategory;
                      return Padding(
                        key: _navKeys.putIfAbsent(cat, () => GlobalKey()),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isActive,
                          onSelected: (_) => _scrollToCategory(cat),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: isActive
                                ? Theme.of(context).colorScheme.onPrimary
                                : null,
                          ),
                          selectedColor: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    },
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: Row(
            children: [
              // 左侧分类导航 (当选择侧边栏布局时)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: isSidebar && _groupedItems.length > 1 ? 90 : 0,
                decoration: BoxDecoration(
                  border: Border(
                      right: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: isSidebar && _groupedItems.length > 1
                    ? ListView.builder(
                        itemCount: _groupedItems.length,
                        itemBuilder: (context, index) {
                          final group = _groupedItems[index];
                          final cat = group.category;
                          final isActive = cat == _activeCategory;
                          final count = group.count;
                          return InkWell(
                            onTap: () => _scrollToCategory(cat),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 4),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withValues(alpha: 0.3)
                                    : null,
                                border: isActive
                                    ? Border(
                                        left: BorderSide(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            width: 4))
                                    : null,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    cat,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isActive
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isActive
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : null,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (count > 0)
                                    Text(
                                      '$count件',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isActive
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context).hintColor,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    : const SizedBox.shrink(),
              ),
              // 右侧列表
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadItems,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      for (var group in _groupedItems) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            key: _categoryKeys.putIfAbsent(
                                group.category, () => GlobalKey()),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              group.category,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: settings.gridCrossAxisCount,
                              childAspectRatio: settings.gridCrossAxisCount == 1
                                  ? 2.2
                                  : (settings.gridCrossAxisCount == 2
                                      ? 0.8
                                      : 0.7),
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = group.items[index];
                                return InventoryItemCard(
                                  item: item,
                                  onEdit: () => _showEditDialog(item),
                                  isSelectionMode: _isSelectionMode,
                                  isSelected: _selectedIds.contains(item.id),
                                  isWideLayout:
                                      settings.gridCrossAxisCount == 1,
                                  onSelectedChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedIds.add(item.id);
                                      } else {
                                        _selectedIds.remove(item.id);
                                      }
                                    });
                                  },
                                );
                              },
                              childCount: group.items.length,
                            ),
                          ),
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton(InventorySettingsState settings) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: settings.gridCrossAxisCount,
        childAspectRatio: settings.gridCrossAxisCount == 1
            ? 2.2
            : (settings.gridCrossAxisCount == 2 ? 0.8 : 0.7),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 8, // 显示 8 个骨架
      itemBuilder: (context, index) => InventoryItemSkeleton(
        isWideLayout: settings.gridCrossAxisCount == 1,
      ),
    );
  }
}
