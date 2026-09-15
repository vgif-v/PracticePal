import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'theme/theme.dart';
import 'screens/login_register_screen.dart';
import 'screens/trainer_dashboard_screen.dart';
import 'screens/student_dashboard_screen.dart';
import 'screens/student_tracking_screen.dart';
import 'screens/complete_profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const PracticePalApp());
}

class PracticePalApp extends StatelessWidget {
  const PracticePalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PracticePal',
      debugShowCheckedModeBanner: false,
      theme: KineticTheme.light,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginRegisterScreen(),
        '/trainer': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          final user = FirebaseAuth.instance.currentUser;
          return TrainerDashboardScreen(
            trainerName: args?['name'] ?? user?.displayName ?? user?.email ?? 'Trainer',
            trainerId: args?['uid'] ?? user?.uid ?? '',
          );
        },
        '/student': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          final user = FirebaseAuth.instance.currentUser;
          return StudentDashboardScreen(
            studentName: args?['name'] ?? user?.displayName ?? user?.email ?? 'Student',
            studentId: args?['uid'] ?? user?.uid ?? '',
          );
        },
        '/tracking': (context) => const StudentTrackingScreen(),
        '/complete-profile': (context) => const CompleteProfileScreen(),
      },
    );
  }
}
