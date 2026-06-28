// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(initialThemeMode)
final initialThemeModeProvider = InitialThemeModeProvider._();

final class InitialThemeModeProvider
    extends $FunctionalProvider<ThemeMode, ThemeMode, ThemeMode>
    with $Provider<ThemeMode> {
  InitialThemeModeProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'initialThemeModeProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$initialThemeModeHash();

  @$internal
  @override
  $ProviderElement<ThemeMode> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ThemeMode create(Ref ref) {
    return initialThemeMode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeMode>(value),
    );
  }
}

String _$initialThemeModeHash() => r'5ccd3f792823271dd8a2bb8f7747cd8bd288b99b';

@ProviderFor(initialThemeColor)
final initialThemeColorProvider = InitialThemeColorProvider._();

final class InitialThemeColorProvider
    extends $FunctionalProvider<Color, Color, Color> with $Provider<Color> {
  InitialThemeColorProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'initialThemeColorProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$initialThemeColorHash();

  @$internal
  @override
  $ProviderElement<Color> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Color create(Ref ref) {
    return initialThemeColor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Color value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Color>(value),
    );
  }
}

String _$initialThemeColorHash() => r'ca9ad03c0009177fa1bd5f78f0ab6782e82db07b';

@ProviderFor(ThemeModeNotifier)
final themeModeProvider = ThemeModeNotifierProvider._();

final class ThemeModeNotifierProvider
    extends $NotifierProvider<ThemeModeNotifier, ThemeMode> {
  ThemeModeNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'themeModeProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$themeModeNotifierHash();

  @$internal
  @override
  ThemeModeNotifier create() => ThemeModeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeMode>(value),
    );
  }
}

String _$themeModeNotifierHash() => r'd4513ccb5fe67345dd59ddee8af14040b73b9db7';

abstract class _$ThemeModeNotifier extends $Notifier<ThemeMode> {
  ThemeMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ThemeMode, ThemeMode>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<ThemeMode, ThemeMode>, ThemeMode, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(ThemeColorNotifier)
final themeColorProvider = ThemeColorNotifierProvider._();

final class ThemeColorNotifierProvider
    extends $NotifierProvider<ThemeColorNotifier, Color> {
  ThemeColorNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'themeColorProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$themeColorNotifierHash();

  @$internal
  @override
  ThemeColorNotifier create() => ThemeColorNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Color value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Color>(value),
    );
  }
}

String _$themeColorNotifierHash() =>
    r'49521bf3b59b7aab22b46cc183164a139b2b21d7';

abstract class _$ThemeColorNotifier extends $Notifier<Color> {
  Color build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Color, Color>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<Color, Color>, Color, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}
