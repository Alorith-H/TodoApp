import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// 当前应用版本号（来自 pubspec.yaml）
const String currentVersion = '1.0.0';

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
  static Future<UpdateInfo> checkForUpdate() async {
    try {
      debugPrint('[UpdateService] 正在检查更新...');
      final response = await http
          .get(Uri.parse(_apiUrl), headers: {
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'TodoApp-Update-Checker',
          })
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('[UpdateService] GitHub API 返回 ${response.statusCode}');
        return const UpdateInfo(hasUpdate: false, latestVersion: currentVersion);
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String? ?? '';
      final latestVersion = tagName.replaceAll('v', '');
      final releaseNotes = data['body'] as String? ?? '';
      final downloadUrl = _extractApkUrl(data);

      debugPrint('[UpdateService] 最新版本: $latestVersion, 下载: $downloadUrl');

      final hasUpdate = isNewerVersion(latestVersion, currentVersion);
      debugPrint('[UpdateService] hasUpdate=$hasUpdate');

      // 缓存检查结果
      await _cacheUpdateInfo(hasUpdate, latestVersion, downloadUrl);

      return UpdateInfo(
        hasUpdate: hasUpdate,
        latestVersion: latestVersion,
        downloadUrl: downloadUrl,
        releaseNotes: releaseNotes,
      );
    } catch (e) {
      debugPrint('[UpdateService] 检查更新失败: $e');
      return const UpdateInfo(hasUpdate: false, latestVersion: currentVersion);
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
    // 如果没有 assets 则用 tag 拼接的下载链接
    final tag = release['tag_name'] as String? ?? 'v1.0.0';
    return 'https://github.com/$_repoOwner/$_repoName/releases/download/$tag/TODO.apk';
  }

  /// 打开浏览器去下载页面
  static Future<void> openDownloadPage() async {
    await _cacheUpdateInfo(false, currentVersion, '');
    final url = Uri.parse(
        'https://github.com/$_repoOwner/$_repoName/releases/latest');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// 下载 APK 到本地（Android 专用）
  static Future<String?> downloadApk() async {
    try {
      final url = await _getCachedDownloadUrl();
      if (url == null || url.isEmpty) {
        // 先检查更新获取 URL
        final info = await checkForUpdate();
        if (info.downloadUrl.isEmpty) return null;
      }
      final downloadUrl = await _getCachedDownloadUrl() ?? '';
      if (downloadUrl.isEmpty) return null;

      debugPrint('[UpdateService] 开始下载: $downloadUrl');

      // 下载到应用缓存目录
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/TODO_update.apk');

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

  static Future<String?> _getCachedDownloadUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDownloadUrl);
  }

  /// 获取上次检查时间（毫秒时间戳）
  static Future<int> lastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLastCheck) ?? 0;
  }
}
