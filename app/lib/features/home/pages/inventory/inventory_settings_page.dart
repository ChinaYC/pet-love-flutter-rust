import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../theme/theme_provider.dart';
import 'inventory_settings_provider.dart';

class InventorySettingsPage extends ConsumerStatefulWidget {
  const InventorySettingsPage({super.key});

  @override
  ConsumerState<InventorySettingsPage> createState() =>
      _InventorySettingsPageState();
}

class _InventorySettingsPageState extends ConsumerState<InventorySettingsPage> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(inventorySettingsProvider);
    final theme = context.theme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('分类与偏好设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text('分类显示偏好',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            color: context.adaptiveSecondaryBackgroundColor,
            child: SwitchListTile(
              title: const Text('选择品类时按物品数量排序'),
              subtitle: const Text('开启后，包含物品较多的分类会排在前面'),
              value: settings.sortCategoryByCount,
              onChanged: (val) {
                ref
                    .read(inventorySettingsProvider.notifier)
                    .toggleSortCategoryByCount(val);
              },
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('预设分类',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _showAddGroupDialog,
                tooltip: '添加一级分类',
              ),
            ],
          ),
          const SizedBox(height: 8),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: settings.categoryGroups.length,
            onReorderItem: (oldIndex, newIndex) {
              ref
                  .read(inventorySettingsProvider.notifier)
                  .reorderCategoryGroups(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final group = settings.categoryGroups[index];
              return _buildCategoryGroup(group,
                  key: ValueKey(group.name), index: index);
            },
          ),
          const SizedBox(height: 24),
          Text('列表视图控制',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            color: context.adaptiveSecondaryBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: RadioGroup<int>(
                groupValue: settings.gridCrossAxisCount,
                onChanged: (val) {
                  if (val != null) {
                    ref
                        .read(inventorySettingsProvider.notifier)
                        .updateGridCount(val);
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('设置卡片每行显示数量'),
                    const SizedBox(height: 16),
                    _buildGridOption(context, '大卡片 (单列)', 1),
                    _buildGridOption(context, '中等卡片 (双列)', 2),
                    _buildGridOption(context, '小卡片 (三列)', 3),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGroup(CategoryGroup group,
      {required int index, Key? key}) {
    final theme = context.theme;
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      color: context.adaptiveSecondaryBackgroundColor,
      child: ExpansionTile(
        title: ReorderableDragStartListener(
          index: index,
          child: Row(
            children: [
              const Icon(Icons.drag_indicator, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '包含 ${group.subcategories.length} 个子分类',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => _showAddSubcategoryDialog(group.name),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: group.subcategories.map((sub) {
                return InputChip(
                  label: Text(sub),
                  backgroundColor: context.colorScheme.primaryContainer
                      .withValues(alpha: 0.2),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  onDeleted: () {
                    ref
                        .read(inventorySettingsProvider.notifier)
                        .removeSubcategory(group.name, sub);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSubcategoryDialog(String groupName) {
    final controller = TextEditingController();
    AppDialog.show(
      context: context,
      title: Text('添加子分类到 $groupName'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(hintText: '输入分类名称'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final val = controller.text.trim();
            if (val.isNotEmpty) {
              ref
                  .read(inventorySettingsProvider.notifier)
                  .addSubcategory(groupName, val);
              if (context.mounted && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            }
          },
          child: const Text('添加'),
        ),
      ],
    );
  }

  void _showAddGroupDialog() {
    final controller = TextEditingController();
    AppDialog.show(
      context: context,
      title: const Text('添加一级分类'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(hintText: '输入分类名称'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final val = controller.text.trim();
            if (val.isNotEmpty) {
              ref
                  .read(inventorySettingsProvider.notifier)
                  .addCategoryGroup(val);
              if (context.mounted && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            }
          },
          child: const Text('添加'),
        ),
      ],
    );
  }

  Widget _buildGridOption(BuildContext context, String label, int value) {
    return RadioListTile<int>.adaptive(
      title: Text(label),
      value: value,
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeColor: context.colorScheme.primary,
    );
  }
}
