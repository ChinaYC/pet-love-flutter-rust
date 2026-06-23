import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/theme_provider.dart';

class AppDialog extends StatefulWidget {
  final Widget? title;
  final Widget content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? contentPadding;
  final bool useBlur;
  final double maxWidth;

  const AppDialog({
    super.key,
    this.title,
    required this.content,
    this.actions,
    this.contentPadding,
    this.useBlur = true,
    this.maxWidth = 400,
  });

  @override
  State<AppDialog> createState() => _AppDialogState();

  static Future<T?> show<T>({
    required BuildContext context,
    Widget? title,
    required Widget content,
    List<Widget>? actions,
    EdgeInsetsGeometry? contentPadding,
    bool barrierDismissible = true,
    bool useBlur = true,
    double maxWidth = 400,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: AppDialog(
            title: title,
            content: content,
            actions: actions,
            contentPadding: contentPadding,
            useBlur: useBlur,
            maxWidth: maxWidth,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }

  /// 直接显示一个已经包含 AppDialog 结构的 Widget，并应用统一样式和动画
  static Future<T?> showRaw<T>({
    required BuildContext context,
    required Widget child,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) =>
          SafeArea(child: child),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _AppDialogState extends State<AppDialog> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final screenWidth = MediaQuery.of(context).size.width;

    // 优化：小屏幕下减小左右无用空间，大屏幕下限制最大宽度
    double horizontalInset = 16.0;
    if (screenWidth > widget.maxWidth + 32.0) {
      horizontalInset = (screenWidth - widget.maxWidth) / 2;
    }

    Widget dialogChild = AlertDialog(
      title: widget.title,
      // 关键修复：使用 Scrollbar 增强滚动感知，并确保内容区受限，而 actions 区固定
      content: SizedBox(
        width: double.maxFinite,
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(right: 8), // 为滚动条预留空间
            child: widget.content,
          ),
        ),
      ),
      actions: widget.actions,
      // 优化：actionsPadding 确保底部按钮有足够的点击区域且不拥挤
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      scrollable: false, // 严禁整个 AlertDialog 滚动，确保 actions 固定
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: 24.0,
      ),
      contentPadding: widget.contentPadding ??
          const EdgeInsets.fromLTRB(24.0, 20.0, 16.0, 8.0),
      backgroundColor: context.adaptiveBackgroundColor.withValues(
        alpha: (Platform.isIOS && widget.useBlur) ? 0.8 : 1.0,
      ),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.dividerColor,
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.hardEdge, // 性能优化：使用 hardEdge 代替复杂的抗锯齿裁剪
    );

    if (Platform.isIOS && widget.useBlur) {
      dialogChild = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: dialogChild,
      );
    }

    // 点击弹窗外部或空白处，自动收起键盘
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: dialogChild,
    );
  }
}
