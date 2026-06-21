import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../../../src/rust/api/inventory.dart';
import '../../../../../../src/rust/api/system.dart';
import 'widgets/inventory_item_card.dart';
import 'widgets/add_inventory_dialog.dart';
import 'inventory_settings_provider.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  List<InventoryItem> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadItems().then((_) {
      if (mounted) {
        _restoreDialogState();
      }
    });
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
            final items = _items.where((i) => i.id == data['itemId']);
            if (items.isNotEmpty) {
              _showEditDialog(items.first, isRestoring: true);
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
      final items = await getActiveInventoryItems();
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteItem(String id) async {
    final confirm = await AppDialog.show<bool>(
      context: context,
      title: const Text('确认删除'),
      content: const Text('确定要删除这条囤货记录吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('删除'),
        ),
      ],
    );

    if (confirm == true) {
      try {
        await deleteInventoryItem(id: id);
        _loadItems();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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

    if (_items.isEmpty) {
      return const Center(
        child: Text('暂无囤货记录，点击右下角添加吧！'),
      );
    }

    final settings = ref.watch(inventorySettingsProvider);

    return RefreshIndicator(
      onRefresh: _loadItems,
      child: GridView.builder(
        padding: const EdgeInsets.only(
            bottom: 80, left: 8, right: 8, top: 8), // 为 FAB 留出空间
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: settings.gridCrossAxisCount,
          childAspectRatio:
              settings.gridCrossAxisCount == 1 ? 2.2 : 0.75, // 根据列数调整宽高比
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return InventoryItemCard(
            item: item,
            onEdit: () => _showEditDialog(item),
            onDelete: () => _deleteItem(item.id),
          );
        },
      ),
    );
  }
}
