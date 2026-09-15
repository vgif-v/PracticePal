import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/theme.dart';
import 'student_tracking_screen.dart';
import '../models/student.dart';
import '../services/class_service.dart';

class StudentDashboardScreen extends StatefulWidget {
  final String studentName;
  final String studentId;

  const StudentDashboardScreen({
    super.key,
    required this.studentName,
    this.studentId = '',
  });

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final ClassService _classService = ClassService();
  late String _effectiveStudentId;
  late String _effectiveStudentName;
  List<ClassModel> _classes = [];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _effectiveStudentId = widget.studentId.isNotEmpty
        ? widget.studentId
        : (user?.uid ?? '');
    _effectiveStudentName = widget.studentName.isNotEmpty
        ? widget.studentName
        : (user?.displayName ?? user?.email?.split('@').first ?? 'Student');
  }

  void _openJoinClassDialog() {
    final codeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KineticRadii.lg),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: KineticColors.coolBlue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  color: KineticColors.coolBlue,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Join a Class',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: KineticColors.coolDark,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the private class code provided by your trainer or studio.',
                style: KineticTypography.bodySm.copyWith(
                  color: KineticColors.coolMutedText,
                ),
              ),
              const SizedBox(height: KineticSpacing.md),
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Class Join Code',
                  hintText: 'e.g. PP-9421',
                  prefixIcon: const Icon(
                    Icons.vpn_key_rounded,
                    color: KineticColors.sunnyGold,
                  ),
                  fillColor: KineticColors.coolInputBg,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KineticRadii.dflt),
                    borderSide: const BorderSide(color: KineticColors.coolBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KineticRadii.dflt),
                    borderSide: const BorderSide(
                      color: KineticColors.coolBlue,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = codeCtrl.text.trim().toUpperCase();
                if (code.isNotEmpty) {
                  Navigator.pop(ctx);
                  try {
                    final joined = await _classService.joinClassByCode(
                      joinCode: code,
                      studentId: _effectiveStudentId,
                      studentName: _effectiveStudentName,
                    );

                    if (!mounted) return;

                    if (joined != null) {
                      setState(() {
                        // Add locally if not already present
                        if (!_classes.any((c) => c.id == joined.id)) {
                          _classes.insert(0, joined);
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(
                                Icons.celebration_rounded,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Joined "${joined.name}" successfully!',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: KineticColors.secondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(KineticRadii.dflt),
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'No class found with that code. Please check with your trainer.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: KineticColors.coolDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(KineticRadii.dflt),
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error joining class: $e'),
                          backgroundColor: KineticColors.error,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: KineticColors.coolDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KineticRadii.full),
                ),
              ),
              child: const Text(
                'Join Class',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToTracking(ClassModel classModel) {
    // Find this student's data in the class, or create default for them
    final studentData = classModel.students.firstWhere(
      (s) => s.name.toLowerCase() == _effectiveStudentName.toLowerCase(),
      orElse: () => StudentData(
        name: _effectiveStudentName,
        age: 14,
        address: '',
        trainerName: classModel.trainerName,
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
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentTrackingScreen(student: studentData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KineticColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: KineticSpacing.gutter,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: KineticColors.coolBlue.withValues(alpha: 0.15),
              child: const Icon(
                Icons.person_rounded,
                size: 20,
                color: KineticColors.coolBlue,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, $_effectiveStudentName 👋',
                  style: KineticTypography.headlineSm.copyWith(
                    color: KineticColors.coolDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                Text(
                  'Student Dashboard',
                  style: KineticTypography.bodySm.copyWith(
                    color: KineticColors.coolMutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: KineticColors.coolDark,
            ),
            onPressed: () async {
              final nav = Navigator.of(context);
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              nav.pushReplacementNamed('/');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<ClassModel>>(
        stream: _classService.streamStudentClasses(_effectiveStudentId, _effectiveStudentName),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _classes = snapshot.data!;
          }

          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Motivational Banner
                _buildMotivationalBanner(),

                // Section Title & Join Button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KineticSpacing.gutter,
                    vertical: KineticSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Joined Classes (${_classes.length})',
                        style: KineticTypography.titleMd.copyWith(
                          color: KineticColors.coolDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      InkWell(
                        onTap: _openJoinClassDialog,
                        borderRadius: BorderRadius.circular(KineticRadii.sm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 16,
                                color: KineticColors.coolBlue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Enter Code',
                                style: KineticTypography.labelSm.copyWith(
                                  color: KineticColors.coolBlue,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Classes or Empty State
                Expanded(
                  child: _classes.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: KineticSpacing.gutter,
                            vertical: 4,
                          ),
                          itemCount: _classes.length,
                          itemBuilder: (context, index) {
                            final cls = _classes[index];
                            return _buildClassCard(cls);
                          },
                        ),
                ),

                // Join Button at bottom
                Padding(
                  padding: const EdgeInsets.all(KineticSpacing.gutter),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(KineticRadii.full),
                      boxShadow: KineticShadows.coolDarkPop,
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _openJoinClassDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KineticColors.coolDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(KineticRadii.full),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 22),
                      label: const Text(
                        'Join Class with Private Code',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KineticSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: KineticColors.coolBlue.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.school_outlined,
                size: 38,
                color: KineticColors.coolBlue,
              ),
            ),
            const SizedBox(height: KineticSpacing.md),
            Text(
              'No Classes Joined Yet',
              style: KineticTypography.titleMd.copyWith(
                color: KineticColors.coolDark,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                'Enter the private code from your trainer (e.g. PP-XXXX) to join their class and track your stars!',
                textAlign: TextAlign.center,
                style: KineticTypography.bodySm.copyWith(
                  color: KineticColors.coolMutedText,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: KineticSpacing.lg),
            ElevatedButton.icon(
              onPressed: _openJoinClassDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: KineticColors.coolDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KineticRadii.full),
                ),
              ),
              icon: const Icon(Icons.vpn_key_rounded, size: 18),
              label: const Text(
                'Enter Join Code',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMotivationalBanner() {
    int totalStars = 0;
    for (final c in _classes) {
      final student = c.students.firstWhere(
        (s) => s.name.toLowerCase() == _effectiveStudentName.toLowerCase(),
        orElse: () => StudentData(
          name: '',
          age: 0,
          address: '',
          trainerName: '',
          cycleNumber: 1,
          sessions: [],
          payments: [],
        ),
      );
      totalStars += student.sessions.where((s) => s.isCompleted).length;
    }

    return Container(
      margin: const EdgeInsets.all(KineticSpacing.gutter),
      padding: const EdgeInsets.all(KineticSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(KineticRadii.md),
        boxShadow: KineticShadows.level2,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star_rounded,
              color: KineticColors.sunnyGold,
              size: 34,
            ),
          ),
          const SizedBox(width: KineticSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalStars Total Stars Collected! 🌟',
                  style: KineticTypography.titleMd.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Keep practicing! Consistency creates champions.',
                  style: KineticTypography.bodySm.copyWith(
                    color: const Color(0xFFCBD5E1),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(ClassModel classModel) {
    final student = classModel.students.firstWhere(
      (s) => s.name.toLowerCase() == _effectiveStudentName.toLowerCase(),
      orElse: () => StudentData(
        name: _effectiveStudentName,
        age: 14,
        address: '',
        trainerName: classModel.trainerName,
        cycleNumber: 1,
        sessions: [],
        payments: [],
      ),
    );

    final completed = student.sessions.where((s) => s.isCompleted).length;
    final total = student.sessions.isNotEmpty ? student.sessions.length : 8;
    final progress = (completed / total).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: KineticSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(KineticRadii.md),
        boxShadow: KineticShadows.level1,
        border: Border.all(
          color: KineticColors.coolBorder,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(KineticRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(KineticRadii.md),
          onTap: () => _navigateToTracking(classModel),
          child: Padding(
            padding: const EdgeInsets.all(KineticSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: KineticColors.coolBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(KineticRadii.dflt),
                      ),
                      child: const Icon(
                        Icons.sports_gymnastics_rounded,
                        color: KineticColors.coolBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: KineticSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            classModel.name,
                            style: KineticTypography.titleMd.copyWith(
                              color: KineticColors.coolDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 14,
                                color: KineticColors.coolMutedText,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                classModel.trainerName,
                                style: KineticTypography.bodySm.copyWith(
                                  color: KineticColors.coolMutedText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: KineticColors.coolInputBg,
                        borderRadius: BorderRadius.circular(KineticRadii.sm),
                        border: Border.all(color: KineticColors.coolBorder),
                      ),
                      child: Text(
                        classModel.joinCode,
                        style: KineticTypography.labelSm.copyWith(
                          color: KineticColors.coolDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KineticSpacing.md),

                // Schedule & Location Pills
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: KineticColors.coolInputBg,
                        borderRadius: BorderRadius.circular(KineticRadii.sm),
                        border: Border.all(color: KineticColors.coolBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: KineticColors.coolMutedText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            classModel.schedule,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: KineticColors.coolDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        classModel.room,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KineticTypography.labelSm.copyWith(
                          color: KineticColors.coolMutedText,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: KineticSpacing.sm),

                // Progress Bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(KineticRadii.full),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: KineticColors.coolInputBg,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            KineticColors.coolBlue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$completed/$total Sessions',
                      style: KineticTypography.labelSm.copyWith(
                        color: KineticColors.coolDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
