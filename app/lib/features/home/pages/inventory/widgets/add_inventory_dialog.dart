import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/widgets/app_dialog.dart';
import '../../../../../theme/theme_provider.dart';
import '../../../../../../src/rust/api/inventory.dart';
import '../../../../../../src/rust/api/system.dart';
import '../inventory_settings_provider.dart';

import 'category_picker_sheet.dart';

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
  late final TextEditingController _categoryController;
  String? _parentCategory;
  String? _subCategory;
  DateTime _purchaseDate = DateTime.now();
  DateTime _expirationDate = DateTime.now().add(const Duration(days: 365));
  bool _isSubmitting = false;
  String? _imagePath;
  Timer? _autoSaveTimer;

  bool get _isEditMode => widget.initialItem != null;

  @override
  void initState() {
    super.initState();
    final initialItem = widget.initialItem;
    _nameController = TextEditingController(text: initialItem?.name ?? '');
    _costController = TextEditingController(
      text: initialItem != null ? initialItem.cost.toStringAsFixed(2) : '',
    );
    _categoryController = TextEditingController(
      text: initialItem != null ? initialItem.category : '',
    );

    // 监听输入变化以触发自动保存
    _nameController.addListener(_onFormChanged);
    _costController.addListener(_onFormChanged);
    _categoryController.addListener(_onCategoryInputChanged);

    if (initialItem != null) {
      // 尝试解析二级分类 "Parent/Sub"
      final category = initialItem.category;
      final slashIndex = category.indexOf('/');
      if (slashIndex != -1) {
        _parentCategory = category.substring(0, slashIndex).trim();
        _subCategory = category.substring(slashIndex + 1).trim();
      } else {
        _parentCategory = '其他支出';
        _subCategory = category;
      }
      _purchaseDate =
          DateTime.fromMillisecondsSinceEpoch(initialItem.purchaseDate);
      _expirationDate =
          DateTime.fromMillisecondsSinceEpoch(initialItem.expirationDate);
      _imagePath = initialItem.imagePath;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // 1. 尝试从数据库恢复草稿 (无论新增还是编辑)
      await _restoreDraft();

      if (!mounted) return;
      if (!_isEditMode) {
        // 2. 如果恢复后依然没有分类，则设置默认分类
        final settings = ref.read(inventorySettingsProvider);
        if (_parentCategory == null && settings.categoryGroups.isNotEmpty) {
          final firstGroup = settings.categoryGroups.first;
          setState(() {
            _parentCategory = firstGroup.name;
            _subCategory = firstGroup.subcategories.isNotEmpty
                ? firstGroup.subcategories.first
                : null;
          });
        }
      }
    });
  }

  Future<void> _restoreDraft() async {
    try {
      final draftKey = _isEditMode
          ? 'inventory_edit_draft_${widget.initialItem!.id}'
          : 'inventory_add_draft';
      final draftJson = await getAppSetting(key: draftKey);
      if (!mounted) return;
      if (draftJson != null && draftJson.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(draftJson);
        setState(() {
          _nameController.text = data['name'] ?? '';
          _costController.text = data['cost']?.toString() ?? '';
          _parentCategory = data['parentCategory'];
          _subCategory = data['subCategory'];
          if (data['purchaseDate'] != null) {
            _purchaseDate =
                DateTime.fromMillisecondsSinceEpoch(data['purchaseDate']);
          }
          if (data['expirationDate'] != null) {
            _expirationDate =
                DateTime.fromMillisecondsSinceEpoch(data['expirationDate']);
          }
          _imagePath = data['imagePath'];
          if (_parentCategory != null && _subCategory != null) {
            _categoryController.text = '$_parentCategory / $_subCategory';
          }
        });
      }
    } catch (e) {
      debugPrint('恢复草稿失败: $e');
    }
  }

  void _onFormChanged() {
    if (!mounted || _isEditMode) return; // 编辑模式不自动保存草稿
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 500), _saveDraft);
  }

  void _onCategoryInputChanged() {
    if (!mounted) return;
    final text = _categoryController.text.trim();
    if (text.isNotEmpty) {
      final slashIndex = text.indexOf('/');
      if (slashIndex != -1) {
        _parentCategory = text.substring(0, slashIndex).trim();
        _subCategory = text.substring(slashIndex + 1).trim();
      } else {
        _parentCategory = '其他支出';
        _subCategory = text;
      }
    }
    _onFormChanged();
  }

  Future<void> _saveDraft() async {
    if (!mounted) return;
    try {
      final draftData = {
        'name': _nameController.text,
        'cost': double.tryParse(_costController.text),
        'parentCategory': _parentCategory,
        'subCategory': _subCategory,
        'purchaseDate': _purchaseDate.millisecondsSinceEpoch,
        'expirationDate': _expirationDate.millisecondsSinceEpoch,
        'imagePath': _imagePath,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      final draftKey = _isEditMode
          ? 'inventory_edit_draft_${widget.initialItem!.id}'
          : 'inventory_add_draft';
      await setAppSetting(key: draftKey, value: jsonEncode(draftData));
    } catch (e) {
      debugPrint('自动保存草稿失败: $e');
    }
  }

  Future<void> _clearDraft() async {
    try {
      final draftKey = _isEditMode
          ? 'inventory_edit_draft_${widget.initialItem!.id}'
          : 'inventory_add_draft';
      await setAppSetting(key: draftKey, value: '');
    } catch (e) {
      debugPrint('清除草稿失败: $e');
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _nameController.dispose();
    _costController.dispose();
    _categoryController.dispose();
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
              leading:
                  Icon(Icons.camera_alt, color: context.colorScheme.primary),
              title: const Text('拍照'),
              onTap: () async {
                final file = await picker.pickImage(source: ImageSource.camera);
                if (context.mounted) Navigator.of(context).pop(file);
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.photo_library, color: context.colorScheme.primary),
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
      _onFormChanged();
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
      _onFormChanged();
    }
  }

  /// 功能：在最终保存前统一清洗表单数据并做兜底校验。
  /// 参数：无，直接读取当前表单状态。
  /// 返回值：返回清洗后的表单数据 Map；若校验失败则返回 null。
  /// 注意事项：不能只依赖输入框事件，提交前必须再校验一次，防止旧数据回显或异步更新漏算。
  Map<String, dynamic>? _normalizeFormData() {
    final normalizedName = _nameController.text.trim();
    final normalizedCategory =
        '${_parentCategory ?? "其他支出"}/${_subCategory ?? "杂项"}';
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
        await _clearDraft();
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

  Future<void> _showCategoryPicker(InventorySettingsState settings) async {
    // 使用 Rust 层提供的统计 API，直接获取分类计数，性能更优且省内存
    Map<String, int> categoryCounts = {};
    try {
      final stats = await getCategoryStats();
      for (final stat in stats) {
        categoryCounts[stat.name] = stat.count;
      }
    } catch (e) {
      debugPrint('Failed to get category stats from Rust: $e');
    }

    if (!mounted) return;

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: CategoryPickerSheet(
          categories: settings.categoryGroups,
          initialParent: _parentCategory,
          initialSub: _subCategory,
          categoryCounts: categoryCounts,
          sortByCount: settings.sortCategoryByCount,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _parentCategory = result['parent'];
        _subCategory = result['sub'];
        _categoryController.text = '$_parentCategory / $_subCategory';
      });
      _onFormChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colorScheme = context.colorScheme;
    final settings = ref.watch(inventorySettingsProvider);

    if (settings.categoryGroups.isEmpty && !_isEditMode) {
      return AppDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('加载分类中...', style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    return AppDialog(
      title: Text(_isEditMode ? '编辑囤货' : '新增囤货'),
      content: Form(
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
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  image: _imagePath != null
                      ? DecorationImage(
                          image: FileImage(File(_imagePath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _imagePath == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo,
                              size: 40, color: colorScheme.onSurfaceVariant),
                          const SizedBox(height: 8),
                          Text('添加物品图片',
                              style: TextStyle(
                                  color: colorScheme.onSurfaceVariant)),
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
            RawAutocomplete<String>(
              textEditingController: _categoryController,
              focusNode: FocusNode(),
              optionsBuilder: (TextEditingValue textEditingValue) {
                final text = textEditingValue.text.trim();
                if (text.isEmpty) return const Iterable<String>.empty();

                final allOptions = settings.categoryGroups.expand((group) {
                  return group.subcategories
                      .map((sub) => '${group.name} / $sub');
                }).toList();

                return allOptions.where((option) =>
                    option.toLowerCase().contains(text.toLowerCase()));
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: '品类',
                    hintText: '输入或点击右侧图标选择',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.category_outlined),
                      onPressed: () {
                        focusNode.unfocus();
                        _showCategoryPicker(settings);
                      },
                    ),
                  ),
                  onFieldSubmitted: (value) => onSubmitted(),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    borderRadius: BorderRadius.circular(8),
                    color: context.adaptiveBackgroundColor,
                    child: Container(
                      height: 200,
                      width: MediaQuery.of(context).size.width - 64,
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final String option = options.elementAt(index);
                          return ListTile(
                            title:
                                Text(option, style: theme.textTheme.bodyMedium),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
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
