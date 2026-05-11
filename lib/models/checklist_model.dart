class ChecklistItem {
  String id;
  String title;
  String? description;
  bool isCompleted;
  String? photoPath;
  String? notes;
  DateTime? completedAt;

  ChecklistItem({
    required this.id,
    required this.title,
    this.description,
    this.isCompleted = false,
    this.photoPath,
    this.notes,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'isCompleted': isCompleted,
    'photoPath': photoPath,
    'notes': notes,
    'completedAt': completedAt?.toIso8601String(),
  };

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    isCompleted: json['isCompleted'] ?? false,
    photoPath: json['photoPath'],
    notes: json['notes'],
    completedAt: json['completedAt'] != null 
        ? DateTime.parse(json['completedAt']) 
        : null,
  );
}

class ChecklistTemplate {
  String id;
  String name;
  String? brandName; // null = todos
  List<ChecklistItem> items;
  DateTime createdAt;

  ChecklistTemplate({
    required this.id,
    required this.name,
    this.brandName,
    required this.items,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brandName': brandName,
    'items': items.map((e) => e.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory ChecklistTemplate.fromJson(Map<String, dynamic> json) => ChecklistTemplate(
    id: json['id'],
    name: json['name'],
    brandName: json['brandName'],
    items: (json['items'] as List).map((e) => ChecklistItem.fromJson(e)).toList(),
    createdAt: DateTime.parse(json['createdAt']),
  );

  ChecklistTemplate copyWith({String? id}) {
    return ChecklistTemplate(
      id: id ?? this.id,
      name: name,
      brandName: brandName,
      items: items.map((e) => ChecklistItem(
        id: e.id,
        title: e.title,
        description: e.description,
      )).toList(),
      createdAt: DateTime.now(),
    );
  }
}
