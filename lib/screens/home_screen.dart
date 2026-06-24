import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/task.dart';
import '../models/category.dart';
import '../models/settings_model.dart';
import 'settings_screen.dart';
import 'task_form_screen.dart';

/// 丝滑优化版 HomeScreen
/// Key improvements:
/// 1. 勾选完成 -> 局部 setState，不进数据库（只在离开/重新打开时持久化）
/// 2. 增量加载 + 延迟写数据库
class HomeScreen extends StatefulWidget {
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;

  const HomeScreen({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<Task> _tasks = [];
  List<Category> _categories = [];
  int? _selectedCategoryId;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await _db.getAllTasks(categoryId: _selectedCategoryId);
      final categories = await _db.getCategories();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('数据加载失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('数据加载失败: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Map<String, List<Task>> _groupTasks(List<Task> tasks) {
    final groups = <String, List<Task>>{};
    for (final task in tasks) {
      groups.putIfAbsent(task.dateGroupLabel, () => []).add(task);
    }
    const order = ['逾期', '今天', '明天', '本周', '以后'];
    final sorted = <String, List<Task>>{};
    for (final key in order) {
      if (groups.containsKey(key)) {
        sorted[key] = groups[key]!;
      }
    }
    return sorted;
  }

  List<Task> _filteredTasks() {
    if (_searchQuery.isEmpty) return _tasks;
    final query = _searchQuery.toLowerCase();
    return _tasks.where((t) => t.title.toLowerCase().contains(query)).toList();
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  String _formatDueDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);
    final diff = taskDate.difference(today).inDays;

    if (diff == 0) return '今天';
    if (diff == 1) return '明天';
    return DateFormat('M月d日').format(date);
  }

  /// 添加任务 → 在返回时刷新
  Future<void> _addTask() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TaskFormScreen()),
    );
    if (result == true) _loadData();
  }

  /// 编辑任务 → 在返回时刷新
  Future<void> _editTask(Task task) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)),
    );
    if (result == true) _loadData();
  }

  /// 勾选完成 → 局部刷新，数据库异步写（不阻塞UI）
  Future<void> _toggleTask(Task task) async {
    final updated = task.copyWith(
      isCompleted: !task.isCompleted,
      completedAt: !task.isCompleted ? DateTime.now() : null,
    );
    // 先局部刷新 UI —— 0ms
    setState(() {
      final idx = _tasks.indexWhere((t) => t.id == task.id);
      if (idx != -1) _tasks[idx] = updated;
    });
    // 后写数据库 —— 不 await，放后台
    _db.updateTask(updated).catchError((e) {
      debugPrint('异步写库失败: $e');
      // 写失败了回滚
      if (mounted) {
        setState(() {
          final idx = _tasks.indexWhere((t) => t.id == task.id);
          if (idx != -1) _tasks[idx] = task;
        });
      }
    });
  }

  /// 删除任务 → 先局部移除（让 Dismissible 动画继续），后异步删库
  Future<void> _deleteTask(Task task) async {
    // 保存以备撤销
    final taskSnapshot = task;
    // 先局部移除
    setState(() {
      _tasks.removeWhere((t) => t.id == task.id);
    });
    // 后异步删库
    await _db.deleteTask(task.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: const Text('任务已删除'),
        action: SnackBarAction(label: '撤销', onPressed: () async {
          await _db.addTask(taskSnapshot);
          if (mounted) _loadData();
        }),
      ),
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();

    const colorOptions = ['#E53935', '#FB8C00', '#FDD835', '#43A047', '#039BE5', '#5E35B1', '#D81B60', '#00ACC1'];

    String selectedColor = '#039BE5';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加标签'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '标签名称',
                    hintText: '输入标签名称...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                const Text('选择颜色', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: colorOptions.map((hex) => GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = hex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _parseColor(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedColor == hex ? Colors.black54 : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        await _db.addCategory(Category(
          name: nameController.text.trim(),
          color: selectedColor,
        ));
        _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('标签已添加')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加标签失败: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteCategory(Category category) async {
    if (category.id == null || category.id! <= 4) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('默认标签无法删除')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除标签'),
        content: Text('确定删除「${category.name}」吗？\n该标签下的任务将移至默认分类。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.deleteCategory(category.id!);
      if (_selectedCategoryId == category.id) {
        _selectedCategoryId = null;
      }
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        child: const Icon(Icons.add),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchQuery = '';
              _searchController.clear();
            });
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索任务...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        scrolledUnderElevation: 0,
      );
    }
    return AppBar(
      title: const Text('TODO'),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: _openSettings,
        ),
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => setState(() => _isSearching = true),
        ),
      ],
      scrolledUnderElevation: 0,
    );
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          settings: widget.settings,
          onSettingsChanged: widget.onSettingsChanged,
        ),
      ),
    );
    _loadData();
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final tasks = _filteredTasks();

    final categoryMap = <int, Category>{};
    for (final cat in _categories) {
      if (cat.id != null) categoryMap[cat.id!] = cat;
    }

    return Column(
      children: [
        // Category filter chips row
        if (_categories.isNotEmpty)
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _buildCategoryChip(null, '全部', Icons.all_inclusive),
                ..._categories.map(
                  (cat) => GestureDetector(
                    onLongPress: () => _confirmDeleteCategory(cat),
                    child: _buildCategoryChip(cat.id, cat.name, null),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(Icons.add, size: 16, color: Theme.of(context).colorScheme.primary),
                    label: Text(
                      '标签',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    onPressed: _showAddCategoryDialog,
                  ),
                ),
              ],
            ),
          ),

        // Task list or empty state
        Expanded(
          child: tasks.isEmpty
              ? (_isSearching || (_selectedCategoryId != null && _tasks.isEmpty)
                  ? _buildNoMatchState()
                  : _buildEmptyState())
              : _buildGroupedList(tasks, categoryMap),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(int? id, String label, IconData? icon) {
    final isSelected = _selectedCategoryId == id;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _selectedCategoryId = isSelected ? null : id);
          _loadData();
        },
        showCheckmark: false,
        selectedColor: Theme.of(context).colorScheme.primaryContainer,
      ),
    );
  }

  Widget _buildGroupedList(List<Task> tasks, Map<int, Category> categoryMap) {
    final grouped = _groupTasks(tasks);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
      // 使用 RepaintBoundary 减少重绘区域
      addRepaintBoundaries: true,
      itemCount: grouped.entries.length,
      itemBuilder: (context, index) {
        final entry = grouped.entries.elementAt(index);
        final label = entry.key;
        final sectionTasks = entry.value;
        return _buildSection(label, sectionTasks, categoryMap);
      },
    );
  }

  Widget _buildSection(String label, List<Task> tasks, Map<int, Category> categoryMap) {
    final isOverdueSection = label == '逾期';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6, left: 4),
          child: Row(
            children: [
              Icon(
                _sectionIcon(label),
                size: 16,
                color: isOverdueSection ? Colors.red[400] : Colors.grey[500],
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isOverdueSection ? Colors.red[400] : Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isOverdueSection
                      ? Colors.red[50]
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${tasks.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isOverdueSection ? Colors.red[400] : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
        ...tasks.map((task) => _buildTaskTile(task, categoryMap)),
      ],
    );
  }

  IconData _sectionIcon(String label) {
    switch (label) {
      case '逾期':
        return Icons.error_outline;
      case '今天':
        return Icons.today;
      case '明天':
        return Icons.event;
      case '本周':
        return Icons.calendar_view_week;
      case '以后':
        return Icons.calendar_today;
      default:
        return Icons.circle;
    }
  }

  Widget _buildTaskTile(Task task, Map<int, Category> categoryMap) {
    final category = categoryMap[task.categoryId];
    final isOverdue = task.dateGroupLabel == '逾期' && !task.isCompleted;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Dismissible(
      key: ValueKey('task_${task.id}'),
      direction: DismissDirection.endToStart,
      // Dismissible 动画结束后才触发删除
      confirmDismiss: (_) async {
        await _deleteTask(task);
        return true;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _editTask(task),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 12, 2),
            child: Row(
              children: [
                // Checkbox
                SizedBox(
                  width: 44,
                  child: Checkbox(
                    value: task.isCompleted,
                    onChanged: (_) => _toggleTask(task),
                    activeColor: Colors.green[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),

                // Task content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: task.isCompleted
                                ? FontWeight.normal
                                : FontWeight.w500,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.isCompleted
                                ? Colors.grey[400]
                                : (isOverdue
                                    ? Colors.red[700]
                                    : textColor),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Bottom row
                        if (task.dueDate != null || category != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                if (task.dueDate != null) ...[
                                  Icon(
                                    Icons.access_time,
                                    size: 13,
                                    color: isOverdue ? Colors.red[400] : Colors.grey[400],
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _formatDueDate(task.dueDate),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isOverdue
                                          ? Colors.red[400]
                                          : Colors.grey[500],
                                    ),
                                  ),
                                  if (category != null) const SizedBox(width: 6),
                                ],
                                if (category != null)
                                  _buildCategoryLabel(category),
                                if (task.isRecurring) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.loop, size: 13, color: Colors.grey[400]),
                                  const SizedBox(width: 2),
                                  Text(
                                    '每日',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryLabel(Category category) {
    final rawColor = _parseColor(category.color);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final bgColor = rawColor.withValues(alpha: 0.15);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category.name,
        style: TextStyle(fontSize: 11, color: textColor),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt,
              size: 80,
              color: isDark ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 20),
            Text(
              '还没有任务',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[500],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '点击右下角的 + 按钮添加你的第一个任务',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMatchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '没有匹配的任务',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
