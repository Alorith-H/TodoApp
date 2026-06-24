import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 检查更新结果
class UpdateInfo {
  final bool hasUpdate;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;

  const UpdateInfo({
    required this.hasUpdate,
    required this.latestVersion,
    this.downloadUrl = '',
    this.releaseNotes = '',
  });
}

/// 检查更新的服务类
class UpdateService {
  static const String _repoOwner = 'Alorith-H';
  static const String _repoName = 'TodoApp';
  static const String _apiUrl =
      'https://api.github.com/repos/Alorith-H/TodoApp/releases/latest';
  static const String _keyLastCheck = 'last_update_check_time';
  static const String _keyUpdateAvailable = 'update_available';
  static const String _keyLatestVersion = 'latest_version';
  static const String _keyDownloadUrl = 'download_url';

  /// 已忽略的版本号（用户点了忽略后永久不再提示）
  static const String _keyIgnoredVersion = 'ignored_update_version';

  /// 解析版本号字符串为可比较的整数数组
  static List<int> _parseVersion(String version) {
    return version
        .replaceAll('v', '')
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
  }

  /// 比较两个版本号，返回 true 如果 latest > current
  static bool isNewerVersion(String latest, String current) {
    final l = _parseVersion(latest);
    final c = _parseVersion(current);
    final maxLen = l.length > c.length ? l.length : c.length;
    for (int i = 0; i < maxLen; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv != cv) return lv > cv;
    }
    return false;
  }

  /// 从 GitHub API 检查最新 Release
  static Future<UpdateInfo> checkForUpdate(
      {required String currentVersion}) async {
    try {
      debugPrint('[UpdateService] 正在检查更新...');

      final prefs = await SharedPreferences.getInstance();
      final ignoredVersion = prefs.getString(_keyIgnoredVersion) ?? '';

      final response = await http
          .get(Uri.parse(_apiUrl), headers: {
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'TodoApp-Update-Checker',
          })
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('[UpdateService] GitHub API 返回 ${response.statusCode}');
        return const UpdateInfo(hasUpdate: false, latestVersion: '');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String? ?? '';
      final latestVersion = tagName.replaceAll('v', '');
      final releaseNotes = data['body'] as String? ?? '';
      final downloadUrl = _extractApkUrl(data);

      debugPrint('[UpdateService] 最新版本: $latestVersion, 下载: $downloadUrl');

      // 如果这个版本已经被忽略，就不提示
      if (ignoredVersion == latestVersion) {
        debugPrint('[UpdateService] 版本 v$latestVersion 已被忽略');
        return const UpdateInfo(hasUpdate: false, latestVersion: '');
      }

      final hasUpdate = isNewerVersion(latestVersion, currentVersion);

      await _cacheUpdateInfo(hasUpdate, latestVersion, downloadUrl);

      return UpdateInfo(
        hasUpdate: hasUpdate,
        latestVersion: latestVersion,
        downloadUrl: downloadUrl,
        releaseNotes: releaseNotes,
      );
    } catch (e) {
      debugPrint('[UpdateService] 检查更新失败: $e');
      return const UpdateInfo(hasUpdate: false, latestVersion: '');
    }
  }

  /// 从 release JSON 中提取 APK 下载 URL
  static String _extractApkUrl(Map<String, dynamic> release) {
    final assets = release['assets'] as List<dynamic>? ?? [];
    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name.endsWith('.apk')) {
        return asset['browser_download_url'] as String? ?? '';
      }
    }
    final tag = release['tag_name'] as String? ?? 'v1.0.0';
    return 'https://github.com/$_repoOwner/$_repoName/releases/download/$tag/TODO.apk';
  }

  /// 忽略当前版本（永久隐藏小红点）
  static Future<void> ignoreVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyIgnoredVersion, version);
    await _cacheUpdateInfo(false, '', '');
  }

  /// 下载 APK 到应用文档目录，返回文件路径
  static Future<String?> downloadApk({required String downloadUrl}) async {
    try {
      debugPrint('[UpdateService] 开始下载: $downloadUrl');
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/TODO_update.apk');
      if (await file.exists()) {
        await file.delete();
      }
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('[UpdateService] 下载完成: ${file.path}');
        return file.path;
      }
    } catch (e) {
      debugPrint('[UpdateService] 下载失败: $e');
    }
    return null;
  }

  // ─── 缓存方法 ───

  static Future<void> _cacheUpdateInfo(
      bool hasUpdate, String version, String downloadUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUpdateAvailable, hasUpdate);
    await prefs.setString(_keyLatestVersion, version);
    await prefs.setString(_keyDownloadUrl, downloadUrl);
    await prefs.setInt(_keyLastCheck, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<bool> hasCachedUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyUpdateAvailable) ?? false;
  }

  static Future<String?> getCachedLatestVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLatestVersion);
  }

  static Future<String?> getCachedDownloadUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDownloadUrl);
  }

  static Future<int> lastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLastCheck) ?? 0;
  }
}
