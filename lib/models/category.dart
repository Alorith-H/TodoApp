class Category {
  final int? id;
  final String name;
  final String icon;
  final String color;
  final int taskCount;

  Category({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.taskCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'icon': icon,
      'color': color,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: map['color'] as String,
      taskCount: map['task_count'] as int? ?? 0,
    );
  }

  Category copyWith({int? taskCount}) {
    return Category(
      id: id,
      name: name,
      icon: icon,
      color: color,
      taskCount: taskCount ?? this.taskCount,
    );
  }

  static List<Category> defaults() {
    return [
      Category(id: 1, name: '工作', icon: '💼', color: '#4A90D9'),
      Category(id: 2, name: '个人', icon: '👤', color: '#7C4DFF'),
      Category(id: 3, name: '购物', icon: '🛒', color: '#00C853'),
      Category(id: 4, name: '学习', icon: '📚', color: '#FF6D00'),
    ];
  }
}
