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
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform Error: $error');
    if (error.toString().contains('SocketException') ||
        error.toString().contains('Connection failed') ||
        error.toString().contains('HttpException')) {
      debugPrint('Caught unhandled network error: $error');
      return true;
    }
    return false;
  };

  runApp(const BootstrapApp());
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late Future<_BootstrapSettings> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrap();
  }

  /// 功能：执行 Rust、数据库与应用设置的启动初始化。
  /// 参数：无。
  /// 返回值：返回启动阶段需要的设置快照。
  /// 注意事项：该过程在 Flutter 首帧之后执行，避免阻塞原生启动页退出。
  Future<_BootstrapSettings> _bootstrap() async {
    await RustLib.init(externalLibrary: _loadRustLibrary());

    final appDir = await getApplicationSupportDirectory();
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    final dbPath = p.join(appDir.path, 'petlove.db');

    assert(() {
      debugPrint('SQLLite Database path: $dbPath');
      return true;
    }());

    await initSystem(dbPath: dbPath);
    return _loadBootstrapSettings();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootstrapSettings>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _BootstrapFallbackApp(
            error: snapshot.error,
            onRetry: () {
              setState(() {
                _bootstrapFuture = _bootstrap();
              });
            },
          );
        }

        if (!snapshot.hasData) {
          return const _BootstrapFallbackApp();
        }

        final settings = snapshot.data!;
        return ProviderScope(
          overrides: [
            if (settings.lastRoute != null)
              initialLocationProvider
                  .overrideWith((ref) => settings.lastRoute!),
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
        );
      },
    );
  }
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

class _BootstrapFallbackApp extends StatelessWidget {
  const _BootstrapFallbackApp({
    this.error,
    this.onRetry,
  });

  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFFFFFFF);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/splash.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            if (error == null)
              const Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (error != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '启动初始化失败：$error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: onRetry,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
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
