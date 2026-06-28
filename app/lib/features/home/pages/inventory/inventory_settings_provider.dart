import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../../../src/rust/api/system.dart';
import '../../../../../../src/rust/api/inventory.dart';

class CategoryGroup {
  final String name;
  final List<String> subcategories;

  CategoryGroup({required this.name, required this.subcategories});

  factory CategoryGroup.fromJson(Map<String, dynamic> json) {
    return CategoryGroup(
      name: json['name'] as String,
      subcategories: List<String>.from(json['subcategories'] as List),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'subcategories': subcategories,
    };
  }
}

enum InventoryNavigationLayout {
  sidebar,
  top,
}

class InventorySettingsState {
  final List<CategoryGroup> categoryGroups;
  final int gridCrossAxisCount;
  final bool sortCategoryByCount;
  final InventoryNavigationLayout navigationLayout;

  InventorySettingsState({
    required this.categoryGroups,
    required this.gridCrossAxisCount,
    this.sortCategoryByCount = false,
    this.navigationLayout = InventoryNavigationLayout.sidebar,
  });

  InventorySettingsState copyWith({
    List<CategoryGroup>? categoryGroups,
    int? gridCrossAxisCount,
    bool? sortCategoryByCount,
    InventoryNavigationLayout? navigationLayout,
  }) {
    return InventorySettingsState(
      categoryGroups: categoryGroups ?? this.categoryGroups,
      gridCrossAxisCount: gridCrossAxisCount ?? this.gridCrossAxisCount,
      sortCategoryByCount: sortCategoryByCount ?? this.sortCategoryByCount,
      navigationLayout: navigationLayout ?? this.navigationLayout,
    );
  }
}

class InventorySettingsNotifier extends StateNotifier<InventorySettingsState> {
  InventorySettingsNotifier()
      : super(InventorySettingsState(
          categoryGroups: [],
          gridCrossAxisCount: 2,
        )) {
    _scheduleInitialLoad();
  }

  bool _initialLoadQueued = false;

