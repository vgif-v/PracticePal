import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/theme.dart';
import '../services/auth_service.dart';
import '../services/class_service.dart';
import 'class_detail_screen.dart';

// ---------------------------------------------------------------------------
// Trainer Dashboard — responsive nav (bottom bar < 900, sidebar ≥ 900)
// ---------------------------------------------------------------------------
class TrainerDashboardScreen extends StatefulWidget {
  final String trainerName;
  final String trainerId;

  const TrainerDashboardScreen({
    super.key,
    required this.trainerName,
    this.trainerId = '',
  });

  @override
  State<TrainerDashboardScreen> createState() => _TrainerDashboardScreenState();
}

class _TrainerDashboardScreenState extends State<TrainerDashboardScreen> {
  final AuthService _authService = AuthService();
  final ClassService _classService = ClassService();
  int _navIndex = 0; // 0 = Classes, 1 = Profile

  late String _effectiveTrainerId;
  late String _effectiveTrainerName;
  List<ClassModel> _classes = [];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _effectiveTrainerId = widget.trainerId.isNotEmpty
        ? widget.trainerId
        : (user?.uid ?? '');
    _effectiveTrainerName = widget.trainerName.isNotEmpty
        ? widget.trainerName
        : (user?.displayName ?? user?.email?.split('@').first ?? 'Trainer');

