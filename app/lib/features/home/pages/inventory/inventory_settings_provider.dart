import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../src/rust/api/system.dart';

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

class InventorySettingsState {
  final List<CategoryGroup> categoryGroups;
  final int gridCrossAxisCount;
  final bool sortCategoryByCount;

  InventorySettingsState({
    required this.categoryGroups,
    required this.gridCrossAxisCount,
    this.sortCategoryByCount = false,
  });

  InventorySettingsState copyWith({
    List<CategoryGroup>? categoryGroups,
    int? gridCrossAxisCount,
    bool? sortCategoryByCount,
  }) {
    return InventorySettingsState(
      categoryGroups: categoryGroups ?? this.categoryGroups,
      gridCrossAxisCount: gridCrossAxisCount ?? this.gridCrossAxisCount,
      sortCategoryByCount: sortCategoryByCount ?? this.sortCategoryByCount,
    );
  }
}

class InventorySettingsNotifier extends StateNotifier<InventorySettingsState> {
  InventorySettingsNotifier()
      : super(InventorySettingsState(
          categoryGroups: [],
          gridCrossAxisCount: 2,
        )) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      // 1. Load default categories from JSON
      final String jsonString =
          await rootBundle.loadString('assets/categories.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      final List<CategoryGroup> defaultGroups = (jsonData['categories'] as List)
          .map((item) => CategoryGroup.fromJson(item))
          .toList();

      // 2. Load user customized categories from settings (if any)
      final catsStr = await getAppSetting(key: 'inventory_categories_v2');
      List<CategoryGroup> finalGroups = defaultGroups;

      if (catsStr != null && catsStr.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(catsStr);
          finalGroups =
              decoded.map((item) => CategoryGroup.fromJson(item)).toList();
        } catch (e) {
          debugPrint('Failed to parse saved categories: $e');
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

      state = state.copyWith(
          categoryGroups: finalGroups,
          gridCrossAxisCount: loadedGrid,
          sortCategoryByCount: loadedSort);
    } catch (e) {
      debugPrint('Failed to load inventory settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final catsStr =
          jsonEncode(state.categoryGroups.map((e) => e.toJson()).toList());
      await setAppSetting(key: 'inventory_categories_v2', value: catsStr);
      await setAppSetting(
          key: 'inventory_grid_count',
          value: state.gridCrossAxisCount.toString());
      await setAppSetting(
          key: 'inventory_sort_category_by_count',
          value: state.sortCategoryByCount.toString());
    } catch (e) {
      debugPrint('Failed to save inventory settings: $e');
    }
  }

  Future<void> updateGridCount(int count) async {
    state = state.copyWith(gridCrossAxisCount: count);
    await _saveSettings();
  }

  Future<void> toggleSortCategoryByCount(bool value) async {
    state = state.copyWith(sortCategoryByCount: value);
    await _saveSettings();
  }

  Future<void> addSubcategory(String groupName, String subcategory) async {
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
    state = state.copyWith(categoryGroups: newGroups);
    await _saveSettings();
  }

  Future<void> removeSubcategory(String groupName, String subcategory) async {
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
    state = state.copyWith(categoryGroups: newGroups);
    await _saveSettings();
  }

  Future<void> addCategoryGroup(String groupName) async {
    if (state.categoryGroups.any((g) => g.name == groupName)) return;
    final newGroups = [
      ...state.categoryGroups,
      CategoryGroup(name: groupName, subcategories: []),
    ];
    state = state.copyWith(categoryGroups: newGroups);
    await _saveSettings();
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
