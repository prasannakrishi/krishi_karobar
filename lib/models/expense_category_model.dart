class ExpenseCategoryModel {
  final String id;
  final String expenseType; // General, Vehicle, Activity Related
  final String name;
  final bool isActive;

  const ExpenseCategoryModel({
    required this.id,
    required this.expenseType,
    required this.name,
    this.isActive = true,
  });

  factory ExpenseCategoryModel.fromMap(Map<String, dynamic> map) {
    return ExpenseCategoryModel(
      id: map['id']?.toString() ?? '',
      expenseType: map['expenseType']?.toString() ?? 'General',
      name: map['name']?.toString() ?? '',
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expenseType': expenseType,
      'name': name,
      'isActive': isActive,
    };
  }
}
