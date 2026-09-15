class StudentData {
  final String name;
  final int age;
  final String address;
  final String trainerName;
  final int cycleNumber;
  final List<SessionItem> sessions;
  final List<PaymentDueItem> payments;

  const StudentData({
    required this.name,
    required this.age,
    required this.address,
    required this.trainerName,
    required this.cycleNumber,
    required this.sessions,
    required this.payments,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'address': address,
      'trainerName': trainerName,
      'cycleNumber': cycleNumber,
      'sessions': sessions.map((s) => s.toMap()).toList(),
      'payments': payments.map((p) => p.toMap()).toList(),
    };
  }

  factory StudentData.fromMap(Map<String, dynamic> map) {
    return StudentData(
      name: map['name'] ?? '',
      age: (map['age'] as num?)?.toInt() ?? 0,
      address: map['address'] ?? '',
      trainerName: map['trainerName'] ?? '',
      cycleNumber: (map['cycleNumber'] as num?)?.toInt() ?? 1,
      sessions: (map['sessions'] as List<dynamic>? ?? [])
          .map((s) => SessionItem.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
      payments: (map['payments'] as List<dynamic>? ?? [])
          .map((p) => PaymentDueItem.fromMap(Map<String, dynamic>.from(p as Map)))
          .toList(),
    );
  }

  static StudentData defaultStudent() {
    return const StudentData(
      name: 'Student',
      age: 0,
      address: '',
      trainerName: '',
      cycleNumber: 1,
      sessions: [],
      payments: [],
    );
  }
}

class SessionItem {
  String date;
  bool isCompleted;

  SessionItem({required this.date, required this.isCompleted});

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'isCompleted': isCompleted,
    };
  }

  factory SessionItem.fromMap(Map<String, dynamic> map) {
    return SessionItem(
      date: map['date'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

class PaymentDueItem {
  final String label;
  final String amount;
  final String dueDate;
  final int dueSessionNumber;
  final bool isUrgent;
  final bool isPaid;
  final DateTime? customDueDate;

  const PaymentDueItem({
    required this.label,
    required this.amount,
    required this.dueDate,
    this.dueSessionNumber = 2,
    this.isUrgent = false,
    this.isPaid = false,
    this.customDueDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'amount': amount,
      'dueDate': dueDate,
      'dueSessionNumber': dueSessionNumber,
      'isUrgent': isUrgent,
      'isPaid': isPaid,
    };
  }

  factory PaymentDueItem.fromMap(Map<String, dynamic> map) {
    return PaymentDueItem(
      label: map['label'] ?? '',
      amount: map['amount'] ?? '',
      dueDate: map['dueDate'] ?? '',
      dueSessionNumber: (map['dueSessionNumber'] as num?)?.toInt() ?? 2,
      isUrgent: map['isUrgent'] ?? false,
      isPaid: map['isPaid'] ?? false,
    );
  }

  PaymentDueItem copyWith({
    String? label,
    String? amount,
    String? dueDate,
    int? dueSessionNumber,
    bool? isUrgent,
    bool? isPaid,
    DateTime? customDueDate,
  }) {
    return PaymentDueItem(
      label: label ?? this.label,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      dueSessionNumber: dueSessionNumber ?? this.dueSessionNumber,
      isUrgent: isUrgent ?? this.isUrgent,
      isPaid: isPaid ?? this.isPaid,
      customDueDate: customDueDate ?? this.customDueDate,
    );
  }
}
