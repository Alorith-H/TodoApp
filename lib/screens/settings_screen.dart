import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/settings_model.dart';
import '../services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _settings;
  Map<String, int>? _stats;
  bool _statsLoading = true;
  bool _updateChecking = false;
  String? _updateStatus;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _loadStats();
    _loadUpdateStatus();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await DatabaseHelper().getTaskStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _statsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statsLoading = false);
    }
  }

  Future<void> _loadUpdateStatus() async {
    final hasUpdate = await UpdateService.hasCachedUpdate();
    final version = await UpdateService.getCachedLatestVersion();
    if (!mounted) return;
    setState(() {
      if (hasUpdate) {
        _updateStatus = '发现新版本 v$version';
      }
    });
  }

  void _updateSettings(AppSettings newSettings) {
    setState(() {
      _settings = newSettings;
    });
    widget.onSettingsChanged(newSettings);
  }

  Future<void> _checkUpdate() async {
    setState(() {
      _updateChecking = true;
      _updateStatus = null;
    });

    final info = await UpdateService.checkForUpdate();

    if (!mounted) return;
    setState(() {
      _updateChecking = false;
    });

    if (info.hasUpdate) {
      setState(() {
        _updateStatus = '发现新版本 v${info.latestVersion}';
      });

      _showUpdateDialog(info);
    } else {
      setState(() {
        _updateStatus = '已是最新版';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 已是最新版 v1.0.0'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showUpdateDialog(UpdateInfo info) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue),
            SizedBox(width: 8),
            Text('发现新版本'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前版本：v$currentVersion',
                style: TextStyle(color: Colors.grey[600])),
            Text('最新版本：v${info.latestVersion}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (info.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('更新内容：',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                info.releaseNotes.length > 300
                    ? '${info.releaseNotes.substring(0, 300)}...'
                    : info.releaseNotes,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_browser, size: 18),
            label: const Text('去下载'),
            onPressed: () {
              Navigator.pop(ctx);
              UpdateService.openDownloadPage();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Appearance section ──
          _buildSectionHeader('外观', Icons.palette_outlined),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('主题模式', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('浅色'),
                          icon: Icon(Icons.light_mode),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('系统'),
                          icon: Icon(Icons.brightness_auto),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('深色'),
                          icon: Icon(Icons.dark_mode),
                        ),
                      ],
                      selected: {_settings.themeMode},
                      onSelectionChanged: (selected) {
                        _updateSettings(_settings.copyWith(themeMode: selected.first));
                      },
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('主题色', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: SeedColorOption.options.map((option) {
                      final isSelected = _settings.seedColorValue == option.value;
                      return GestureDetector(
                        onTap: () {
                          _updateSettings(_settings.copyWith(seedColorValue: option.value));
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: option.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: option.color.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 20)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Task defaults section ──
          _buildSectionHeader('任务', Icons.task_outlined),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                // Default due time
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('默认截止时间'),
                  subtitle: Text(
                    '${_settings.defaultDueHour.toString().padLeft(2, '0')}:${_settings.defaultDueMinute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.edit_calendar, size: 20),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: _settings.defaultDueHour,
                        minute: _settings.defaultDueMinute,
                      ),
                      helpText: '选择默认截止时间',
                      cancelText: '取消',
                      confirmText: '确定',
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: Theme.of(context).colorScheme,
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (time != null) {
                      _updateSettings(_settings.copyWith(
                        defaultDueHour: time.hour,
                        defaultDueMinute: time.minute,
                      ));
                    }
                  },
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),

                // Show completed toggle
                ListTile(
                  leading: const Icon(Icons.visibility),
                  title: const Text('显示已完成任务'),
                  trailing: Switch(
                    value: _settings.showCompleted,
                    onChanged: (val) {
                      _updateSettings(_settings.copyWith(showCompleted: val));
                    },
                  ),
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),

                // Sort mode
                ListTile(
                  leading: const Icon(Icons.sort),
                  title: const Text('排序方式'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  subtitle: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('按截止日期'),
                        subtitle: const Text('逾期优先，按日期排序'),
                        value: 'due_date',
                        groupValue: _settings.sortMode,
                        onChanged: (val) {
                          if (val != null) {
                            _updateSettings(_settings.copyWith(sortMode: val));
                          }
                        },
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      RadioListTile<String>(
                        title: const Text('按创建时间'),
                        subtitle: const Text('最新的在前'),
                        value: 'created_at',
                        groupValue: _settings.sortMode,
                        onChanged: (val) {
                          if (val != null) {
                            _updateSettings(_settings.copyWith(sortMode: val));
                          }
                        },
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Statistics section ──
          _buildSectionHeader('数据统计', Icons.bar_chart_outlined),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _statsLoading
                  ? const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : _stats == null
                      ? const Center(child: Text('加载失败'))
                      : Row(
                          children: [
                            _buildStatItem(
                              icon: Icons.task_alt,
                              label: '全部',
                              value: '${_stats!['total']}',
                              color: isDark ? Colors.blue[300]! : Colors.blue,
                            ),
                            _buildStatDivider(),
                            _buildStatItem(
                              icon: Icons.check_circle_outline,
                              label: '已完成',
                              value: '${_stats!['completed']}',
                              color: isDark ? Colors.green[300]! : Colors.green,
                            ),
                            _buildStatDivider(),
                            _buildStatItem(
                              icon: Icons.pending_outlined,
                              label: '待完成',
                              value: '${_stats!['pending']}',
                              color: isDark ? Colors.orange[300]! : Colors.orange,
                            ),
                            _buildStatDivider(),
                            _buildStatItem(
                              icon: Icons.percent,
                              label: '完成率',
                              value: _stats!['total']! > 0
                                  ? '${(_stats!['completed']! / _stats!['total']! * 100).toStringAsFixed(0)}%'
                                  : '0%',
                              color: isDark ? Colors.purple[300]! : Colors.purple,
                            ),
                          ],
                        ),
            ),
          ),

          const SizedBox(height: 8),

          // ── About section ──
          _buildSectionHeader('关于', Icons.info_outline),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                // 版本号
                ListTile(
                  leading: const Icon(Icons.tag),
                  title: const Text('版本号'),
                  subtitle: Text('v$currentVersion'),
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),

                // 检查更新
                ListTile(
                  leading: Icon(
                    Icons.system_update,
                    color: _updateStatus?.contains('新版本') == true
                        ? Colors.blue
                        : null,
                  ),
                  title: const Text('检查更新'),
                  subtitle: Text(
                    _updateChecking
                        ? '正在检查...'
                        : (_updateStatus ?? '点击检查最新版本'),
                    style: TextStyle(
                      color: _updateStatus == '已是最新版'
                          ? Colors.green
                          : (_updateStatus?.contains('新版本') == true
                              ? Colors.blue
                              : null),
                    ),
                  ),
                  trailing: _updateChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : (_updateStatus?.contains('新版本') == true
                          ? const Icon(Icons.circle, color: Colors.red, size: 10)
                          : const Icon(Icons.chevron_right)),
                  onTap: _updateChecking ? null : _checkUpdate,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 48,
      color: Colors.grey.withValues(alpha: 0.2),
    );
  }
}
