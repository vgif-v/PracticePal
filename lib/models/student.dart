import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// SessionItem — one practice session entry
// ---------------------------------------------------------------------------
class SessionItem {
  final int sessionNumber;
  String date; // trainer-editable label, e.g. "Oct 02" or "Session 1"
  bool isCompleted;

  SessionItem({
    required this.sessionNumber,
    required this.date,
    required this.isCompleted,
  });

  Map<String, dynamic> toMap() {
    return {
      'sessionNumber': sessionNumber,
      'date': date,
      'isCompleted': isCompleted,
    };
  }

  factory SessionItem.fromMap(Map<String, dynamic> map) {
    return SessionItem(
      sessionNumber: (map['sessionNumber'] as num?)?.toInt() ?? 0,
      date: map['date'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  SessionItem copyWith({int? sessionNumber, String? date, bool? isCompleted}) {
    return SessionItem(
      sessionNumber: sessionNumber ?? this.sessionNumber,
      date: date ?? this.date,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

// ---------------------------------------------------------------------------
// PaymentDueItem — one payment record tied to a cycle
// ---------------------------------------------------------------------------
class PaymentDueItem {
  final String label;
  final String amount;
  final String dueDate;       // display string, auto-generated or trainer-set
  final int dueSessionNumber; // session that triggers this payment (2 or 8)
  final bool isUrgent;
  final bool isPaid;
  final DateTime? customDueDate; // trainer-edited due date
  final DateTime? paidAt;        // when marked paid

  const PaymentDueItem({
    required this.label,
    required this.amount,
    required this.dueDate,
    this.dueSessionNumber = 2,
    this.isUrgent = false,
    this.isPaid = false,
    this.customDueDate,
    this.paidAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'amount': amount,
      'dueDate': dueDate,
      'dueSessionNumber': dueSessionNumber,
      'isUrgent': isUrgent,
      'isPaid': isPaid,
      'customDueDate': customDueDate != null
          ? Timestamp.fromDate(customDueDate!)
          : null,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
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
      customDueDate:
          (map['customDueDate'] as Timestamp?)?.toDate(),
      paidAt: (map['paidAt'] as Timestamp?)?.toDate(),
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
    DateTime? paidAt,
    bool clearCustomDueDate = false,
    bool clearPaidAt = false,
  }) {
    return PaymentDueItem(
      label: label ?? this.label,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      dueSessionNumber: dueSessionNumber ?? this.dueSessionNumber,
      isUrgent: isUrgent ?? this.isUrgent,
      isPaid: isPaid ?? this.isPaid,
      customDueDate: clearCustomDueDate ? null : (customDueDate ?? this.customDueDate),
      paidAt: clearPaidAt ? null : (paidAt ?? this.paidAt),
    );
  }
}

// ---------------------------------------------------------------------------
// CycleData — one full cycle (8 sessions + 2 payments) for a student
// ---------------------------------------------------------------------------
class CycleData {
  final int cycleNumber;
  final List<SessionItem> sessions;
  final List<PaymentDueItem> payments;

  const CycleData({
    required this.cycleNumber,
    required this.sessions,
    required this.payments,
  });

  Map<String, dynamic> toMap() {
    return {
      'cycleNumber': cycleNumber,
      'sessions': sessions.map((s) => s.toMap()).toList(),
      'payments': payments.map((p) => p.toMap()).toList(),
    };
  }

  factory CycleData.fromMap(Map<String, dynamic> map) {
    return CycleData(
      cycleNumber: (map['cycleNumber'] as num?)?.toInt() ?? 1,
      sessions: (map['sessions'] as List<dynamic>? ?? [])
          .map((s) => SessionItem.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
      payments: (map['payments'] as List<dynamic>? ?? [])
          .map((p) => PaymentDueItem.fromMap(Map<String, dynamic>.from(p as Map)))
          .toList(),
    );
  }

  /// Create a fresh cycle with 8 blank sessions and 2 payment placeholders
  factory CycleData.fresh(int cycleNumber,
      {String defaultPaymentAmount = '₱0'}) {
    final sessions = List.generate(
      8,
      (i) => SessionItem(
        sessionNumber: i + 1,
        date: 'Session ${i + 1}',
        isCompleted: false,
      ),
    );
    final payments = [
      PaymentDueItem(
        label: 'Cycle #$cycleNumber — Payment 1',
        amount: defaultPaymentAmount,
        dueDate: 'After Session 2',
        dueSessionNumber: 2,
        isPaid: false,
      ),
      PaymentDueItem(
        label: 'Cycle #$cycleNumber — Payment 2',
        amount: defaultPaymentAmount,
        dueDate: 'After Session 8',
        dueSessionNumber: 8,
        isPaid: false,
      ),
    ];
    return CycleData(
      cycleNumber: cycleNumber,
      sessions: sessions,
      payments: payments,
    );
  }

  CycleData copyWith({
    int? cycleNumber,
    List<SessionItem>? sessions,
    List<PaymentDueItem>? payments,
  }) {
    return CycleData(
      cycleNumber: cycleNumber ?? this.cycleNumber,
      sessions: sessions ?? this.sessions,
      payments: payments ?? this.payments,
    );
  }
}

// ---------------------------------------------------------------------------
// StudentData — a student's full record within a class
// ---------------------------------------------------------------------------
class StudentData {
  final String name;
  final int age;
  final String address;
  final String trainerName;
  final bool isManuallyAdded; // true if trainer added without auth account
  final DateTime? birthdate;  // for manually-added students

  // Active cycle data (the current cycle being tracked)
  final int cycleNumber;
  final List<SessionItem> sessions;
  final List<PaymentDueItem> payments;

  // Archived previous cycles
  final List<CycleData> cycleHistory;

  const StudentData({
    required this.name,
    required this.age,
    required this.address,
    required this.trainerName,
    required this.cycleNumber,
    required this.sessions,
    required this.payments,
    this.isManuallyAdded = false,
    this.birthdate,
    this.cycleHistory = const [],
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
      'isManuallyAdded': isManuallyAdded,
      'birthdate': birthdate != null ? Timestamp.fromDate(birthdate!) : null,
      'cycleHistory': cycleHistory.map((c) => c.toMap()).toList(),
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
      isManuallyAdded: map['isManuallyAdded'] ?? false,
      birthdate: () {
        final raw = map['birthdate'];
        if (raw == null) return null;
        if (raw is Timestamp) return raw.toDate();
        if (raw is String) return DateTime.tryParse(raw);
        if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
        return null;
      }(),
      cycleHistory: (map['cycleHistory'] as List<dynamic>? ?? [])
          .map((c) => CycleData.fromMap(Map<String, dynamic>.from(c as Map)))
          .toList(),
    );
  }

  StudentData copyWith({
    String? name,
    int? age,
    String? address,
    String? trainerName,
    int? cycleNumber,
    List<SessionItem>? sessions,
    List<PaymentDueItem>? payments,
    bool? isManuallyAdded,
    DateTime? birthdate,
    List<CycleData>? cycleHistory,
  }) {
    return StudentData(
      name: name ?? this.name,
      age: age ?? this.age,
      address: address ?? this.address,
      trainerName: trainerName ?? this.trainerName,
      cycleNumber: cycleNumber ?? this.cycleNumber,
      sessions: sessions ?? this.sessions,
      payments: payments ?? this.payments,
      isManuallyAdded: isManuallyAdded ?? this.isManuallyAdded,
      birthdate: birthdate ?? this.birthdate,
      cycleHistory: cycleHistory ?? this.cycleHistory,
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

  /// Returns a fresh StudentData with cycle 1 initialized (8 sessions, 2 payments)
  factory StudentData.newEnrollment({
    required String name,
    required String trainerName,
    int age = 0,
    String address = '',
    bool isManuallyAdded = false,
    DateTime? birthdate,
    String defaultPaymentAmount = '₱0',
  }) {
    final cycle1 =
        CycleData.fresh(1, defaultPaymentAmount: defaultPaymentAmount);
    return StudentData(
      name: name,
      age: age,
      address: address,
      trainerName: trainerName,
      cycleNumber: 1,
      sessions: cycle1.sessions,
      payments: cycle1.payments,
      isManuallyAdded: isManuallyAdded,
      birthdate: birthdate,
      cycleHistory: const [],
    );
  }

  /// Returns all cycles including the currently active one as a list
  List<CycleData> get allCycles {
    final activeCycle = CycleData(
      cycleNumber: cycleNumber,
      sessions: sessions,
      payments: payments,
    );
    final archived = cycleHistory
        .where((c) => c.cycleNumber != cycleNumber)
        .toList();
    archived.sort((a, b) => a.cycleNumber.compareTo(b.cycleNumber));
    return [...archived, activeCycle];
  }
}
