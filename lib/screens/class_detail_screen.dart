import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/theme.dart';
import '../models/student.dart';
import '../services/class_service.dart';
import 'student_tracking_screen.dart';

class ClassDetailScreen extends StatefulWidget {
  final String classId;
  final String className;
  final String joinCode;
  final String trainerName;
  final String trainerId; // current user's uid — used to determine trainer view
  final List<StudentData> students;

  const ClassDetailScreen({
    super.key,
    this.classId = '',
    required this.className,
    required this.joinCode,
    required this.trainerName,
    this.trainerId = '',
    required this.students,
  });

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  final ClassService _classService = ClassService();
  final TextEditingController _searchController = TextEditingController();
  late List<StudentData> _studentList;
  String _searchQuery = '';
  bool _isSaving = false;

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

  void _showBanner(String message, {bool isSuccess = true, bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? KineticColors.error
              : (isSuccess ? KineticColors.secondary : KineticColors.deepSlate),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KineticRadii.dflt),
          ),
        ),
      );
  }

  void _copyJoinCode() {
    Clipboard.setData(ClipboardData(text: widget.joinCode));
    _showBanner('Join code "${widget.joinCode}" copied to clipboard!');
  }

  int _getCompletedSessions(StudentData student) {
    return student.sessions.where((s) => s.isCompleted).length;
  }

  bool _hasUnpaidTuition(StudentData student) {
    return student.payments.any((p) => !p.isPaid);
  }

  // ---------------------------------------------------------------------------
  // Add Student Dialog (manual enrollment)
  // ---------------------------------------------------------------------------
  Future<void> _openAddStudentDialog() async {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    DateTime? selectedBirthdate;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KineticRadii.lg)),
            title: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: KineticColors.coolBlue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add_rounded,
                    color: KineticColors.coolBlue),
              ),
              const SizedBox(width: 10),
              const Text('Add Student',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: KineticColors.coolDark)),
            ]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Manually enroll a student. They can later link their account using the class join code.',
                    style: KineticTypography.bodySm
                        .copyWith(color: KineticColors.coolMutedText),
                  ),
                  const SizedBox(height: KineticSpacing.md),
                  _dialogField(nameCtrl, 'Full Name *', Icons.person_rounded),
                  const SizedBox(height: 10),
                  _dialogField(addressCtrl, 'Address', Icons.location_on_rounded),
                  const SizedBox(height: 10),
                  _dialogField(ageCtrl, 'Age', Icons.cake_rounded,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 10),
                  // Birthdate picker
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime(2010),
                        firstDate: DateTime(1980),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDlgState(() => selectedBirthdate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: KineticColors.coolInputBg,
                        borderRadius:
                            BorderRadius.circular(KineticRadii.dflt),
                        border: Border.all(color: KineticColors.coolBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              color: KineticColors.sunnyGold, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            selectedBirthdate != null
                                ? '${selectedBirthdate!.year}-${selectedBirthdate!.month.toString().padLeft(2, '0')}-${selectedBirthdate!.day.toString().padLeft(2, '0')}'
                                : 'Birthdate (optional)',
                            style: KineticTypography.bodyMd.copyWith(
                              color: selectedBirthdate != null
                                  ? KineticColors.coolDark
                                  : KineticColors.coolMutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: KineticColors.coolDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(KineticRadii.full))),
                child: const Text('Add Student',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          );
        });
      },
    );

    if (result != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      _showBanner('Please enter the student\'s name.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _classService.addManualStudent(
        classId: widget.classId,
        trainerName: widget.trainerName,
        studentName: name,
        address: addressCtrl.text.trim(),
        age: int.tryParse(ageCtrl.text.trim()) ?? 0,
        birthdate: selectedBirthdate,
      );

      // Refresh student list from Firestore
      final doc = await _classService.db
          .collection('classes')
          .doc(widget.classId)
          .get();
      final updatedClass = ClassModel.fromFirestore(doc);
      if (mounted) {
        setState(() => _studentList = List.from(updatedClass.students));
        _showBanner('$name added successfully!');
      }
    } catch (e) {
      _showBanner('Error adding student: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: KineticColors.coolBlue, size: 20),
        fillColor: KineticColors.coolInputBg,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KineticRadii.dflt),
          borderSide: const BorderSide(color: KineticColors.coolBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KineticRadii.dflt),
          borderSide:
              const BorderSide(color: KineticColors.coolBlue, width: 2),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredStudents;
    final totalStars = _studentList.fold<int>(
        0, (sum, s) => sum + _getCompletedSessions(s));
    final unpaidCount =
        _studentList.where(_hasUnpaidTuition).length;

    return Scaffold(
      backgroundColor: KineticColors.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: KineticColors.surfaceContainerLowest,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: KineticColors.deepSlate, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.className,
          style: KineticTypography.headlineSm.copyWith(
              fontWeight: FontWeight.w800, color: KineticColors.deepSlate),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Add Student button (trainer only)
          if (widget.trainerId.isNotEmpty && widget.classId.isNotEmpty)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.person_add_rounded,
                      color: KineticColors.coolBlue, size: 22),
              tooltip: 'Add Student',
              onPressed: _isSaving ? null : _openAddStudentDialog,
            ),
          Padding(
            padding: const EdgeInsets.only(right: KineticSpacing.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(KineticRadii.full),
              onTap: _copyJoinCode,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: KineticColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(KineticRadii.full),
                  border: Border.all(color: KineticColors.surfaceContainerHighest),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.key_rounded,
                        size: 14, color: KineticColors.sunnyGold),
                    const SizedBox(width: 4),
                    Text(
                      widget.joinCode,
                      style: KineticTypography.labelSm.copyWith(
                          fontWeight: FontWeight.w800,
                          color: KineticColors.deepSlate),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.copy_rounded,
                        size: 13, color: KineticColors.outline),
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
                  horizontal: KineticSpacing.lg, vertical: KineticSpacing.sm),
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
                  horizontal: KineticSpacing.lg, vertical: KineticSpacing.sm),
              child: TextField(
                controller: _searchController,
                style: KineticTypography.bodyMd
                    .copyWith(color: KineticColors.deepSlate),
                decoration: InputDecoration(
                  hintText: 'Search student or address...',
                  hintStyle: KineticTypography.bodyMd
                      .copyWith(color: KineticColors.outline),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: KineticColors.outline, size: 20),
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
                      vertical: KineticSpacing.sm),
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
                  horizontal: KineticSpacing.lg, vertical: KineticSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Enrolled Students (${filtered.length})',
                    style: KineticTypography.labelLg.copyWith(
                        color: KineticColors.deepSlate,
                        fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Tap to view tracking',
                    style: KineticTypography.labelSm
                        .copyWith(color: KineticColors.outline),
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
                          Icon(Icons.person_search_rounded,
                              size: 48, color: KineticColors.outlineVariant),
                          const SizedBox(height: KineticSpacing.sm),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No students enrolled yet.'
                                : 'No students found matching "$_searchQuery"',
                            style: KineticTypography.bodyMd
                                .copyWith(color: KineticColors.outline),
                          ),
                          if (_searchQuery.isEmpty &&
                              widget.classId.isNotEmpty &&
                              widget.trainerId.isNotEmpty) ...[
                            const SizedBox(height: KineticSpacing.sm),
                            TextButton.icon(
                              onPressed: _openAddStudentDialog,
                              icon: const Icon(Icons.person_add_rounded,
                                  size: 16),
                              label: const Text('Add First Student'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: KineticSpacing.lg,
                          vertical: KineticSpacing.sm),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: KineticSpacing.sm),
                      itemBuilder: (context, index) {
                        return _buildStudentCard(filtered[index]);
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
          horizontal: KineticSpacing.sm, vertical: KineticSpacing.md),
      decoration: BoxDecoration(
        color: KineticColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(KineticRadii.md),
        border: Border.all(
            color: KineticColors.surfaceContainerHighest, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(value,
              style: KineticTypography.titleMd.copyWith(
                  fontWeight: FontWeight.w800, color: KineticColors.deepSlate)),
          const SizedBox(height: 2),
          Text(label,
              style: KineticTypography.labelSm
                  .copyWith(color: KineticColors.outline, fontSize: 11),
              textAlign: TextAlign.center),
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
            width: 1),
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
                builder: (_) => StudentTrackingScreen(
                  student: student,
                  isTrainerView: widget.trainerId.isNotEmpty,
                  classId: widget.classId,
                ),
              ),
            );
            // Refresh list after returning from tracking screen
            if (mounted && widget.classId.isNotEmpty) {
              try {
                final doc = await _classService.db
                    .collection('classes')
                    .doc(widget.classId)
                    .get();
                final updated = ClassModel.fromFirestore(doc);
                if (mounted) {
                  setState(
                      () => _studentList = List.from(updated.students));
                }
              } catch (_) {}
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(KineticSpacing.md),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      KineticColors.secondary.withValues(alpha: 0.15),
                  child: Text(
                    student.name.isNotEmpty
                        ? student.name.substring(0, 1).toUpperCase()
                        : '?',
                    style: KineticTypography.titleMd.copyWith(
                        color: KineticColors.secondary,
                        fontWeight: FontWeight.w800),
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
                                  color: KineticColors.deepSlate),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (student.age > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: KineticColors.surfaceContainerHigh,
                                borderRadius:
                                    BorderRadius.circular(KineticRadii.sm),
                              ),
                              child: Text(
                                'Age ${student.age}',
                                style: KineticTypography.labelSm.copyWith(
                                    color: KineticColors.outline,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          if (student.isManuallyAdded) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: KineticColors.sunnyGold
                                    .withValues(alpha: 0.2),
                                borderRadius:
                                    BorderRadius.circular(KineticRadii.sm),
                              ),
                              child: Text(
                                'Manual',
                                style: KineticTypography.labelSm.copyWith(
                                    color: KineticColors.sunnyGold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (student.address.isNotEmpty)
                        Text(
                          student.address,
                          style: KineticTypography.bodySm
                              .copyWith(color: KineticColors.outline),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 6),

                      // Badges
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildMiniBadge(
                              icon: Icons.sync_rounded,
                              label: 'Cycle #${student.cycleNumber}',
                              color: KineticColors.secondary),
                          _buildMiniBadge(
                              icon: Icons.star_rounded,
                              label: '$completed/$total stars',
                              color: KineticColors.sunnyGold),
                          _buildMiniBadge(
                              icon: hasUnpaid
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline_rounded,
                              label: hasUnpaid ? 'Payment Due' : 'Paid',
                              color: hasUnpaid
                                  ? KineticColors.electricCoral
                                  : KineticColors.secondary),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: KineticColors.outlineVariant, size: 20),
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
          Text(label,
              style: KineticTypography.labelSm.copyWith(
                  color: color, fontWeight: FontWeight.w700, fontSize: 10)),
        ],
      ),
    );
  }
}
