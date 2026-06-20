import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'inventory_settings_provider.dart';

class InventorySettingsPage extends ConsumerStatefulWidget {
  const InventorySettingsPage({super.key});

  @override
  ConsumerState<InventorySettingsPage> createState() =>
      _InventorySettingsPageState();
}

class _InventorySettingsPageState extends ConsumerState<InventorySettingsPage> {
  final TextEditingController _categoryController = TextEditingController();
  bool _isEditing = false;
  final Set<String> _selectedCategories = {};

  void _addCategory() {
    final val = _categoryController.text.trim();
    if (val.isNotEmpty) {
      ref.read(inventorySettingsProvider.notifier).addCategory(val);
      _categoryController.clear();
    }
  }

  void _deleteSelected() {
    if (_selectedCategories.isEmpty) return;
    ref
        .read(inventorySettingsProvider.notifier)
        .removeCategories(_selectedCategories.toList());
    setState(() {
      _selectedCategories.clear();
      _isEditing = false;
    });
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(inventorySettingsProvider);
    final customCategories =
        settings.categories.where((cat) => cat != '其他').toList();
    final hasFixedCategory = settings.categories.contains('其他');

    return Scaffold(
      appBar: AppBar(
        title: const Text('囤货功能设置'),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _selectedCategories.clear();
                });
              },
              child: const Text('取消', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('分类调整',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (customCategories.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isEditing = !_isEditing;
                      if (!_isEditing) _selectedCategories.clear();
                    });
                  },
                  icon: Icon(_isEditing ? Icons.check : Icons.edit_note,
                      size: 20),
                  label: Text(_isEditing ? '完成' : '编辑'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isEditing)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _categoryController,
                            decoration: const InputDecoration(
                              hintText: '输入新分类名称',
                              isDense: true,
                            ),
                            onSubmitted: (_) => _addCategory(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addCategory,
                          child: const Text('添加'),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Text('已选择 ${_selectedCategories.length} 项',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _selectedCategories.isEmpty
                              ? null
                              : _deleteSelected,
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          label: const Text('删除所选',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  if (customCategories.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '还没有自定义分类，先添加一个吧',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      buildDefaultDragHandles: false,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: customCategories.length,
                      onReorderItem: (oldIndex, newIndex) {
                        ref
                            .read(inventorySettingsProvider.notifier)
                            .reorderCategories(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final category = customCategories[index];
                        final isSelected =
                            _selectedCategories.contains(category);

                        return ReorderableDragStartListener(
                          key: ValueKey(category),
                          index: index,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withAlpha(76)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: IntrinsicWidth(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isEditing)
                                      Checkbox(
                                        value: isSelected,
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedCategories.add(category);
                                            } else {
                                              _selectedCategories
                                                  .remove(category);
                                            }
                                          });
                                        },
                                      )
                                    else
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 12),
                                        child: CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer,
                                          child: Text(
                                            '${index + 1}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall,
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      child: Text(
                                        category,
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    if (!_isEditing)
                                      IconButton(
                                        onPressed: () {
                                          ref
                                              .read(inventorySettingsProvider
                                                  .notifier)
                                              .removeCategory(category);
                                        },
                                        icon: const Icon(Icons.close,
                                            size: 18, color: Colors.black38),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  if (hasFixedCategory) ...[
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFFF5F5F5), // Colors.grey.shade100
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.zero,
                          child: IntrinsicWidth(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(left: 12),
                                  child: Icon(Icons.lock_outline,
                                      size: 18, color: Colors.black38),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: Text(
                                    '其他',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black45),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(right: 12),
                                  child: Text(
                                    '(默认)',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.black38),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('列表视图控制',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: RadioGroup<int>(
                groupValue: settings.gridCrossAxisCount,
                onChanged: (val) => ref
                    .read(inventorySettingsProvider.notifier)
                    .updateGridCount(val!),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('设置卡片每行显示数量，用于控制卡片大小（自适应屏幕）'),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('大卡片 (单列)'),
                        Radio<int>(
                          value: 1,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('中等卡片 (双列)'),
                        Radio<int>(
                          value: 2,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('小卡片 (三列)'),
                        Radio<int>(
                          value: 3,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
