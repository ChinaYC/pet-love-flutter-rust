// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UserProfileNotifier)
final userProfileProvider = UserProfileNotifierProvider._();

final class UserProfileNotifierProvider
    extends $NotifierProvider<UserProfileNotifier, UserProfile> {
  UserProfileNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'userProfileProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$userProfileNotifierHash();

  @$internal
  @override
  UserProfileNotifier create() => UserProfileNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserProfile value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserProfile>(value),
    );
  }
}

String _$userProfileNotifierHash() =>
    r'8a10fffc65e46a574fd8255d1bf1ff2a0dde373a';

abstract class _$UserProfileNotifier extends $Notifier<UserProfile> {
  UserProfile build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UserProfile, UserProfile>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<UserProfile, UserProfile>, UserProfile, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}
