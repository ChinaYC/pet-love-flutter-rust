import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ota_update/ota_update.dart';
import 'dart:io';
import '../../theme/theme_provider.dart';
import '../debug/db_inspector.dart';
import '../home/pages/inventory/inventory_settings_page.dart';
import './widgets/user_avatar_header.dart';
import '../../core/services/update_service.dart';

class SettingsDrawer extends ConsumerWidget {
  const SettingsDrawer({super.key});

  void _showUpdateDialog(
      BuildContext context, WidgetRef ref, GitHubUpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UpdateDialogContent(
        updateInfo: updateInfo,
        ref: ref,
      ),
    );
  }

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
      backgroundColor: context.adaptiveBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            const UserAvatarHeader(),
            Divider(color: context.theme.dividerColor),
            ListTile(
              leading: const Icon(CupertinoIcons.moon_stars),
              title: const Text('外观设置'),
              trailing: SizedBox(
                width: 180,
                child: CupertinoSlidingSegmentedControl<ThemeMode>(
                  backgroundColor: context.colorScheme.surfaceContainerHigh,
                  groupValue: themeMode,
                  children: {
                    ThemeMode.system: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('跟随',
                          style: TextStyle(
                              fontSize: 12,
                              color: themeMode == ThemeMode.system
                                  ? themeColor
                                  : context.theme.textTheme.bodyMedium?.color)),
                    ),
                    ThemeMode.light: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('白天',
                          style: TextStyle(
                              fontSize: 12,
                              color: themeMode == ThemeMode.light
                                  ? themeColor
                                  : context.theme.textTheme.bodyMedium?.color)),
                    ),
                    ThemeMode.dark: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('黑夜',
                          style: TextStyle(
                              fontSize: 12,
                              color: themeMode == ThemeMode.dark
                                  ? themeColor
                                  : context.theme.textTheme.bodyMedium?.color)),
                    ),
                  },
                  onValueChanged: (ThemeMode? value) {
                    if (value != null) {
                      ref
                          .read(themeModeNotifierProvider.notifier)
                          .setTheme(value);
                    }
                  },
                ),
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
                      color: context.adaptiveBackgroundColor,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('选择主题色',
                            style: context.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 15,
                          runSpacing: 15,
                          children: themeColors.map((color) {
                            final isSelected =
                                color.toARGB32() == themeColor.toARGB32();
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
                // 显示加载提示
                showCupertinoDialog(
                  context: context,
                  builder: (context) => const CupertinoAlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoActivityIndicator(),
                        SizedBox(height: 12),
                        Text('正在检查更新...'),
                      ],
                    ),
                  ),
                );

                try {
                  final updateInfo =
                      await ref.read(updateServiceProvider).checkUpdate();

                  if (context.mounted) {
                    Navigator.pop(context); // 关闭加载弹窗
                  }

                  if (!context.mounted) return;

                  if (updateInfo.hasUpdate) {
                    _showUpdateDialog(context, ref, updateInfo);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('当前已是最新版本')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // 关闭加载弹窗
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$e'),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      ),
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

class _UpdateDialogContent extends StatefulWidget {
  final GitHubUpdateInfo updateInfo;
  final WidgetRef ref;

  const _UpdateDialogContent({
    required this.updateInfo,
    required this.ref,
  });

  @override
  State<_UpdateDialogContent> createState() => _UpdateDialogContentState();
}

class _UpdateDialogContentState extends State<_UpdateDialogContent> {
  double? progress;
  String? status;
  bool isDownloading = false;

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text('发现新版本 ${widget.updateInfo.latestVersion}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text(widget.updateInfo.changelog, textAlign: TextAlign.left),
          if (isDownloading && status != null) ...[
            const SizedBox(height: 16),
            Text(status!,
                style: const TextStyle(fontSize: 12, color: Colors.blue)),
            if (progress != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress! / 100),
            ],
          ],
        ],
      ),
      actions: [
        if (!isDownloading)
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后'),
          ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: isDownloading
              ? null
              : () async {
                  if (Platform.isAndroid &&
                      widget.updateInfo.downloadUrl.endsWith('.apk')) {
                    setState(() {
                      isDownloading = true;
                      status = '正在初始化下载...';
                    });

                    try {
                      widget.ref
                          .read(updateServiceProvider)
                          .downloadAndInstall(widget.updateInfo.downloadUrl)
                          .listen(
                        (event) {
                          if (!context.mounted) return;
                          setState(() {
                            progress = double.tryParse(event.value ?? '');
                            switch (event.status) {
                              case OtaStatus.DOWNLOADING:
                                status = '正在下载: ${event.value}%';
                                break;
                              case OtaStatus.INSTALLING:
                                status = '下载完成，准备安装...';
                                break;
                              case OtaStatus.ALREADY_RUNNING_ERROR:
                                status = '更新已在运行';
                                break;
                              case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                                status = '未获得安装权限';
                                break;
                              case OtaStatus.DOWNLOAD_ERROR:
                                status = '下载失败，请检查网络';
                                break;
                              default:
                                status = '更新失败: ${event.status}';
                            }
                          });

                          if (event.status == OtaStatus.INSTALLING ||
                              event.status.name.contains('ERROR')) {
                            if (event.status.name.contains('ERROR')) {
                              Future.delayed(const Duration(seconds: 2), () {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              });
                            }
                          }
                        },
                        onError: (e) {
                          if (!context.mounted) return;
                          setState(() {
                            status = '下载出错: $e';
                          });
                          Future.delayed(const Duration(seconds: 2), () {
                            if (context.mounted) Navigator.pop(context);
                          });
                        },
                        cancelOnError: true,
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      setState(() {
                        isDownloading = false;
                        status = '无法启动下载: $e';
                      });
                    }
                  } else {
                    final url = Uri.parse(widget.updateInfo.downloadUrl);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    }
                    if (context.mounted) Navigator.pop(context);
                  }
                },
          child: Text(isDownloading ? '正在更新' : '立即更新'),
        ),
      ],
    );
  }
}
