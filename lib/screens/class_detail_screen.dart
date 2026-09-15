import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/theme.dart';
import '../models/student.dart';
import 'student_tracking_screen.dart';

class ClassDetailScreen extends StatefulWidget {
  final String className;
  final String joinCode;
  final String trainerName;
  final List<StudentData> students;

  const ClassDetailScreen({
    super.key,
    required this.className,
    required this.joinCode,
    required this.trainerName,
    required this.students,
  });

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  late List<StudentData> _studentList;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _studentList = List.from(widget.students);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<StudentData> get _filteredStudents {
    if (_searchQuery.isEmpty) return _studentList;
    return _studentList.where((s) {
      return s.name.toLowerCase().contains(_searchQuery) ||
          s.address.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  void _copyJoinCode() {
    Clipboard.setData(ClipboardData(text: widget.joinCode));
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Join code "${widget.joinCode}" copied to clipboard!',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: KineticColors.deepSlate,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KineticRadii.dflt),
        ),
      ),
    );
  }

  int _getCompletedSessions(StudentData student) {
    return student.sessions.where((s) => s.isCompleted).length;
  }

  bool _hasUnpaidTuition(StudentData student) {
    return student.payments.any((p) => !p.isPaid);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredStudents;
    final totalStars = _studentList.fold<int>(
      0,
      (sum, s) => sum + _getCompletedSessions(s),
    );
    final unpaidCount = _studentList.where(_hasUnpaidTuition).length;

    return Scaffold(
      backgroundColor: KineticColors.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: KineticColors.surfaceContainerLowest,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: KineticColors.deepSlate,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.className,
          style: KineticTypography.headlineSm.copyWith(
            fontWeight: FontWeight.w800,
            color: KineticColors.deepSlate,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: KineticSpacing.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(KineticRadii.full),
              onTap: _copyJoinCode,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: KineticColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(KineticRadii.full),
                  border: Border.all(
                    color: KineticColors.surfaceContainerHighest,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.key_rounded,
                      size: 14,
                      color: KineticColors.sunnyGold,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.joinCode,
                      style: KineticTypography.labelSm.copyWith(
                        fontWeight: FontWeight.w800,
                        color: KineticColors.deepSlate,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.copy_rounded,
                      size: 13,
                      color: KineticColors.outline,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header stats banner
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KineticSpacing.lg,
                vertical: KineticSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Students',
                      value: '${_studentList.length}',
                      icon: Icons.people_alt_rounded,
                      color: KineticColors.secondary,
                    ),
                  ),
                  const SizedBox(width: KineticSpacing.sm),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Stars Earned',
                      value: '$totalStars',
                      icon: Icons.star_rounded,
                      color: KineticColors.sunnyGold,
                    ),
                  ),
                  const SizedBox(width: KineticSpacing.sm),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Pending Pay',
                      value: '$unpaidCount',
                      icon: Icons.payment_rounded,
                      color: unpaidCount > 0
                          ? KineticColors.electricCoral
                          : KineticColors.secondary,
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KineticSpacing.lg,
                vertical: KineticSpacing.sm,
              ),
              child: TextField(
                controller: _searchController,
                style: KineticTypography.bodyMd.copyWith(
                  color: KineticColors.deepSlate,
                ),
                decoration: InputDecoration(
                  hintText: 'Search student or address...',
                  hintStyle: KineticTypography.bodyMd.copyWith(
                    color: KineticColors.outline,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: KineticColors.outline,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: KineticColors.surfaceContainerLow,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: KineticSpacing.md,
                    vertical: KineticSpacing.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KineticRadii.md),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Students count header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KineticSpacing.lg,
                vertical: KineticSpacing.xs,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Enrolled Students (${filtered.length})',
                    style: KineticTypography.labelLg.copyWith(
                      color: KineticColors.deepSlate,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Tap to view tracking',
                    style: KineticTypography.labelSm.copyWith(
                      color: KineticColors.outline,
                    ),
                  ),
                ],
              ),
            ),

            // Student list
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search_rounded,
                            size: 48,
                            color: KineticColors.outlineVariant,
                          ),
                          const SizedBox(height: KineticSpacing.sm),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No students enrolled yet.'
                                : 'No students found matching "$_searchQuery"',
                            style: KineticTypography.bodyMd.copyWith(
                              color: KineticColors.outline,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KineticSpacing.lg,
                        vertical: KineticSpacing.sm,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: KineticSpacing.sm),
                      itemBuilder: (context, index) {
                        final student = filtered[index];
                        return _buildStudentCard(student);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KineticSpacing.sm,
        vertical: KineticSpacing.md,
      ),
      decoration: BoxDecoration(
        color: KineticColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(KineticRadii.md),
        border: Border.all(
          color: KineticColors.surfaceContainerHighest,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: KineticTypography.titleMd.copyWith(
              fontWeight: FontWeight.w800,
              color: KineticColors.deepSlate,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: KineticTypography.labelSm.copyWith(
              color: KineticColors.outline,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(StudentData student) {
    final completed = _getCompletedSessions(student);
    final total = student.sessions.length;
    final hasUnpaid = _hasUnpaidTuition(student);

    return Container(
      decoration: BoxDecoration(
        color: KineticColors.surface,
        borderRadius: BorderRadius.circular(KineticRadii.md),
        boxShadow: KineticShadows.level1,
        border: Border.all(
          color: KineticColors.surfaceContainerHighest.withValues(alpha: 0.6),
          width: 1,
        ),
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
                builder: (_) => StudentTrackingScreen(student: student),
              ),
            );
            if (mounted) setState(() {});
          },
          child: Padding(
            padding: const EdgeInsets.all(KineticSpacing.md),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: KineticColors.secondary.withValues(
                    alpha: 0.15,
                  ),
                  child: Text(
                    student.name.isNotEmpty
                        ? student.name.substring(0, 1).toUpperCase()
                        : '?',
                    style: KineticTypography.titleMd.copyWith(
                      color: KineticColors.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: KineticSpacing.md),

                // Name & details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              student.name,
                              style: KineticTypography.titleMd.copyWith(
                                fontWeight: FontWeight.w700,
                                color: KineticColors.deepSlate,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: KineticColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(
                                KineticRadii.sm,
                              ),
                            ),
                            child: Text(
                              'Age ${student.age}',
                              style: KineticTypography.labelSm.copyWith(
                                color: KineticColors.outline,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        student.address,
                        style: KineticTypography.bodySm.copyWith(
                          color: KineticColors.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // Badges
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // Cycle badge
                          _buildMiniBadge(
                            icon: Icons.sync_rounded,
                            label: 'Cycle #${student.cycleNumber}',
                            color: KineticColors.secondary,
                          ),
                          // Star badge
                          _buildMiniBadge(
                            icon: Icons.star_rounded,
                            label: '$completed/$total stars',
                            color: KineticColors.sunnyGold,
                          ),
                          // Payment badge
                          _buildMiniBadge(
                            icon: hasUnpaid
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline_rounded,
                            label: hasUnpaid ? 'Payment Due' : 'Paid',
                            color: hasUnpaid
                                ? KineticColors.electricCoral
                                : KineticColors.secondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: KineticColors.outlineVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBadge({
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
          Icon(icon, size: 11, color: color),
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
}
