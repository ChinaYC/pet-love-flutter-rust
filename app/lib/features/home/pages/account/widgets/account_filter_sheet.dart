import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../theme/theme_provider.dart';
import '../../../../../src/rust/api/inventory/models.dart';
import '../account_providers.dart';

class AccountFilterSheet extends ConsumerStatefulWidget {
  final Function(InventorySearchQuery) onApply;
  final InventorySearchQuery initialQuery;

  const AccountFilterSheet({
    super.key,
    required this.onApply,
    required this.initialQuery,
  });

  @override
  ConsumerState<AccountFilterSheet> createState() => _AccountFilterSheetState();
}

class _AccountFilterSheetState extends ConsumerState<AccountFilterSheet> {
  late String? _selectedCategory;
  late DateTime? _startDate;
  late DateTime? _endDate;
  final TextEditingController _minCostController = TextEditingController();
  final TextEditingController _maxCostController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialQuery.category;
    _startDate = widget.initialQuery.startDate != null
        ? DateTime.fromMillisecondsSinceEpoch(
            widget.initialQuery.startDate!.toInt())
        : null;
    _endDate = widget.initialQuery.endDate != null
        ? DateTime.fromMillisecondsSinceEpoch(
            widget.initialQuery.endDate!.toInt())
        : null;
    _minCostController.text = widget.initialQuery.minCost?.toString() ?? '';
    _maxCostController.text = widget.initialQuery.maxCost?.toString() ?? '';
  }

  @override
  void dispose() {
    _minCostController.dispose();
    _maxCostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(accountCategoriesProvider);

    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: context.adaptiveBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('分类',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    _buildCategoryGrid(categoriesAsync),
                    const SizedBox(height: 20),
                    const Text('日期范围',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    _buildDateRangePicker(context),
                    const SizedBox(height: 20),
                    const Text('金额范围',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    _buildCostRangePicker(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildApplyButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('筛选条件',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('重置'),
          onPressed: () {
            setState(() {
              _selectedCategory = null;
              _startDate = null;
              _endDate = null;
              _minCostController.clear();
              _maxCostController.clear();
            });
          },
        ),
      ],
    );
  }

  Widget _buildCategoryGrid(AsyncValue<List<String>> categoriesAsync) {
    return categoriesAsync.when(
      data: (categories) => Wrap(
        spacing: 8,
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat ||
              (_selectedCategory == null && cat == '全部');
          return ChoiceChip(
            label: Text(cat),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                _selectedCategory = cat == '全部' ? null : cat;
              });
            },
          );
        }).toList(),
      ),
      loading: () => const CupertinoActivityIndicator(),
      error: (_, __) => const Text('加载分类失败'),
    );
  }

  Widget _buildDateRangePicker(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: context.adaptiveSecondaryBackgroundColor,
            child: Text(
              _startDate == null
                  ? '开始日期'
                  : DateFormat('yyyy-MM-dd').format(_startDate!),
              style: TextStyle(
                  color: _startDate == null
                      ? context.theme.hintColor
                      : context.theme.textTheme.bodyMedium?.color,
                  fontSize: 14),
            ),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _startDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) setState(() => _startDate = date);
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Text('-'),
        ),
        Expanded(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: context.adaptiveSecondaryBackgroundColor,
            child: Text(
              _endDate == null
                  ? '结束日期'
                  : DateFormat('yyyy-MM-dd').format(_endDate!),
              style: TextStyle(
                  color: _endDate == null
                      ? context.theme.hintColor
                      : context.theme.textTheme.bodyMedium?.color,
                  fontSize: 14),
            ),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _endDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) setState(() => _endDate = date);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCostRangePicker() {
    return Row(
      children: [
        Expanded(
          child: CupertinoTextField(
            controller: _minCostController,
            placeholder: '最小金额',
            keyboardType: TextInputType.number,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Text('-'),
        ),
        Expanded(
          child: CupertinoTextField(
            controller: _maxCostController,
            placeholder: '最大金额',
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }

  Widget _buildApplyButton() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton.filled(
        child: const Text('确定'),
        onPressed: () {
          final query = InventorySearchQuery(
            query: widget.initialQuery.query,
            category: _selectedCategory,
            startDate: _startDate?.millisecondsSinceEpoch,
            endDate: _endDate?.millisecondsSinceEpoch,
            minCost: double.tryParse(_minCostController.text),
            maxCost: double.tryParse(_maxCostController.text),
          );
          widget.onApply(query);
          Navigator.pop(context);
        },
      ),
    );
  }
}
