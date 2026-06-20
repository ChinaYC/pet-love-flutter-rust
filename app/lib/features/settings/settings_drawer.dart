import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../src/rust/api/system.dart';
import '../../theme/theme_provider.dart';
import '../debug/db_inspector.dart';
import '../home/pages/inventory/inventory_settings_page.dart';

class SettingsDrawer extends ConsumerWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeNotifierProvider);
    final themeColor = ref.watch(themeColorNotifierProvider);

    final List<Color> themeColors = [
      const Color(0xFFFF9800), // 橘猫橙
      const Color(0xFFFF8FA3), // 浪漫粉
      const Color(0xFF2196F3), // 天空蓝
      const Color(0xFF4CAF50), // 森林绿
      const Color(0xFF9C27B0), // 神秘紫
      const Color(0xFFF44336), // 热情红
    ];

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Row(
                children: [
                  CircleAvatar(radius: 30, backgroundColor: Colors.pinkAccent),
                  SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('小家成员',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Alice & Bob', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(CupertinoIcons.moon),
              title: const Text('暗黑模式'),
              trailing: CupertinoSwitch(
                value: themeMode == ThemeMode.dark,
                activeTrackColor: themeColor,
                onChanged: (val) {
                  ref.read(themeModeNotifierProvider.notifier).toggleTheme();
                },
              ),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.paintbrush),
              title: const Text('主题色'),
              trailing: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: themeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              onTap: () {
                showCupertinoModalPopup(
                  context: context,
                  builder: (context) => Container(
                    padding: const EdgeInsets.all(20),
                    height: 200,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('选择主题色',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 15,
                          runSpacing: 15,
                          children: themeColors.map((color) {
                            final isSelected = color.value == themeColor.value;
                            return GestureDetector(
                              onTap: () {
                                ref
                                    .read(themeColorNotifierProvider.notifier)
                                    .setColor(color);
                                Navigator.pop(context);
                              },
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 45,
                                    height: 45,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(CupertinoIcons.check_mark,
                                        color: Colors.white, size: 24),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.doc_text),
              title: const Text('导出排查日志'),
              onTap: () async {
                // 模拟调用 Rust FFI: export_diagnostic_logs()
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('日志已导出至本地沙盒。')),
                );
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.archivebox),
              title: const Text('囤货功能设置'),
              onTap: () {
                Navigator.pop(context); // 关闭抽屉
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const InventorySettingsPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.cloud_download),
              title: const Text('检查更新'),
              onTap: () async {
                // 调用 Rust FFI: check_app_update()
                try {
                  final updateInfo =
                      await checkAppUpdate(currentVersion: "1.0.0");
                  if (!context.mounted) return;

                  if (updateInfo.hasUpdate) {
                    showDialog(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: Text('发现新版本 ${updateInfo.latestVersion}'),
                        content: Text(updateInfo.changelog),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text('稍后'),
                            onPressed: () => Navigator.pop(context),
                          ),
                          CupertinoDialogAction(
                            isDefaultAction: true,
                            child: const Text('立即更新'),
                            onPressed: () async {
                              final url = Uri.parse(updateInfo.downloadUrl);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url,
                                    mode: LaunchMode.externalApplication);
                              }
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('当前已是最新版本')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('检查更新失败: $e')),
                    );
                  }
                }
              },
            ),
            if (kDebugMode) ...[
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('开发者选项',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.settings),
                title: const Text('SQLite 数据库审查'),
                subtitle: const Text('使用 Rust 高速查询引擎'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DatabaseInspectorPage(),
                    ),
                  );
                },
              ),
            ],
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () {
                  // 触发埋点事件
                  // track_telemetry_event("logout_clicked", "{}");
                },
                child:
                    const Text('退出登录', style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