    // Clean up any previously seeded demo class so only real classes appear
    _classService.cleanUpDemoData();
  }

  // -------------------------------------------------------------------------
  // UI Builder
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          body: Row(
            children: [
              // Desktop Sidebar
              if (isDesktop) _buildSidebar(),

              // Main content (StreamBuilder for real-time per-trainer classes)
              Expanded(
                child: StreamBuilder<List<ClassModel>>(
                  stream: _classService.streamTrainerClasses(
                    _effectiveTrainerId,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      _classes = snapshot.data!;
                    }

                    return IndexedStack(
                      index: _navIndex,
                      children: [_buildClassesTab(), _buildProfileTab()],
                    );
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: isDesktop ? null : _buildBottomNav(),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Navigation: Bottom Bar (Mobile)
  // -------------------------------------------------------------------------
  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _navIndex,
      onDestinationSelected: (i) => setState(() => _navIndex = i),
      backgroundColor: Colors.white,
      indicatorColor: KineticColors.coolBlue.withValues(alpha: 0.12),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.school_outlined),
          selectedIcon: Icon(
            Icons.school_rounded,
            color: KineticColors.coolBlue,
          ),
          label: 'My Classes',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(
            Icons.person_rounded,
            color: KineticColors.coolBlue,
          ),
          label: 'Profile',
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Navigation: Sidebar (Desktop / Tablet)
  // -------------------------------------------------------------------------
  Widget _buildSidebar() {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: KineticColors.coolBorder, width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(KineticSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(KineticRadii.sm),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(KineticRadii.sm),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PracticePal',
                        style: KineticTypography.titleMd.copyWith(
                          color: KineticColors.coolDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Trainer Studio',
                        style: KineticTypography.labelSm.copyWith(
                          color: KineticColors.coolMutedText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          const SizedBox(height: KineticSpacing.md),

          // Nav items
          _buildSidebarItem(
            index: 0,
            icon: Icons.school_rounded,
            label: 'My Classes',
          ),
          _buildSidebarItem(
            index: 1,
            icon: Icons.person_rounded,
            label: 'Profile & Settings',
          ),

          const Spacer(),

          // Trainer Info Card
          Padding(
            padding: const EdgeInsets.all(KineticSpacing.md),
            child: Container(
              padding: const EdgeInsets.all(KineticSpacing.md),
              decoration: BoxDecoration(
                color: KineticColors.coolInputBg,
                borderRadius: BorderRadius.circular(KineticRadii.md),
                border: Border.all(color: KineticColors.coolBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: KineticColors.coolBlue.withValues(
                      alpha: 0.15,
                    ),
                    child: Text(
                      _effectiveTrainerName.isNotEmpty
                          ? _effectiveTrainerName[0].toUpperCase()
                          : 'T',
                      style: const TextStyle(
                        color: KineticColors.coolBlue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _effectiveTrainerName,
                      style: KineticTypography.titleMd.copyWith(
                        color: KineticColors.coolDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _navIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KineticSpacing.sm,
        vertical: 2,
      ),
      child: Material(
        color: isSelected
            ? KineticColors.coolBlue.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(KineticRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(KineticRadii.md),
          onTap: () => setState(() => _navIndex = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? KineticColors.coolBlue
                      : KineticColors.coolMutedText,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: KineticTypography.titleMd.copyWith(
                    color: isSelected
                        ? KineticColors.coolBlue
                        : KineticColors.coolDark,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // CLASSES TAB
  // -------------------------------------------------------------------------
  Widget _buildClassesTab() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // AppBar section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: KineticSpacing.gutter,
              vertical: KineticSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  padding: const EdgeInsets.all(3),
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: KineticColors.coolBorder.withValues(alpha: 0.8),
                      width: 1,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _effectiveTrainerName,
                        style: KineticTypography.headlineSm.copyWith(
                          color: KineticColors.coolDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Trainer Dashboard',
                        style: KineticTypography.bodySm.copyWith(
                          color: KineticColors.coolMutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Add Class button (Cool dark styling)
                ElevatedButton.icon(
                  onPressed: _openAddClassDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KineticColors.coolDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KineticRadii.full),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Add Class',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Class summary
          _buildClassSummaryBar(),

          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KineticSpacing.gutter,
              vertical: KineticSpacing.sm,
            ),
            child: Text(
              'My Classes (${_classes.length})',
              style: KineticTypography.titleMd.copyWith(
                color: KineticColors.coolDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          // Class list or Empty State
          Expanded(
            child: _classes.isEmpty
                ? _buildEmptyClassesView()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KineticSpacing.gutter,
                      vertical: 4,
                    ),
                    itemCount: _classes.length,
                    itemBuilder: (context, index) {
                      return _buildClassCard(_classes[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyClassesView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KineticSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: KineticColors.coolBlue.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.school_outlined,
                size: 40,
                color: KineticColors.coolBlue,
              ),
            ),
            const SizedBox(height: KineticSpacing.md),
            Text(
              'No Classes Yet',
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
                'Each trainer has their own private classes. Tap below to create your first class and get your unique student join code!',
                textAlign: TextAlign.center,
                style: KineticTypography.bodySm.copyWith(
                  color: KineticColors.coolMutedText,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: KineticSpacing.lg),
            ElevatedButton.icon(
              onPressed: _openAddClassDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: KineticColors.coolDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KineticRadii.full),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Create New Class',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassSummaryBar() {
    final totalStudents = _classes.fold<int>(
      0,
      (sum, c) => sum + c.students.length,
    );
    final totalCompleted = _classes.fold<int>(
      0,
      (sum, c) =>
          sum +
          c.students.fold<int>(
            0,
            (s, st) => s + st.sessions.where((x) => x.isCompleted).length,
          ),
    );

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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            label: 'Classes',
            value: '${_classes.length}',
            icon: Icons.school_rounded,
            iconColor: KineticColors.coolBlueLight,
          ),
          Container(
            height: 36,
            width: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          _buildStatItem(
            label: 'Total Students',
            value: '$totalStudents',
            icon: Icons.groups_rounded,
            iconColor: KineticColors.neonTeal,
          ),
          Container(
            height: 36,
            width: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          _buildStatItem(
            label: 'Stars Earned',
            value: '$totalCompleted',
            icon: Icons.star_rounded,
            iconColor: KineticColors.sunnyGold,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: KineticTypography.headlineSm.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: KineticTypography.labelSm.copyWith(
            color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildClassCard(ClassModel trainerClass) {
    final studentCount = trainerClass.students.length;
    final totalStars = trainerClass.students.fold<int>(
      0,
      (sum, s) => sum + s.sessions.where((x) => x.isCompleted).length,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: KineticSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(KineticRadii.md),
        boxShadow: KineticShadows.level1,
        border: Border.all(color: KineticColors.coolBorder, width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(KineticRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(KineticRadii.md),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClassDetailScreen(
                  classId: trainerClass.id,
                  className: trainerClass.name,
                  joinCode: trainerClass.joinCode,
                  trainerName: _effectiveTrainerName,
                  trainerId: _effectiveTrainerId,
                  students: trainerClass.students,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(KineticSpacing.md),
            child: Row(
              children: [
                // Class icon badge
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: KineticColors.coolBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(KineticRadii.dflt),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: KineticColors.coolBlue,
                    size: 26,
                  ),
                ),
                const SizedBox(width: KineticSpacing.md),

                // Class info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trainerClass.name,
                        style: KineticTypography.titleMd.copyWith(
                          color: KineticColors.coolDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildChip(
                            icon: Icons.groups_rounded,
                            label: '$studentCount students',
                            color: KineticColors.secondary,
                          ),
                          _buildChip(
                            icon: Icons.star_rounded,
                            label: '$totalStars stars',
                            color: KineticColors.sunnyGold,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Join code pill
                Flexible(
                  child: GestureDetector(
                    onTap: () => _copyJoinCode(trainerClass.joinCode),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: KineticColors.coolInputBg,
                        borderRadius: BorderRadius.circular(KineticRadii.full),
                        border: Border.all(
                          color: KineticColors.coolBorder,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.key_rounded,
                            size: 12,
                            color: KineticColors.sunnyGold,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              trainerClass.joinCode,
                              style: KineticTypography.labelSm.copyWith(
                                color: KineticColors.coolDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.copy_rounded,
                            size: 11,
                            color: KineticColors.coolMutedText,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: KineticColors.coolMutedText,
                  ),
                  tooltip: 'Delete class',
                  onPressed: () => _confirmDeleteClass(trainerClass),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: KineticColors.coolBorder,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteClass(ClassModel cls) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text('Are you sure you want to delete "${cls.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _classService.deleteClass(cls.id);
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text('Class "${cls.name}" deleted.'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text('Failed to delete class: $e'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      }
    }
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KineticRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: KineticTypography.labelSm.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  void _copyJoinCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Join code $code copied!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: KineticColors.coolDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KineticRadii.dflt),
          ),
        ),
      );
  }

  // -------------------------------------------------------------------------
  // Add Class Dialog — saves directly to Firestore under this trainer
  // -------------------------------------------------------------------------
  void _openAddClassDialog() {
    final nameCtrl = TextEditingController();
    final scheduleCtrl = TextEditingController(text: 'Tues & Thu • 4:30 PM');
    final roomCtrl = TextEditingController(text: 'Main Studio');
    final paymentCtrl = TextEditingController(text: '1,500');

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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: KineticColors.coolBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(KineticRadii.sm),
                ),
                child: const Icon(
                  Icons.add_circle_rounded,
                  color: KineticColors.coolBlue,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Create New Class',
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
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Class Name',
                  hintText: 'e.g. Hip Hop Routine 1',
                  fillColor: KineticColors.coolInputBg,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KineticRadii.dflt),
                    borderSide: const BorderSide(
                      color: KineticColors.coolBorder,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: KineticSpacing.md),
              TextField(
                controller: scheduleCtrl,
                decoration: InputDecoration(
                  labelText: 'Schedule (Optional)',
                  hintText: 'e.g. Saturdays • 10:00 AM',
                  fillColor: KineticColors.coolInputBg,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KineticRadii.dflt),
                    borderSide: const BorderSide(
                      color: KineticColors.coolBorder,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: KineticSpacing.md),
              TextField(
                controller: roomCtrl,
                decoration: InputDecoration(
                  labelText: 'Studio / Room (Optional)',
                  hintText: 'e.g. Studio A',
                  fillColor: KineticColors.coolInputBg,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KineticRadii.dflt),
                    borderSide: const BorderSide(
                      color: KineticColors.coolBorder,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: KineticSpacing.md),
              TextField(
                controller: paymentCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Default Payment Amount',
                  hintText: 'e.g. 1500',
                  prefixText: '₱ ',
                  prefixStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: KineticColors.coolDark,
                  ),
                  fillColor: KineticColors.coolInputBg,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KineticRadii.dflt),
                    borderSide: const BorderSide(
                      color: KineticColors.coolBorder,
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
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(ctx);
                  try {
                    await _classService.createClass(
                      name: name,
                      trainerId: _effectiveTrainerId,
                      trainerName: _effectiveTrainerName,
                      schedule: scheduleCtrl.text.trim().isNotEmpty
                          ? scheduleCtrl.text.trim()
                          : 'Flexible Schedule',
                      room: roomCtrl.text.trim().isNotEmpty
                          ? roomCtrl.text.trim()
                          : 'Main Studio',
                      defaultPaymentAmount: paymentCtrl.text.trim().isNotEmpty
                          ? paymentCtrl.text.trim()
                          : '₱0',
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          SnackBar(
                            content: Text('Class "$name" created successfully!'),
                            backgroundColor: KineticColors.secondary,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          SnackBar(
                            content: Text('Error creating class: $e'),
                            backgroundColor: KineticColors.error,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
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
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // PROFILE TAB
  // -------------------------------------------------------------------------
  Widget _buildProfileTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KineticSpacing.gutter),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: KineticSpacing.lg),
              // Profile header
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: KineticColors.coolBlue.withValues(
                        alpha: 0.15,
                      ),
                      child: Text(
                        _effectiveTrainerName
                            .split(' ')
                            .map((e) => e.isNotEmpty ? e[0] : '')
                            .take(2)
                            .join(),
                        style: KineticTypography.headlineLg.copyWith(
                          color: KineticColors.coolBlue,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: KineticSpacing.md),
                    Text(
                      _effectiveTrainerName,
                      style: KineticTypography.headlineMd.copyWith(
                        color: KineticColors.coolDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: KineticColors.coolBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(KineticRadii.full),
                      ),
                      child: Text(
                        'Trainer',
                        style: KineticTypography.labelMd.copyWith(
                          color: KineticColors.coolBlue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KineticSpacing.xl),

              // Profile info card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(KineticRadii.md),
                  boxShadow: KineticShadows.level1,
                  border: Border.all(color: KineticColors.coolBorder),
                ),
                child: Column(
                  children: [
                    _buildProfileItem(
                      icon: Icons.school_rounded,
                      label: 'Total Classes',
                      value: '${_classes.length}',
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildProfileItem(
                      icon: Icons.groups_rounded,
                      label: 'Total Students',
                      value:
                          '${_classes.fold<int>(0, (sum, c) => sum + c.students.length)}',
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildProfileItem(
                      icon: Icons.email_rounded,
                      label: 'Email',
                      value: _authService.currentUser?.email ?? 'Not signed in',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: KineticSpacing.xl),

              // Settings section
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(KineticRadii.md),
                  boxShadow: KineticShadows.level1,
                  border: Border.all(color: KineticColors.coolBorder),
                ),
                child: Column(
                  children: [
                    _buildProfileAction(
                      icon: Icons.logout_rounded,
                      label: 'Log Out',
                      isDestructive: true,
                      onTap: () async {
                        await _authService.signOut();
                        if (!mounted) return;
                        Navigator.pushNamedAndRemoveUntil(
                            context, '/', (route) => false);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KineticSpacing.md,
        vertical: KineticSpacing.sm + 4,
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: KineticColors.coolMutedText),
          const SizedBox(width: KineticSpacing.md),
          Expanded(
            child: Text(
              label,
              style: KineticTypography.bodyMd.copyWith(
                color: KineticColors.coolMutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: KineticTypography.titleMd.copyWith(
                color: KineticColors.coolDark,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KineticSpacing.md,
            vertical: KineticSpacing.sm + 4,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: isDestructive
                    ? KineticColors.error
                    : KineticColors.coolMutedText,
              ),
              const SizedBox(width: KineticSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: KineticTypography.bodyMd.copyWith(
                    color: isDestructive
                        ? KineticColors.error
                        : KineticColors.coolDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDestructive
                    ? KineticColors.error
                    : KineticColors.coolBorder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
