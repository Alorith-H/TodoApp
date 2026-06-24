class Task {
  final int? id;
  final String title;
  final String? description;
  final int categoryId;
  final DateTime? dueDate;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? completedAt;
  final bool isRecurring;

  Task({
    this.id,
    required this.title,
    this.description,
    this.categoryId = 1,
    this.dueDate,
    this.isCompleted = false,
    DateTime? createdAt,
    this.completedAt,
    this.isRecurring = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'category_id': categoryId,
      'due_date': dueDate?.toIso8601String(),
      'is_completed': isCompleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'is_recurring': isRecurring ? 1 : 0,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String?,
      categoryId: map['category_id'] as int? ?? 1,
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date'] as String) : null,
      isCompleted: (map['is_completed'] as int?) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      isRecurring: (map['is_recurring'] as int?) == 1,
    );
  }

  Task copyWith({
    int? id,
    String? title,
    String? description,
    int? categoryId,
    DateTime? dueDate,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? completedAt,
    bool? isRecurring,
    bool clearDueDate = false,
    bool clearDescription = false,
    bool clearCompletedAt = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      categoryId: categoryId ?? this.categoryId,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      isRecurring: isRecurring ?? this.isRecurring,
    );
  }

  /// 返回日期分组标签：'逾期'、'今天'、'明天'、'本周'、'以后'
  String get dateGroupLabel {
    if (dueDate == null) return '以后';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final diff = taskDate.difference(today).inDays;

    if (diff < 0) return '逾期';
    if (diff == 0) return '今天';
    if (diff == 1) return '明天';
    if (diff <= 7) return '本周';
    return '以后';
  }

  /// 排序优先级：逾期 > 今天 > 明天 > 本周 > 以后
  int get datePriority {
    switch (dateGroupLabel) {
      case '逾期': return 0;
      case '今天': return 1;
      case '明天': return 2;
      case '本周': return 3;
      case '以后': return 4;
      default: return 5;
    }
  }
}
