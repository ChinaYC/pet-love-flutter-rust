// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$initialThemeModeHash() => r'5ccd3f792823271dd8a2bb8f7747cd8bd288b99b';

/// See also [initialThemeMode].
@ProviderFor(initialThemeMode)
final initialThemeModeProvider = AutoDisposeProvider<ThemeMode>.internal(
  initialThemeMode,
  name: r'initialThemeModeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$initialThemeModeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef InitialThemeModeRef = AutoDisposeProviderRef<ThemeMode>;
String _$initialThemeColorHash() => r'ca9ad03c0009177fa1bd5f78f0ab6782e82db07b';

/// See also [initialThemeColor].
@ProviderFor(initialThemeColor)
final initialThemeColorProvider = AutoDisposeProvider<Color>.internal(
  initialThemeColor,
  name: r'initialThemeColorProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$initialThemeColorHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef InitialThemeColorRef = AutoDisposeProviderRef<Color>;
String _$themeModeNotifierHash() => r'd4513ccb5fe67345dd59ddee8af14040b73b9db7';

/// See also [ThemeModeNotifier].
@ProviderFor(ThemeModeNotifier)
final themeModeNotifierProvider =
    AutoDisposeNotifierProvider<ThemeModeNotifier, ThemeMode>.internal(
  ThemeModeNotifier.new,
  name: r'themeModeNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$themeModeNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ThemeModeNotifier = AutoDisposeNotifier<ThemeMode>;
String _$themeColorNotifierHash() =>
    r'49521bf3b59b7aab22b46cc183164a139b2b21d7';

/// See also [ThemeColorNotifier].
@ProviderFor(ThemeColorNotifier)
final themeColorNotifierProvider =
    AutoDisposeNotifierProvider<ThemeColorNotifier, Color>.internal(
  ThemeColorNotifier.new,
  name: r'themeColorNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$themeColorNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ThemeColorNotifier = AutoDisposeNotifier<Color>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
