import 'package:flutter/material.dart';

class EnrolledClass {
  final String id;
  final String name;
  final String trainerName;
  final String trainerId;
  final String schedule;
  final String room;
  final String joinCode;
  final int completedSessions;
  final int totalSessions;
  final int cycleNumber;
  final int studentCount;
  final Color primaryAccent;
  final IconData icon;

  const EnrolledClass({
    required this.id,
    required this.name,
    required this.trainerName,
    this.trainerId = '',
    required this.schedule,
    required this.room,
    this.joinCode = '',
    required this.completedSessions,
    required this.totalSessions,
    required this.cycleNumber,
    this.studentCount = 0,
    required this.primaryAccent,
    required this.icon,
  });
}
