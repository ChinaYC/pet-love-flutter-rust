import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ota_update/ota_update.dart';

class GitHubUpdateInfo {
  final String latestVersion;
  final String changelog;
  final String downloadUrl;
  final bool hasUpdate;

  GitHubUpdateInfo({
    required this.latestVersion,
    required this.changelog,
    required this.downloadUrl,
    required this.hasUpdate,
  });
}

class UpdateService {
  static const String _owner = 'pet-love';
  static const String _repo = 'pet-love-flutter-rust';
  static const String _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  Future<GitHubUpdateInfo> checkUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    try {
      final response = await http
          .get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = (data['tag_name'] as String).replaceAll('v', '');
        final changelog = data['body'] as String;

        // Find APK asset for Android, or fallback to html_url
        String downloadUrl = data['html_url'];
        final assets = data['assets'] as List;
        if (Platform.isAndroid) {
          final apkAsset = assets.firstWhere(
            (asset) => (asset['name'] as String).endsWith('.apk'),
            orElse: () => null,
          );
          if (apkAsset != null) {
            downloadUrl = apkAsset['browser_download_url'];
          }
        }

        final hasUpdate = _isNewerVersion(currentVersion, latestVersion);

        return GitHubUpdateInfo(
          latestVersion: latestVersion,
          changelog: changelog,
          downloadUrl: downloadUrl,
          hasUpdate: hasUpdate,
        );
      } else {
        throw HttpException('获取更新信息失败 (HTTP ${response.statusCode})',
            uri: Uri.parse(_apiUrl));
      }
    } on SocketException catch (e) {
      if (e.message.contains('Operation not permitted')) {
        throw Exception('系统权限错误：应用被禁止访问网络。请检查 macOS 沙盒权限设置。');
      }
      throw Exception('网络连接失败，请检查您的网络连接或代理设置。($e)');
    } on TimeoutException {
      throw Exception('检查更新超时，请稍后再试。');
    } on HttpException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('检查更新时发生未知错误: $e');
    }
  }

  bool _isNewerVersion(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) return true;
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
    } catch (e) {
      // If version format is not standard, fallback to simple string comparison
      return current != latest;
    }
    return false;
  }

  Stream<OtaEvent> downloadAndInstall(String url) {
    if (Platform.isAndroid) {
      return OtaUpdate().execute(
        url,
        destinationFilename: 'pet-love-update.apk',
      );
    } else {
      throw UnsupportedError('OTA Update is only supported on Android');
    }
  }
}

final updateServiceProvider = Provider((ref) => UpdateService());
