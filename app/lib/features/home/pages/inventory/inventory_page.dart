import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../src/rust/api/inventory.dart';
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
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final items = await getActiveInventoryItems();
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteItem(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条囤货记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AddInventoryDialog(
        onSaved: _loadItems,
      ),
    );
  }

  void _showEditDialog(InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AddInventoryDialog(
        initialItem: item,
        onSaved: _loadItems,
      ),
    );
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
