import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'theme/theme.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
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
        '/': (context) => const AuthGate(),
        '/login': (context) => const LoginRegisterScreen(),
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

/// Listens to auth state changes so users stay logged in when closing and
/// reopening the app, only returning to login when explicitly signed out.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(color: KineticColors.coolBlue),
            ),
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const LoginRegisterScreen();
        }

        return FutureBuilder<UserModel?>(
          future: AuthService().getUserModel(user.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: CircularProgressIndicator(color: KineticColors.coolBlue),
                ),
              );
            }

            final userModel = userSnapshot.data;
            final role = userModel?.role ?? UserRole.student;
            final name = userModel?.fullName.isNotEmpty == true
                ? userModel!.fullName
                : (user.displayName ?? user.email?.split('@').first ?? 'User');

            if (role == UserRole.trainer) {
              return TrainerDashboardScreen(
                trainerName: name,
                trainerId: user.uid,
              );
            } else {
              return StudentDashboardScreen(
                studentName: name,
                studentId: user.uid,
              );
            }
          },
        );
      },
    );
  }
}
