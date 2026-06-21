import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../../theme/theme_provider.dart';
import '../inventory_settings_provider.dart';

class CategoryPickerSheet extends StatefulWidget {
  final List<CategoryGroup> categories;
  final String? initialParent;
  final String? initialSub;
  final Map<String, int>? categoryCounts;
  final bool sortByCount;

  const CategoryPickerSheet({
    super.key,
    required this.categories,
    this.initialParent,
    this.initialSub,
    this.categoryCounts,
    this.sortByCount = false,
  });

  @override
  State<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<CategoryPickerSheet> {
  int _selectedParentIndex = 0;
  final ScrollController _rightScrollController = ScrollController();
  final List<GlobalKey> _groupKeys = [];
  bool _isManualScrolling = false;
  List<CategoryGroup> _sortedCategories = [];

  @override
  void initState() {
    super.initState();

    // Sort categories and subcategories if needed
    _sortedCategories = List.from(widget.categories.map((group) {
      final sortedSubcategories = List<String>.from(group.subcategories);
      if (widget.sortByCount && widget.categoryCounts != null) {
        sortedSubcategories.sort((a, b) {
          final countA = widget.categoryCounts!['${group.name} / $a'] ?? 0;
          final countB = widget.categoryCounts!['${group.name} / $b'] ?? 0;
          return countB.compareTo(countA);
        });
      }
      return CategoryGroup(
          name: group.name, subcategories: sortedSubcategories);
    }));

    if (widget.sortByCount && widget.categoryCounts != null) {
      _sortedCategories.sort((a, b) {
        final countA = widget.categoryCounts![a.name] ?? 0;
        final countB = widget.categoryCounts![b.name] ?? 0;
        return countB.compareTo(countA);
      });
    }

    for (int i = 0; i < _sortedCategories.length; i++) {
      _groupKeys.add(GlobalKey());
      if (_sortedCategories[i].name == widget.initialParent) {
        _selectedParentIndex = i;
      }
    }

    // 初始化时滚动到对应位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_selectedParentIndex > 0) {
        _scrollToIndex(_selectedParentIndex);
      }
    });
  }

  @override
  void dispose() {
    _rightScrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    _isManualScrolling = true;
    final context = _groupKeys[index].currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ).then((_) => _isManualScrolling = false);
    } else {
      _isManualScrolling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: context.adaptiveBackgroundColor
            .withValues(alpha: Platform.isIOS ? 0.8 : 1.0),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(context.theme),
          Divider(height: 1, color: context.theme.dividerColor),
          Expanded(
            child: Row(
              children: [
                _buildLeftList(context),
                VerticalDivider(width: 1, color: context.theme.dividerColor),
                _buildRightList(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('选择品类',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              )),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftList(BuildContext context) {
    final theme = context.theme;
    final colorScheme = context.colorScheme;

    return Container(
      width: 100,
      color: context.adaptiveSecondaryBackgroundColor,
      child: ListView.builder(
        itemCount: _sortedCategories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedParentIndex == index;
          final groupName = _sortedCategories[index].name;
          final count = widget.categoryCounts?[groupName] ?? 0;
          return InkWell(
            onTap: () {
              setState(() => _selectedParentIndex = index);
              _scrollToIndex(index);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.adaptiveBackgroundColor
                    : Colors.transparent,
                border: isSelected
                    ? Border(
                        left: BorderSide(color: colorScheme.primary, width: 4))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    groupName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? colorScheme.primary
                          : theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.8),
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$count 项',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRightList(BuildContext context) {
    final theme = context.theme;
    final colorScheme = context.colorScheme;

    return Expanded(
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (!_isManualScrolling && notification is ScrollUpdateNotification) {
            _updateLeftIndexOnScroll();
          }
          return true;
        },
        child: ListView.builder(
          controller: _rightScrollController,
          itemCount: _sortedCategories.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final group = _sortedCategories[index];
            return Column(
              key: _groupKeys[index],
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    group.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: group.subcategories.map((sub) {
                    final isSelected = widget.initialParent == group.name &&
                        widget.initialSub == sub;
                    final subCount =
                        widget.categoryCounts?['${group.name} / $sub'] ?? 0;
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context, {
                          'parent': group.name,
                          'sub': sub,
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              sub,
                              style: TextStyle(
                                color: isSelected
                                    ? colorScheme.onPrimary
                                    : theme.textTheme.bodyMedium?.color,
                                fontSize: 14,
                              ),
                            ),
                            if (subCount > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$subCount',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : theme.textTheme.bodySmall?.color
                                            ?.withValues(alpha: 0.7),
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  void _updateLeftIndexOnScroll() {
    for (int i = 0; i < _groupKeys.length; i++) {
      final keyContext = _groupKeys[i].currentContext;
      if (keyContext != null) {
        final box = keyContext.findRenderObject() as RenderBox;
        final position = box.localToGlobal(Offset.zero).dy;
        // 如果该组的顶部进入了可视区域上方一定范围，则更新左侧索引
        if (position >= 0 && position < 200) {
          if (_selectedParentIndex != i) {
            setState(() => _selectedParentIndex = i);
          }
          break;
        }
      }
    }
  }
}
