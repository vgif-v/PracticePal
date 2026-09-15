import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/student.dart';

class ClassModel {
  final String id;
  final String name;
  final String joinCode;
  final String trainerId;
  final String trainerName;
  final String schedule;
  final String room;
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
      students: rawStudents
          .map((s) => StudentData.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class ClassService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Stream trainer's own classes — NEVER shared with any other trainer
  // ---------------------------------------------------------------------------
  Stream<List<ClassModel>> streamTrainerClasses(String trainerId) {
    if (trainerId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('classes')
        .where('trainerId', isEqualTo: trainerId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ClassModel.fromFirestore(doc)).toList();
    }).handleError((error) {
      debugPrint('ClassService streamTrainerClasses error: $error');
      return <ClassModel>[];
    });
  }

  // ---------------------------------------------------------------------------
  // Create a new class under this trainer
  // ---------------------------------------------------------------------------
  Future<String> createClass({
    required String name,
    required String trainerId,
    required String trainerName,
    String schedule = 'Flexible Schedule',
    String room = 'Main Studio',
  }) async {
    final randomDigits = 1000 + Random().nextInt(9000);
    final joinCode = 'PP-$randomDigits';

    final docRef = await _firestore.collection('classes').add({
      'name': name,
      'joinCode': joinCode,
      'trainerId': trainerId,
      'trainerName': trainerName,
      'schedule': schedule,
      'room': room,
      'studentCount': 0,
      'students': [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  // ---------------------------------------------------------------------------
  // Delete class
  // ---------------------------------------------------------------------------
  Future<void> deleteClass(String classId) async {
    await _firestore.collection('classes').doc(classId).delete();
  }

  // ---------------------------------------------------------------------------
  // Update students array in class
  // ---------------------------------------------------------------------------
  Future<void> updateStudents(String classId, List<StudentData> students) async {
    await _firestore.collection('classes').doc(classId).update({
      'students': students.map((s) => s.toMap()).toList(),
      'studentCount': students.length,
    });
  }

  // ---------------------------------------------------------------------------
  // Join a class by code (for Students)
  // ---------------------------------------------------------------------------
  Future<ClassModel?> joinClassByCode({
    required String joinCode,
    required String studentId,
    required String studentName,
    String address = '',
    int age = 14,
  }) async {
    final normalizedCode = joinCode.trim().toUpperCase();
    final query = await _firestore
        .collection('classes')
        .where('joinCode', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    final doc = query.docs.first;
    final cls = ClassModel.fromFirestore(doc);

    // Check if student is already in the class
    final existingIndex = cls.students.indexWhere((s) => s.name.toLowerCase() == studentName.toLowerCase());
    if (existingIndex == -1) {
      final newStudent = StudentData(
        name: studentName,
        age: age,
        address: address,
        trainerName: cls.trainerName,
        cycleNumber: 1,
        sessions: [
          SessionItem(date: 'Session 1', isCompleted: false),
          SessionItem(date: 'Session 2', isCompleted: false),
          SessionItem(date: 'Session 3', isCompleted: false),
          SessionItem(date: 'Session 4', isCompleted: false),
          SessionItem(date: 'Session 5', isCompleted: false),
          SessionItem(date: 'Session 6', isCompleted: false),
          SessionItem(date: 'Session 7', isCompleted: false),
          SessionItem(date: 'Session 8', isCompleted: false),
        ],
        payments: const [
          PaymentDueItem(
            label: 'Cycle #1 Tuition',
            amount: '\$140',
            dueDate: 'Upcoming',
            dueSessionNumber: 2,
            isPaid: false,
          ),
        ],
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
  Stream<List<ClassModel>> streamStudentClasses(String studentId, String studentName) {
    if (studentId.isEmpty) {
      return Stream.value([]);
    }

    // Read from student's enrolled_classes subcollection
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
          final classDoc = await _firestore.collection('classes').doc(classId).get();
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
}
