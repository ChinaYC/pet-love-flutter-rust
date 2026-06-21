import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../src/rust/api/system.dart';

part 'theme_provider.g.dart';

@riverpod
ThemeMode initialThemeMode(InitialThemeModeRef ref) => ThemeMode.system;

@riverpod
Color initialThemeColor(InitialThemeColorRef ref) => const Color(0xFFFF9800);

extension ThemeContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;
  bool get isDark => theme.brightness == Brightness.dark;

  /// 获取自适应平台的背景色
  /// 在 iOS 上优先使用 CupertinoColors.systemBackground
  Color get adaptiveBackgroundColor {
    if (Platform.isIOS) {
      return CupertinoDynamicColor.resolve(
        CupertinoColors.systemBackground,
        this,
      );
    }
    return colorScheme.surface;
  }

  /// 获取自适应平台的次级背景色（如列表项背景）
  Color get adaptiveSecondaryBackgroundColor {
    if (Platform.isIOS) {
      return CupertinoDynamicColor.resolve(
        CupertinoColors.secondarySystemBackground,
        this,
      );
    }
    return colorScheme.surfaceContainer;
  }
}

@riverpod
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  ThemeMode build() {
    return ref.watch(initialThemeModeProvider);
  }

  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    state = newMode;
    await setAppSetting(key: 'theme_mode', value: newMode.name);
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    await setAppSetting(key: 'theme_mode', value: mode.name);
  }
}

@riverpod
class ThemeColorNotifier extends _$ThemeColorNotifier {
  @override
  Color build() {
    return ref.watch(initialThemeColorProvider);
  }

  Future<void> setColor(Color color) async {
    state = color;
    await setAppSetting(key: 'theme_color', value: color.toARGB32().toString());
  }
}

class AppTheme {
  // 基础辅助颜色
  static const backgroundColorLight = Color(0xFFFAF9F9);
  static const backgroundColorDark =
      Color(0xFF121212); // 更深一点的暗色，符合 Material 3 规范

  static ThemeData lightTheme(Color primaryColor) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: primaryColor.withValues(alpha: 0.8),
        surface: backgroundColorLight,
        surfaceContainer: const Color(0xFFF2F2F2),
        surfaceContainerHigh: const Color(0xFFEBEBEB),
        surfaceContainerHighest: const Color(0xFFE0E0E0),
        onSurfaceVariant: const Color(0xFF757575),
      ),
      scaffoldBackgroundColor: backgroundColorLight,
      dividerColor: Colors.black.withValues(alpha: 0.1),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFF333333)),
        titleTextStyle: TextStyle(
          color: Color(0xFF333333),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: Colors.white,
      ),
    );
  }

  static ThemeData darkTheme(Color primaryColor) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: primaryColor.withValues(alpha: 0.8),
        surface: backgroundColorDark,
        surfaceContainer: const Color(0xFF1E1E1E),
        surfaceContainerHigh: const Color(0xFF252525),
        surfaceContainerHighest: const Color(0xFF2C2C2C),
        onSurfaceVariant: const Color(0xFFAAAAAA),
      ),
      scaffoldBackgroundColor: backgroundColorDark,
      dividerColor: Colors.white.withValues(alpha: 0.1),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: const Color(0xFF1E1E1E),
      ),
    );
  }
}
