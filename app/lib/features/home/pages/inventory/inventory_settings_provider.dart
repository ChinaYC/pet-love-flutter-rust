import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../src/rust/api/system.dart';

final inventorySettingsProvider = StateNotifierProvider<InventorySettingsNotifier, InventorySettingsState>((ref) {
  return InventorySettingsNotifier();
});

class InventorySettingsState {
  final List<String> categories;
  final int gridCrossAxisCount;

  InventorySettingsState({
    required this.categories,
    required this.gridCrossAxisCount,
  });

  InventorySettingsState copyWith({
    List<String>? categories,
    int? gridCrossAxisCount,
  }) {
    return InventorySettingsState(
      categories: categories ?? this.categories,
      gridCrossAxisCount: gridCrossAxisCount ?? this.gridCrossAxisCount,
    );
  }
}

class InventorySettingsNotifier extends StateNotifier<InventorySettingsState> {
  InventorySettingsNotifier() : super(InventorySettingsState(
    categories: ['主粮', '零食', '保健品', '日用品', '玩具', '其他'],
    gridCrossAxisCount: 2,
  )) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final catsStr = await getAppSetting(key: 'inventory_categories');
      final gridStr = await getAppSetting(key: 'inventory_grid_count');
      
      List<String> loadedCats = state.categories;
      if (catsStr != null && catsStr.isNotEmpty) {
        loadedCats = _normalizeCategories(List<String>.from(jsonDecode(catsStr)));
      }

      int loadedGrid = state.gridCrossAxisCount;
      if (gridStr != null && gridStr.isNotEmpty) {
        loadedGrid = _normalizeGridCount(int.tryParse(gridStr) ?? state.gridCrossAxisCount);
      }

      state = state.copyWith(categories: loadedCats, gridCrossAxisCount: loadedGrid);
    } catch (e) {
      debugPrint('Failed to load inventory settings: $e');
    }
  }

  /// 功能：统一清洗分类数据，去重、去空白，并强制把“其他”兜底放到最后。
  /// 参数：`categories` 为待清洗的分类列表。
  /// 返回值：返回可安全展示和持久化的分类列表。
  /// 注意事项：保存前必须再次调用，避免拖拽、历史配置或重复添加导致脏数据写入。
  List<String> _normalizeCategories(List<String> categories) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final category in categories) {
      final trimmed = category.trim();
      if (trimmed.isEmpty || trimmed == '其他' || seen.contains(trimmed)) {
        continue;
      }
      normalized.add(trimmed);
      seen.add(trimmed);
    }
    normalized.add('其他');
    return normalized;
  }

  /// 功能：限制卡片列数配置的合法范围。
  /// 参数：`count` 为用户选择的列数。
  /// 返回值：返回 1 到 3 之间的安全列数。
  /// 注意事项：持久化前统一调用，避免异常值影响列表布局。
  int _normalizeGridCount(int count) {
    return count.clamp(1, 3).toInt();
  }

  Future<void> addCategory(String category) async {
    final normalizedInput = category.trim();
    if (normalizedInput.isEmpty || state.categories.contains(normalizedInput)) return;

    final newCats = _normalizeCategories([...state.categories, normalizedInput]);
    state = state.copyWith(categories: newCats);
    await _saveSettings();
  }

  Future<void> removeCategory(String category) async {
    if (category == '其他') return; // 不能删除默认的"其他"
    final newCats = _normalizeCategories(
      List<String>.from(state.categories)..remove(category),
    );
    state = state.copyWith(categories: newCats);
    await _saveSettings();
  }

  Future<void> removeCategories(List<String> categories) async {
    final toRemove = categories.where((cat) => cat != '其他').toSet();
    if (toRemove.isEmpty) return;

    final newCats = _normalizeCategories(
      state.categories.where((cat) => !toRemove.contains(cat)).toList(),
    );
    state = state.copyWith(categories: newCats);
    await _saveSettings();
  }

  /// 功能：调整自定义分类顺序并立即持久化。
  /// 参数：`oldIndex` 为拖拽前位置，`newIndex` 为拖拽后位置。
  /// 返回值：无。
  /// 注意事项：仅允许调整“其他”之前的分类，“其他”始终固定在最后。
  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    final movableCategories = state.categories.where((category) => category != '其他').toList();
    if (movableCategories.isEmpty) return;

    var targetIndex = newIndex;
    if (targetIndex > movableCategories.length) {
      targetIndex = movableCategories.length;
    }
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }
    if (oldIndex == targetIndex || oldIndex >= movableCategories.length || targetIndex < 0) {
      return;
    }

    final movedCategory = movableCategories.removeAt(oldIndex);
    movableCategories.insert(targetIndex, movedCategory);

    state = state.copyWith(categories: _normalizeCategories(movableCategories));
    await _saveSettings();
  }

  Future<void> updateGridCount(int count) async {
    state = state.copyWith(gridCrossAxisCount: _normalizeGridCount(count));
    await _saveSettings();
  }

  /// 功能：在写入设置前执行最后一次兜底归一化并保存。
  /// 参数：无。
  /// 返回值：无。
  /// 注意事项：这是最终持久化入口，不能只依赖前面的交互事件来保证数据正确。
  Future<void> _saveSettings() async {
    try {
      final normalizedCategories = _normalizeCategories(state.categories);
      final normalizedGridCount = _normalizeGridCount(state.gridCrossAxisCount);
      state = state.copyWith(
        categories: normalizedCategories,
        gridCrossAxisCount: normalizedGridCount,
      );

      await setAppSetting(key: 'inventory_categories', value: jsonEncode(state.categories));
      await setAppSetting(key: 'inventory_grid_count', value: state.gridCrossAxisCount.toString());
    } catch (e) {
      debugPrint('Failed to save inventory settings: $e');
    }
  }
}
