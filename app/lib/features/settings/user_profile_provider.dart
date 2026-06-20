import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../src/rust/api/system.dart';

part 'user_profile_provider.g.dart';

class UserProfile {
  final String name;
  final String? avatarPath;

  UserProfile({required this.name, this.avatarPath});

  UserProfile copyWith({String? name, String? avatarPath}) {
    return UserProfile(
      name: name ?? this.name,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }
}

@riverpod
class UserProfileNotifier extends _$UserProfileNotifier {
  @override
  UserProfile build() {
    return UserProfile(name: 'Alice & Bob');
  }

  void updateProfile({String? name, String? avatarPath}) async {
    state = state.copyWith(name: name, avatarPath: avatarPath);
    if (name != null) {
      await setAppSetting(key: 'user_name', value: name);
    }
    if (avatarPath != null) {
      await setAppSetting(key: 'user_avatar', value: avatarPath);
    }
  }

  void init(UserProfile profile) {
    state = profile;
  }
}
