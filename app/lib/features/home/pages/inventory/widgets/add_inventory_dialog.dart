import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../src/rust/api/inventory.dart';
import '../inventory_settings_provider.dart';
import '../inventory_settings_page.dart';

class AddInventoryDialog extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  final InventoryItem? initialItem;

  const AddInventoryDialog({
    super.key,
    required this.onSaved,
    this.initialItem,
  });

  @override
  ConsumerState<AddInventoryDialog> createState() => _AddInventoryDialogState();
}

class _AddInventoryDialogState extends ConsumerState<AddInventoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _costController;
  String _category = '其他';
  DateTime _purchaseDate = DateTime.now();
  DateTime _expirationDate = DateTime.now().add(const Duration(days: 365));
  bool _isSubmitting = false;
  String? _imagePath;

  bool get _isEditMode => widget.initialItem != null;

  @override
  void initState() {
    super.initState();
    final initialItem = widget.initialItem;
    _nameController = TextEditingController(text: initialItem?.name ?? '');
    _costController = TextEditingController(
      text: initialItem != null ? initialItem.cost.toStringAsFixed(2) : '',
    );
    if (initialItem != null) {
      _category = initialItem.category;
      _purchaseDate = DateTime.fromMillisecondsSinceEpoch(initialItem.purchaseDate);
      _expirationDate = DateTime.fromMillisecondsSinceEpoch(initialItem.expirationDate);
      _imagePath = initialItem.imagePath;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cats = ref.read(inventorySettingsProvider).categories;
      if (!_isEditMode && cats.isNotEmpty) {
        setState(() {
          _category = cats.first;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await showDialog<XFile?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择图片'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () async {
                final file = await picker.pickImage(source: ImageSource.camera);
                if (context.mounted) Navigator.of(context).pop(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () async {
                final file =
                    await picker.pickImage(source: ImageSource.gallery);
                if (context.mounted) Navigator.of(context).pop(file);
              },
            ),
          ],
        ),
      ),
    );

    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isPurchase) async {
    final initialDate = isPurchase ? _purchaseDate : _expirationDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isPurchase) {
          _purchaseDate = picked;
          if (_expirationDate.isBefore(_purchaseDate)) {
            _expirationDate = _purchaseDate.add(const Duration(days: 30));
          }
        } else {
          _expirationDate = picked;
        }
      });
    }
  }

  /// 功能：在最终保存前统一清洗表单数据并做兜底校验。
  /// 参数：无，直接读取当前表单状态。
  /// 返回值：返回清洗后的表单数据 Map；若校验失败则返回 null。
  /// 注意事项：不能只依赖输入框事件，提交前必须再校验一次，防止旧数据回显或异步更新漏算。
  Map<String, dynamic>? _normalizeFormData() {
    final normalizedName = _nameController.text.trim();
    final normalizedCategory = _category.trim().isEmpty ? '其他' : _category.trim();
    final normalizedCost = double.tryParse(_costController.text.trim()) ?? 0.0;

    if (normalizedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入名称')),
      );
      return null;
    }

    if (_expirationDate.isBefore(_purchaseDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('过期时间不能早于购买时间')),
      );
      return null;
    }

    return {
      'name': normalizedName,
      'category': normalizedCategory,
      'cost': normalizedCost < 0 ? 0.0 : normalizedCost,
      'purchaseDate': _purchaseDate.millisecondsSinceEpoch,
      'expirationDate': _expirationDate.millisecondsSinceEpoch,
      'imagePath': _imagePath,
    };
  }

  void _handleCategoryChange(String? value) {
    if (value == '其他') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提示'),
          content: const Text('是否需要跳转到设置页面添加更多分类？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _category = value!);
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const InventorySettingsPage()));
              },
              child: const Text('去设置'),
            ),
          ],
        ),
      );
    } else if (value != null) {
      setState(() => _category = value);
    }
  }

  // 强制在保存入口设卡 (Mandatory Submit Interception)
  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final normalizedFormData = _normalizeFormData();
      if (normalizedFormData == null) return;

      setState(() => _isSubmitting = true);
      try {
        if (_isEditMode) {
          await updateInventoryItem(
            id: widget.initialItem!.id,
            name: normalizedFormData['name'] as String,
            category: normalizedFormData['category'] as String,
            purchaseDate: normalizedFormData['purchaseDate'] as int,
            expirationDate: normalizedFormData['expirationDate'] as int,
            cost: normalizedFormData['cost'] as double,
            imagePath: normalizedFormData['imagePath'] as String?,
          );
        } else {
          await addInventoryItem(
            name: normalizedFormData['name'] as String,
            category: normalizedFormData['category'] as String,
            purchaseDate: normalizedFormData['purchaseDate'] as int,
            expirationDate: normalizedFormData['expirationDate'] as int,
            cost: normalizedFormData['cost'] as double,
            imagePath: normalizedFormData['imagePath'] as String?,
          );
        }
        widget.onSaved();
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存失败: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(inventorySettingsProvider);
    final validCategories = settings.categories.contains(_category)
        ? settings.categories
        : [...settings.categories, _category];

    return AlertDialog(
      title: Text(_isEditMode ? '编辑囤货' : '新增囤货'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拍照/选择图片区
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    image: _imagePath != null
                        ? DecorationImage(
                            image: FileImage(File(_imagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _imagePath == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo,
                                size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('添加物品图片',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '物品名称'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入名称' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: '分类'),
                items: validCategories.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: _handleCategoryChange,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _costController,
                decoration: const InputDecoration(labelText: '总花费 (¥)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return '请输入花费';
                  if (double.tryParse(value) == null) return '请输入有效的数字';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('购买日期'),
                subtitle: Text(
                    '${_purchaseDate.year}-${_purchaseDate.month}-${_purchaseDate.day}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('过期时间 (保质期)'),
                subtitle: Text(
                    '${_expirationDate.year}-${_expirationDate.month}-${_expirationDate.day}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, false),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isEditMode ? '更新' : '保存'),
        ),
      ],
    );
  }
}
