import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'src/rust/frb_generated.dart';
import 'src/rust/api/system.dart';
import 'theme/theme_provider.dart';
import 'core/router/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();

  // 初始化数据库
  final appDir = await getApplicationSupportDirectory();
  final dbPath = p.join(appDir.path, 'petlove.db');

  // Debug 模式下打印数据库路径，方便实时查看
  assert(() {
    debugPrint('SQLLite Database path: $dbPath');
    return true;
  }());

  await initSystem(dbPath: dbPath);

  // 读取上次保存的设置
  final lastRoute = await getAppSetting(key: 'last_route');
  final savedThemeMode = await getAppSetting(key: 'theme_mode');
  final savedThemeColor = await getAppSetting(key: 'theme_color');

  runApp(
    ProviderScope(
      overrides: [
        if (lastRoute != null)
          initialLocationProvider.overrideWith((ref) => lastRoute),
        if (savedThemeMode != null)
          initialThemeModeProvider.overrideWithValue(
            ThemeMode.values.byName(savedThemeMode),
          ),
        if (savedThemeColor != null)
          initialThemeColorProvider.overrideWithValue(
            Color(int.parse(savedThemeColor)),
          ),
      ],
      child: const PetLoveApp(),
    ),
  );
}

class PetLoveApp extends ConsumerWidget {
  const PetLoveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeNotifierProvider);
    final themeColor = ref.watch(themeColorNotifierProvider);
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
