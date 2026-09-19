import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/student.dart';

// ---------------------------------------------------------------------------
// ClassModel — represents a trainer's class document in Firestore
// ---------------------------------------------------------------------------
class ClassModel {
  final String id;
  final String name;
  final String joinCode;
  final String trainerId;
  final String trainerName;
  final String schedule;
  final String room;
  final String defaultPaymentAmount;
  final List<StudentData> students;
  final DateTime? createdAt;

  ClassModel({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.trainerId,
    required this.trainerName,
    this.schedule = 'Flexible Schedule',
    this.room = 'Main Studio',
    this.defaultPaymentAmount = '₱0',
    this.students = const [],
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'joinCode': joinCode,
      'trainerId': trainerId,
      'trainerName': trainerName,
      'schedule': schedule,
      'room': room,
      'defaultPaymentAmount': defaultPaymentAmount,
      'studentCount': students.length,
      'students': students.map((s) => s.toMap()).toList(),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory ClassModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawStudents = data['students'] as List<dynamic>? ?? [];
    return ClassModel(
      id: doc.id,
      name: data['name'] ?? '',
      joinCode: data['joinCode'] ?? '',
      trainerId: data['trainerId'] ?? '',
      trainerName: data['trainerName'] ?? '',
      schedule: data['schedule'] ?? 'Flexible Schedule',
      room: data['room'] ?? 'Main Studio',
      defaultPaymentAmount: data['defaultPaymentAmount'] as String? ?? '₱0',
      students: rawStudents
          .map((s) => StudentData.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

// ---------------------------------------------------------------------------
// ClassService — all Firestore operations for classes and student tracking
// ---------------------------------------------------------------------------
class ClassService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Public getter so screens can perform one-off reads after writes
  FirebaseFirestore get db => _firestore;

  // ---------------------------------------------------------------------------
  // Stream trainer's own classes
  // ---------------------------------------------------------------------------
  Stream<List<ClassModel>> streamTrainerClasses(String trainerId) {
    if (trainerId.isEmpty) return Stream.value([]);
    return _firestore
        .collection('classes')
        .where('trainerId', isEqualTo: trainerId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ClassModel.fromFirestore(doc)).toList())
        .handleError((error) {
      debugPrint('ClassService streamTrainerClasses error: $error');
      return <ClassModel>[];
    });
  }

  // ---------------------------------------------------------------------------
  // Create a new class
  // ---------------------------------------------------------------------------
  Future<String> createClass({
    required String name,
    required String trainerId,
    required String trainerName,
    String schedule = 'Flexible Schedule',
    String room = 'Main Studio',
    String defaultPaymentAmount = '₱0',
  }) async {
    // Format payment amount with peso sign
    var cleanAmount = defaultPaymentAmount.trim();
    if (cleanAmount.isEmpty) {
      cleanAmount = '₱0';
    } else {
      if (cleanAmount.startsWith('Php') || cleanAmount.startsWith('PHP')) {
        cleanAmount = cleanAmount.substring(3).trim();
      }
      if (!cleanAmount.startsWith('₱')) {
        cleanAmount = '₱$cleanAmount';
      }
    }

    final randomDigits = 1000 + Random().nextInt(9000);
    final joinCode = 'PP-$randomDigits';
    final docRef = await _firestore.collection('classes').add({
      'name': name,
      'joinCode': joinCode,
      'trainerId': trainerId,
      'trainerName': trainerName,
      'schedule': schedule,
      'room': room,
      'defaultPaymentAmount': cleanAmount,
      'studentCount': 0,
      'students': [],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // ---------------------------------------------------------------------------
  // Delete class (client-side recursive — removes class doc only since
  // students live inside the class doc, not in subcollections for Phase 1)
  // ---------------------------------------------------------------------------
  Future<void> deleteClass(String classId) async {
    // Phase 1: students are embedded in the class doc, so just delete the doc.
    // Also clean up any members subcollection docs if they exist.
    try {
      final members = await _firestore
          .collection('classes')
          .doc(classId)
          .collection('members')
          .get();
      final batch = _firestore.batch();
      for (final doc in members.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_firestore.collection('classes').doc(classId));
      await batch.commit();
    } catch (e) {
      debugPrint('deleteClass error: $e');
      // Fallback: just delete the main doc
      await _firestore.collection('classes').doc(classId).delete();
    }
  }

  // ---------------------------------------------------------------------------
  // Update entire students array (low-level helper)
  // ---------------------------------------------------------------------------
  Future<void> updateStudents(String classId, List<StudentData> students) async {
    await _firestore.collection('classes').doc(classId).update({
      'students': students.map((s) => s.toMap()).toList(),
      'studentCount': students.length,
    });
  }

  // ---------------------------------------------------------------------------
  // Toggle a session's isCompleted for a student (trainer only)
  // ---------------------------------------------------------------------------
  Future<void> toggleSessionCompleted({
    required String classId,
    required String studentName,
    required int cycleNumber,
    required int sessionIndex,
    required bool isCompleted,
  }) async {
    final doc = await _firestore.collection('classes').doc(classId).get();
    final cls = ClassModel.fromFirestore(doc);
    final students = List<StudentData>.from(cls.students);
    final idx = students.indexWhere(
      (s) => s.name.toLowerCase() == studentName.toLowerCase(),
    );
    if (idx == -1) return;

    final student = students[idx];
    // Find the matching cycle
    if (student.cycleNumber == cycleNumber) {
      // Active cycle
      final sessions = List<SessionItem>.from(student.sessions);
      if (sessionIndex < sessions.length) {
        sessions[sessionIndex] = sessions[sessionIndex].copyWith(isCompleted: isCompleted);
        students[idx] = student.copyWith(sessions: sessions);
      }
    } else {
      // Historical cycle
      final history = List<CycleData>.from(student.cycleHistory);
      final cIdx = history.indexWhere((c) => c.cycleNumber == cycleNumber);
      if (cIdx != -1) {
        final sessions = List<SessionItem>.from(history[cIdx].sessions);
        if (sessionIndex < sessions.length) {
          sessions[sessionIndex] = sessions[sessionIndex].copyWith(isCompleted: isCompleted);
          history[cIdx] = history[cIdx].copyWith(sessions: sessions);
          students[idx] = student.copyWith(cycleHistory: history);
        }
      }
    }
    await updateStudents(classId, students);
  }

  // ---------------------------------------------------------------------------
  // Toggle a payment's isPaid (trainer only)
  // ---------------------------------------------------------------------------
  Future<void> togglePaymentPaid({
    required String classId,
    required String studentName,
    required int cycleNumber,
    required int paymentIndex,
    required bool isPaid,
  }) async {
    final doc = await _firestore.collection('classes').doc(classId).get();
    final cls = ClassModel.fromFirestore(doc);
    final students = List<StudentData>.from(cls.students);
    final idx = students.indexWhere(
      (s) => s.name.toLowerCase() == studentName.toLowerCase(),
    );
    if (idx == -1) return;

    final student = students[idx];
    if (student.cycleNumber == cycleNumber) {
      final payments = List<PaymentDueItem>.from(student.payments);
      if (paymentIndex < payments.length) {
        payments[paymentIndex] = payments[paymentIndex].copyWith(
          isPaid: isPaid,
          paidAt: isPaid ? DateTime.now() : null,
          clearPaidAt: !isPaid,
        );
        students[idx] = student.copyWith(payments: payments);
      }
    } else {
      final history = List<CycleData>.from(student.cycleHistory);
      final cIdx = history.indexWhere((c) => c.cycleNumber == cycleNumber);
      if (cIdx != -1) {
        final payments = List<PaymentDueItem>.from(history[cIdx].payments);
        if (paymentIndex < payments.length) {
          payments[paymentIndex] = payments[paymentIndex].copyWith(
            isPaid: isPaid,
            paidAt: isPaid ? DateTime.now() : null,
            clearPaidAt: !isPaid,
          );
          history[cIdx] = history[cIdx].copyWith(payments: payments);
          students[idx] = student.copyWith(cycleHistory: history);
        }
      }
    }
    await updateStudents(classId, students);
  }

  // ---------------------------------------------------------------------------
  // Update a payment's due date (trainer only)
  // ---------------------------------------------------------------------------
  Future<void> updatePaymentDueDate({
    required String classId,
    required String studentName,
    required int cycleNumber,
    required int paymentIndex,
    required DateTime newDate,
  }) async {
    final doc = await _firestore.collection('classes').doc(classId).get();
    final cls = ClassModel.fromFirestore(doc);
    final students = List<StudentData>.from(cls.students);
    final idx = students.indexWhere(
      (s) => s.name.toLowerCase() == studentName.toLowerCase(),
    );
    if (idx == -1) return;

    final student = students[idx];
    // Format the display string
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final label = '${months[newDate.month - 1]} ${newDate.day}, ${newDate.year}';

    if (student.cycleNumber == cycleNumber) {
      final payments = List<PaymentDueItem>.from(student.payments);
      if (paymentIndex < payments.length) {
        payments[paymentIndex] = payments[paymentIndex].copyWith(
          customDueDate: newDate,
          dueDate: label,
        );
        students[idx] = student.copyWith(payments: payments);
      }
    } else {
      final history = List<CycleData>.from(student.cycleHistory);
      final cIdx = history.indexWhere((c) => c.cycleNumber == cycleNumber);
      if (cIdx != -1) {
        final payments = List<PaymentDueItem>.from(history[cIdx].payments);
        if (paymentIndex < payments.length) {
          payments[paymentIndex] = payments[paymentIndex].copyWith(
            customDueDate: newDate,
            dueDate: label,
          );
          history[cIdx] = history[cIdx].copyWith(payments: payments);
          students[idx] = student.copyWith(cycleHistory: history);
        }
      }
    }
    await updateStudents(classId, students);
  }

  // ---------------------------------------------------------------------------
  // Update a payment's amount (trainer only, always formatted with peso sign ₱)
  // ---------------------------------------------------------------------------
  Future<void> updatePaymentAmount({
    required String classId,
    required String studentName,
    required int cycleNumber,
    required int paymentIndex,
    required String newAmount,
  }) async {
    final doc = await _firestore.collection('classes').doc(classId).get();
    final cls = ClassModel.fromFirestore(doc);
    final students = List<StudentData>.from(cls.students);
    final idx = students.indexWhere(
      (s) => s.name.toLowerCase() == studentName.toLowerCase(),
    );
    if (idx == -1) return;

    // Ensure amount always starts with peso sign ₱
    var clean = newAmount.trim();
    if (clean.startsWith('Php') || clean.startsWith('PHP')) {
      clean = clean.substring(3).trim();
    }
    if (!clean.startsWith('₱')) {
      clean = '₱$clean';
    }

    final student = students[idx];
    if (student.cycleNumber == cycleNumber) {
      final payments = List<PaymentDueItem>.from(student.payments);
      if (paymentIndex < payments.length) {
        payments[paymentIndex] = payments[paymentIndex].copyWith(
          amount: clean,
        );
        students[idx] = student.copyWith(payments: payments);
      }
    } else {
      final history = List<CycleData>.from(student.cycleHistory);
      final cIdx = history.indexWhere((c) => c.cycleNumber == cycleNumber);
      if (cIdx != -1) {
        final payments = List<PaymentDueItem>.from(history[cIdx].payments);
        if (paymentIndex < payments.length) {
          payments[paymentIndex] = payments[paymentIndex].copyWith(
            amount: clean,
          );
          history[cIdx] = history[cIdx].copyWith(payments: payments);
          students[idx] = student.copyWith(cycleHistory: history);
        }
      }
    }
    await updateStudents(classId, students);
  }

  // ---------------------------------------------------------------------------
  // Update a session's date label (trainer class settings)
  // ---------------------------------------------------------------------------
  Future<void> updateSessionDate({
    required String classId,
    required String studentName,
    required int cycleNumber,
    required int sessionIndex,
    required String newDate,
  }) async {
    final doc = await _firestore.collection('classes').doc(classId).get();
    final cls = ClassModel.fromFirestore(doc);
    final students = List<StudentData>.from(cls.students);
    final idx = students.indexWhere(
      (s) => s.name.toLowerCase() == studentName.toLowerCase(),
    );
    if (idx == -1) return;

    final student = students[idx];
    if (student.cycleNumber == cycleNumber) {
      final sessions = List<SessionItem>.from(student.sessions);
      if (sessionIndex < sessions.length) {
        sessions[sessionIndex] = sessions[sessionIndex].copyWith(date: newDate);
        students[idx] = student.copyWith(sessions: sessions);
      }
    } else {
      final history = List<CycleData>.from(student.cycleHistory);
      final cIdx = history.indexWhere((c) => c.cycleNumber == cycleNumber);
      if (cIdx != -1) {
        final sessions = List<SessionItem>.from(history[cIdx].sessions);
        if (sessionIndex < sessions.length) {
          sessions[sessionIndex] = sessions[sessionIndex].copyWith(date: newDate);
          history[cIdx] = history[cIdx].copyWith(sessions: sessions);
          students[idx] = student.copyWith(cycleHistory: history);
        }
      }
    }
    await updateStudents(classId, students);
  }

  // ---------------------------------------------------------------------------
  // Add another session to a cycle (trainer only)
  // ---------------------------------------------------------------------------
  Future<void> addSession({
    required String classId,
    required String studentName,
    required int cycleNumber,
    String? sessionLabel,
  }) async {
    final doc = await _firestore.collection('classes').doc(classId).get();
    final cls = ClassModel.fromFirestore(doc);
    final students = List<StudentData>.from(cls.students);
    final idx = students.indexWhere(
      (s) => s.name.toLowerCase() == studentName.toLowerCase(),
    );
    if (idx == -1) return;

    final student = students[idx];
    if (student.cycleNumber == cycleNumber) {
      final sessions = List<SessionItem>.from(student.sessions);
      final newNumber = sessions.length + 1;
      final label = sessionLabel?.trim().isNotEmpty == true
          ? sessionLabel!.trim()
          : 'Session $newNumber';
      sessions.add(SessionItem(
        sessionNumber: newNumber,
        date: label,
        isCompleted: false,
      ));
      students[idx] = student.copyWith(sessions: sessions);
    } else {
      final history = List<CycleData>.from(student.cycleHistory);
      final cIdx = history.indexWhere((c) => c.cycleNumber == cycleNumber);
      if (cIdx != -1) {
        final sessions = List<SessionItem>.from(history[cIdx].sessions);
        final newNumber = sessions.length + 1;
        final label = sessionLabel?.trim().isNotEmpty == true
            ? sessionLabel!.trim()
            : 'Session $newNumber';
        sessions.add(SessionItem(
          sessionNumber: newNumber,
          date: label,
          isCompleted: false,
        ));
        history[cIdx] = history[cIdx].copyWith(sessions: sessions);
        students[idx] = student.copyWith(cycleHistory: history);
      }
    }
    await updateStudents(classId, students);
  }

  // ---------------------------------------------------------------------------
  // Start a new cycle for a student (archives current cycle, starts fresh)
  // ---------------------------------------------------------------------------
  Future<void> addNewCycle({
    required String classId,
    required String studentName,
  }) async {
    final doc = await _firestore.collection('classes').doc(classId).get();
    final cls = ClassModel.fromFirestore(doc);
    final students = List<StudentData>.from(cls.students);
    final idx = students.indexWhere(
      (s) => s.name.toLowerCase() == studentName.toLowerCase(),
    );
    if (idx == -1) return;

    final student = students[idx];
    // Archive current cycle into history
    final archivedCycle = CycleData(
      cycleNumber: student.cycleNumber,
      sessions: student.sessions,
      payments: student.payments,
    );
    final newHistory = [...student.cycleHistory, archivedCycle];
    final nextCycleNum = student.cycleNumber + 1;
    final freshCycle = CycleData.fresh(nextCycleNum,
        defaultPaymentAmount: cls.defaultPaymentAmount);

    students[idx] = student.copyWith(
      cycleNumber: nextCycleNum,
      sessions: freshCycle.sessions,
      payments: freshCycle.payments,
      cycleHistory: newHistory,
    );
    await updateStudents(classId, students);
  }

  // ---------------------------------------------------------------------------
  // Manually enroll a student (trainer adds without join code or auth account)
  // ---------------------------------------------------------------------------
  Future<void> addManualStudent({
    required String classId,
    required String trainerName,
    required String studentName,
    String address = '',
    int age = 0,
    DateTime? birthdate,
  }) async {
    final doc = await _firestore.collection('classes').doc(classId).get();
    final cls = ClassModel.fromFirestore(doc);

    // Check not already enrolled
    final exists = cls.students.any(
      (s) => s.name.toLowerCase() == studentName.toLowerCase(),
    );
    if (exists) return;

    final newStudent = StudentData.newEnrollment(
      name: studentName,
      trainerName: trainerName,
      age: age,
      address: address,
      isManuallyAdded: true,
      birthdate: birthdate,
      defaultPaymentAmount: cls.defaultPaymentAmount,
    );

    final updatedStudents = [...cls.students, newStudent];
    await updateStudents(classId, updatedStudents);
  }

  // ---------------------------------------------------------------------------
  // Join a class by code (for Students via self-service)
  // ---------------------------------------------------------------------------
  Future<ClassModel?> joinClassByCode({
    required String joinCode,
    required String studentId,
    required String studentName,
    String address = '',
    int age = 0,
  }) async {
    final normalizedCode = joinCode.trim().toUpperCase();
    final query = await _firestore
        .collection('classes')
        .where('joinCode', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    final cls = ClassModel.fromFirestore(doc);

    // Check if student is already in the class
    final existingIndex = cls.students
        .indexWhere((s) => s.name.toLowerCase() == studentName.toLowerCase());
    if (existingIndex == -1) {
      final newStudent = StudentData.newEnrollment(
        name: studentName,
        trainerName: cls.trainerName,
        age: age,
        address: address,
        defaultPaymentAmount: cls.defaultPaymentAmount,
      );

      final updatedStudents = [...cls.students, newStudent];
      await updateStudents(cls.id, updatedStudents);

      // Record in student's enrolled_classes subcollection
      if (studentId.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(studentId)
            .collection('enrolled_classes')
            .doc(cls.id)
            .set({
          'classId': cls.id,
          'className': cls.name,
          'trainerName': cls.trainerName,
          'trainerId': cls.trainerId,
          'joinCode': cls.joinCode,
          'schedule': cls.schedule,
          'room': cls.room,
          'enrolledAt': FieldValue.serverTimestamp(),
        });
      }
    }

    return cls;
  }

  // ---------------------------------------------------------------------------
  // Stream enrolled classes for a Student
  // ---------------------------------------------------------------------------
  Stream<List<ClassModel>> streamStudentClasses(
      String studentId, String studentName) {
    if (studentId.isEmpty) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(studentId)
        .collection('enrolled_classes')
        .snapshots()
        .asyncMap((snapshot) async {
      final List<ClassModel> result = [];
      for (final doc in snapshot.docs) {
        final classId = doc.id;
        try {
          final classDoc =
              await _firestore.collection('classes').doc(classId).get();
          if (classDoc.exists) {
            result.add(ClassModel.fromFirestore(classDoc));
          }
        } catch (_) {}
      }
      return result;
    }).handleError((error) {
      debugPrint('ClassService streamStudentClasses error: $error');
      return <ClassModel>[];
    });
  }

  // ---------------------------------------------------------------------------
  // Update a student's address, birthdate/age, name across all enrolled classes
  // ---------------------------------------------------------------------------
  Future<void> updateStudentProfileInEnrolledClasses({
    required String studentId,
    required String oldName,
    String? newName,
    String? address,
    DateTime? birthdate,
  }) async {
    if (studentId.isEmpty) return;
    try {
      final enrolledDocs = await _firestore
          .collection('users')
          .doc(studentId)
          .collection('enrolled_classes')
          .get();

      int calculatedAge = 0;
      if (birthdate != null) {
        final now = DateTime.now();
        calculatedAge = now.year - birthdate.year;
        if (now.month < birthdate.month ||
            (now.month == birthdate.month && now.day < birthdate.day)) {
          calculatedAge--;
        }
      }

      for (final doc in enrolledDocs.docs) {
        final classId = doc.id;
        final classDoc =
            await _firestore.collection('classes').doc(classId).get();
        if (!classDoc.exists) continue;
        final cls = ClassModel.fromFirestore(classDoc);
        final students = List<StudentData>.from(cls.students);
        final sIdx = students.indexWhere(
          (s) => s.name.toLowerCase() == oldName.toLowerCase(),
        );
        if (sIdx != -1) {
          final s = students[sIdx];
          students[sIdx] = s.copyWith(
            name: newName ?? s.name,
            address: address ?? s.address,
            age: calculatedAge > 0 ? calculatedAge : s.age,
            birthdate: birthdate ?? s.birthdate,
          );
          await updateStudents(classId, students);
        }
      }
    } catch (e) {
      debugPrint('updateStudentProfileInEnrolledClasses warning: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Clean up any previously seeded demo class if present
  // ---------------------------------------------------------------------------
  Future<void> cleanUpDemoData() async {
    try {
      final doc = await _firestore
          .collection('classes')
          .doc('regielou-class-1')
          .get();
      if (doc.exists) {
        await _firestore
            .collection('classes')
            .doc('regielou-class-1')
            .delete();
        debugPrint('Cleaned up demo class regielou-class-1');
      }
    } catch (e) {
      debugPrint('cleanUpDemoData error: $e');
    }
  }
}
