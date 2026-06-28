import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'src/rust/frb_generated.dart';
import 'src/rust/api/system.dart';
import 'theme/theme_provider.dart';
import 'core/router/router.dart';
import 'features/settings/user_profile_provider.dart';

class _BootstrapSettings {
  const _BootstrapSettings({
    this.lastRoute,
    this.themeModeName,
    this.themeColorValue,
    this.userName,
    this.userAvatar,
  });

  final String? lastRoute;
  final String? themeModeName;
  final String? themeColorValue;
  final String? userName;
  final String? userAvatar;
}

ExternalLibrary? _loadRustLibrary() {
  if (Platform.isMacOS || Platform.isIOS) {
    return ExternalLibrary.process(iKnowHowToUseIt: true);
  } else if (Platform.isAndroid || Platform.isLinux) {
    return ExternalLibrary.open('librust_lib_petlove.so');
  } else if (Platform.isWindows) {
    return ExternalLibrary.open('rust_lib_petlove.dll');
  }
  return null;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 全局异常捕获：捕获 Flutter 框架异常
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
  };

  // 全局异常捕获：捕获平台/异步异常 (如 HttpClient 连接错误)
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform Error: $error');
    // 如果是网络连接相关的错误，我们在此处进行最后的拦截，防止 App 崩溃
    if (error.toString().contains('SocketException') ||
        error.toString().contains('Connection failed') ||
        error.toString().contains('HttpException')) {
      debugPrint('Caught unhandled network error: $error');
      return true; // 表示错误已被处理
    }
    return false;
  };

  await RustLib.init(externalLibrary: _loadRustLibrary());

  // 初始化数据库
  final appDir = await getApplicationSupportDirectory();
  if (!await appDir.exists()) {
    await appDir.create(recursive: true);
  }
  final dbPath = p.join(appDir.path, 'petlove.db');

  // Debug 模式下打印数据库路径，方便实时查看
  assert(() {
    debugPrint('SQLLite Database path: $dbPath');
    return true;
  }());

  await initSystem(dbPath: dbPath);

  final settings = await _loadBootstrapSettings();

  runApp(
    ProviderScope(
      overrides: [
        if (settings.lastRoute != null)
          initialLocationProvider.overrideWith((ref) => settings.lastRoute!),
        if (settings.themeModeName != null)
          initialThemeModeProvider.overrideWith((ref) {
            try {
              return ThemeMode.values.byName(settings.themeModeName!);
            } catch (_) {
              return ThemeMode.system;
            }
          }),
        if (settings.themeColorValue != null)
          initialThemeColorProvider.overrideWith((ref) {
            try {
              return Color(int.parse(settings.themeColorValue!));
            } catch (_) {
              return const Color(0xFFFF9800);
            }
          }),
        if (settings.userName != null || settings.userAvatar != null)
          initialUserProfileProvider.overrideWith((ref) {
            return UserProfile(
              name: settings.userName ?? 'Alice & Bob',
              avatarPath: settings.userAvatar,
            );
          }),
      ],
      child: const PetLoveApp(),
    ),
  );
}

class PetLoveApp extends ConsumerWidget {
  const PetLoveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final themeColor = ref.watch(themeColorProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      routerConfig: router,
      title: 'PetLove',
      theme: AppTheme.lightTheme(themeColor),
      darkTheme: AppTheme.darkTheme(themeColor),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
    );
  }
}

Future<_BootstrapSettings> _loadBootstrapSettings() async {
  final values = await Future.wait<String?>([
    getAppSetting(key: 'last_route'),
    getAppSetting(key: 'theme_mode'),
    getAppSetting(key: 'theme_color'),
    getAppSetting(key: 'user_name'),
    getAppSetting(key: 'user_avatar'),
  ]);

  return _BootstrapSettings(
    lastRoute: values[0],
    themeModeName: values[1],
    themeColorValue: values[2],
    userName: values[3],
    userAvatar: values[4],
  );
}