  void _scheduleInitialLoad() {
    if (!_shouldDeferStateMutation()) {
      _loadSettings();
      return;
    }
    if (_initialLoadQueued) return;
    _initialLoadQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialLoadQueued = false;
      if (mounted) {
        _loadSettings();
      }
    });
  }

  bool _shouldDeferStateMutation() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    return phase == SchedulerPhase.transientCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks ||
        phase == SchedulerPhase.persistentCallbacks;
  }

  void _updateStateSafely(
    InventorySettingsState Function(InventorySettingsState current) update,
  ) {
    if (_shouldDeferStateMutation()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          state = update(state);
        }
      });
      return;
    }
    state = update(state);
  }

  Future<void> _loadSettings() async {
    try {
      // 优先从 Rust 数据库加载分类，支持动态扩展
      final dbCategories = await getInventoryCategories();
      List<CategoryGroup> finalGroups = [];

      if (dbCategories.isNotEmpty) {
        // 构建树形结构
        final parentMap = <String, InventoryCategory>{};
        for (var cat in dbCategories) {
          if (cat.parentId == null) {
            parentMap[cat.id] = cat;
          }
        }

        for (var parent in dbCategories.where((c) => c.parentId == null)) {
          final subs = dbCategories
              .where((c) => c.parentId == parent.id)
              .map((c) => c.name)
              .toList();
          finalGroups
              .add(CategoryGroup(name: parent.name, subcategories: subs));
        }
      } else {
        // 如果数据库为空，从 JSON 加载默认预设并保存到数据库
        final String jsonString =
            await rootBundle.loadString('assets/categories.json');
        final Map<String, dynamic> jsonData = jsonDecode(jsonString);
        finalGroups = (jsonData['categories'] as List)
            .map((item) => CategoryGroup.fromJson(item))
            .toList();

        // 将预设数据写入 Rust 数据库
        int order = 0;
        for (var group in finalGroups) {
          final parentId = await addInventoryCategory(
            name: group.name,
            parentId: null,
            sortOrder: order++,
            isPreset: true,
          );

          int subOrder = 0;
          for (var sub in group.subcategories) {
            await addInventoryCategory(
              name: sub,
              parentId: parentId,
              sortOrder: subOrder++,
              isPreset: true,
            );
          }
        }
      }

      // 3. Load grid count
      final gridStr = await getAppSetting(key: 'inventory_grid_count');
      int loadedGrid = state.gridCrossAxisCount;
      if (gridStr != null && gridStr.isNotEmpty) {
        loadedGrid = int.tryParse(gridStr) ?? state.gridCrossAxisCount;
      }

      // 4. Load sortCategoryByCount
      final sortStr =
          await getAppSetting(key: 'inventory_sort_category_by_count');
      bool loadedSort = state.sortCategoryByCount;
      if (sortStr != null && sortStr.isNotEmpty) {
        loadedSort = sortStr == 'true';
      }

      // 5. Load navigationLayout
      final navLayoutStr =
          await getAppSetting(key: 'inventory_navigation_layout');
      InventoryNavigationLayout loadedNavLayout;
      if (navLayoutStr != null && navLayoutStr.isNotEmpty) {
        loadedNavLayout = InventoryNavigationLayout.values.firstWhere(
          (e) => e.name == navLayoutStr,
          orElse: () => _getDefaultLayout(),
        );
      } else {
        loadedNavLayout = _getDefaultLayout();
      }

      _updateStateSafely(
        (current) => current.copyWith(
          categoryGroups: finalGroups,
          gridCrossAxisCount: loadedGrid,
          sortCategoryByCount: loadedSort,
          navigationLayout: loadedNavLayout,
        ),
      );
    } catch (e) {
      debugPrint('Failed to load inventory settings: $e');
    }
  }

  InventoryNavigationLayout _getDefaultLayout() {
    // 桌面端默认侧边栏，移动端默认顶部
    if (kIsWeb) return InventoryNavigationLayout.top;
    if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return InventoryNavigationLayout.sidebar;
    }
    return InventoryNavigationLayout.top;
  }

  Future<void> _saveSettings() async {
    try {
      await setAppSetting(
          key: 'inventory_grid_count',
          value: state.gridCrossAxisCount.toString());
      await setAppSetting(
          key: 'inventory_sort_category_by_count',
          value: state.sortCategoryByCount.toString());
      await setAppSetting(
          key: 'inventory_navigation_layout',
          value: state.navigationLayout.name);
    } catch (e) {
      debugPrint('Failed to save inventory settings: $e');
    }
  }

  Future<void> updateGridCount(int count) async {
    _updateStateSafely((current) => current.copyWith(gridCrossAxisCount: count));
    await _saveSettings();
  }

  Future<void> toggleSortCategoryByCount(bool value) async {
    _updateStateSafely(
      (current) => current.copyWith(sortCategoryByCount: value),
    );
    await _saveSettings();
  }

  Future<void> updateNavigationLayout(InventoryNavigationLayout layout) async {
    _updateStateSafely(
      (current) => current.copyWith(navigationLayout: layout),
    );
    await _saveSettings();
  }

  /// 确保分类存在，逻辑下沉到 Rust 层以获得更好性能和原子性
  Future<void> ensureCategoryExists(String parent, String? sub) async {
    try {
      await ensureInventoryCategory(parentName: parent, subName: sub);
      // 重新加载以保持内存状态同步
      await _loadSettings();
    } catch (e) {
      debugPrint('Failed to ensure category exists: $e');
    }
  }

  Future<void> addSubcategory(String groupName, String subcategory) async {
    try {
      // 1. 获取现有分类，查找对应的父级
      final dbCategories = await getInventoryCategories();
      final parent = dbCategories.firstWhere(
        (c) => c.name == groupName && c.parentId == null,
        orElse: () => throw Exception('找不到父分类'),
      );

      // 2. 写入数据库
      await addInventoryCategory(
        name: subcategory,
        parentId: parent.id,
        sortOrder: 999, // 默认追加到最后
        isPreset: false, // 用户手写输入的
      );

      // 3. 更新内存状态
      final newGroups = state.categoryGroups.map((group) {
        if (group.name == groupName) {
          if (!group.subcategories.contains(subcategory)) {
            return CategoryGroup(
              name: group.name,
              subcategories: [...group.subcategories, subcategory],
            );
          }
        }
        return group;
      }).toList();
      _updateStateSafely((current) => current.copyWith(categoryGroups: newGroups));
    } catch (e) {
      debugPrint('Failed to add subcategory: $e');
    }
  }

  Future<void> removeSubcategory(String groupName, String subcategory) async {
    try {
      // 从数据库中删除
      final dbCategories = await getInventoryCategories();
      final parent = dbCategories.firstWhere(
        (c) => c.name == groupName && c.parentId == null,
        orElse: () => throw Exception('找不到父分类'),
      );
      final sub = dbCategories.firstWhere(
        (c) => c.name == subcategory && c.parentId == parent.id,
        orElse: () => throw Exception('找不到子分类'),
      );

      await deleteInventoryCategory(id: sub.id);

      // 更新状态
      final newGroups = state.categoryGroups.map((group) {
        if (group.name == groupName) {
          return CategoryGroup(
            name: group.name,
            subcategories:
                group.subcategories.where((s) => s != subcategory).toList(),
          );
        }
        return group;
      }).toList();
      _updateStateSafely((current) => current.copyWith(categoryGroups: newGroups));
    } catch (e) {
      debugPrint('Failed to remove subcategory: $e');
    }
  }

  Future<void> addCategoryGroup(String groupName) async {
    if (state.categoryGroups.any((g) => g.name == groupName)) return;

    try {
      // 写入数据库
      await addInventoryCategory(
        name: groupName,
        parentId: null,
        sortOrder: state.categoryGroups.length,
        isPreset: false,
      );

      // 更新状态
      final newGroups = [
        ...state.categoryGroups,
        CategoryGroup(name: groupName, subcategories: []),
      ];
      _updateStateSafely((current) => current.copyWith(categoryGroups: newGroups));
    } catch (e) {
      debugPrint('Failed to add category group: $e');
    }
  }

  Future<void> reorderCategoryGroups(int oldIndex, int newIndex) async {
    final List<CategoryGroup> newGroups = List.from(state.categoryGroups);
    final CategoryGroup group = newGroups.removeAt(oldIndex);
    newGroups.insert(newIndex, group);

    // 更新数据库中的排序
    try {
      final dbCategories = await getInventoryCategories();
      for (int i = 0; i < newGroups.length; i++) {
        final g = newGroups[i];
        final dbCat = dbCategories
            .firstWhere((c) => c.name == g.name && c.parentId == null);
        await updateInventoryCategory(
          id: dbCat.id,
          name: dbCat.name,
          parentId: null,
          sortOrder: i,
        );
      }
    } catch (e) {
      debugPrint('Failed to reorder category groups: $e');
    }

    _updateStateSafely((current) => current.copyWith(categoryGroups: newGroups));
  }

  // Helper to get flat list of subcategories for backward compatibility if needed,
  // or for simple dropdowns.
  List<String> get allSubcategories {
    return state.categoryGroups.expand((group) => group.subcategories).toList();
  }
}

final inventorySettingsProvider =
    StateNotifierProvider<InventorySettingsNotifier, InventorySettingsState>(
        (ref) {
  return InventorySettingsNotifier();
});
