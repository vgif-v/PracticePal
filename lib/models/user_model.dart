import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { trainer, student }

class UserModel {
  final String uid;
  final UserRole role;
  final String fullName;
  final String address;
  final DateTime? birthdate;
  final String email;

  const UserModel({
    required this.uid,
    required this.role,
    required this.fullName,
    required this.address,
    this.birthdate,
    required this.email,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'role': role.name,
      'fullName': fullName,
      'address': address,
      'birthdate': birthdate != null ? Timestamp.fromDate(birthdate!) : null,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    DateTime? parsedBirthdate;
    final rawBirthdate = map['birthdate'];
    if (rawBirthdate != null) {
      if (rawBirthdate is Timestamp) {
        parsedBirthdate = rawBirthdate.toDate();
      } else if (rawBirthdate is String) {
        parsedBirthdate = DateTime.tryParse(rawBirthdate);
      } else if (rawBirthdate is int) {
        parsedBirthdate = DateTime.fromMillisecondsSinceEpoch(rawBirthdate);
      }
    }

    return UserModel(
      uid: uid,
      role: map['role'] == 'trainer' ? UserRole.trainer : UserRole.student,
      fullName: map['fullName'] ?? '',
      address: map['address'] ?? '',
      birthdate: parsedBirthdate,
      email: map['email'] ?? '',
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data, doc.id);
  }
}
