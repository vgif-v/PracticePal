import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/theme.dart';
import 'student_tracking_screen.dart';
import '../models/student.dart';
import '../models/user_model.dart';
import '../services/class_service.dart';
import '../services/auth_service.dart';

// ---------------------------------------------------------------------------
// Student Dashboard — responsive nav (bottom bar < 900px, sidebar ≥ 900px)
// ---------------------------------------------------------------------------
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
  final AuthService _authService = AuthService();

  late String _effectiveStudentId;
  late String _effectiveStudentName;
  List<ClassModel> _classes = [];
  int _navIndex = 0; // 0 = My Classes, 1 = Profile

  // Profile data (loaded once)
  UserModel? _userModel;
  /// Static so dismissal persists across navigation — resets only on full app restart
  static bool _profileBannerDismissed = false;
  bool _loadingProfile = true;

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
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? _effectiveStudentId;
    if (uid.isEmpty) {
      if (mounted) setState(() => _loadingProfile = false);
      return;
    }
    try {
      final model = await _authService.getUserModel(uid);
      if (mounted) {
        setState(() {
          _userModel = model;
          if (model?.fullName.isNotEmpty == true) {
            _effectiveStudentName = model!.fullName;
          }
          _loadingProfile = false;
          // If profile is now complete, clear the dismissed flag so the banner
          // can reappear if data is ever missing again
          if (model != null &&
              model.address.trim().isNotEmpty &&
              model.birthdate != null) {
            _profileBannerDismissed = false;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  bool get _profileIncomplete {
    if (_userModel == null) return false;
    return _userModel!.address.trim().isEmpty ||
        _userModel!.birthdate == null;
  }

  // ---------------------------------------------------------------------------
  // Join Class Dialog
  // ---------------------------------------------------------------------------
  void _openJoinClassDialog() {
    final codeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
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
              child: const Icon(Icons.group_add_rounded,
                  color: KineticColors.coolBlue),
            ),
            const SizedBox(width: 10),
            const Text('Join a Class',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: KineticColors.coolDark)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the private class code provided by your trainer or studio.',
                style: KineticTypography.bodySm
                    .copyWith(color: KineticColors.coolMutedText),
              ),
              const SizedBox(height: KineticSpacing.md),
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Class Join Code',
                  hintText: 'e.g. PP-9421',
                  prefixIcon: const Icon(Icons.vpn_key_rounded,
                      color: KineticColors.sunnyGold),
                  fillColor: KineticColors.coolInputBg,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KineticRadii.dflt),
                    borderSide:
                        const BorderSide(color: KineticColors.coolBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KineticRadii.dflt),
                    borderSide: const BorderSide(
                        color: KineticColors.coolBlue, width: 2),
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
                    int calculatedAge = 0;
                    if (_userModel?.birthdate != null) {
                      final now = DateTime.now();
                      calculatedAge = now.year - _userModel!.birthdate!.year;
                      if (now.month < _userModel!.birthdate!.month ||
                          (now.month == _userModel!.birthdate!.month &&
                              now.day < _userModel!.birthdate!.day)) {
                        calculatedAge--;
                      }
                    }
                    final joined = await _classService.joinClassByCode(
                      joinCode: code,
                      studentId: _effectiveStudentId,
                      studentName: _effectiveStudentName,
                      address: _userModel?.address ?? '',
                      age: calculatedAge > 0 ? calculatedAge : 0,
                    );
                    if (!mounted) return;
                    if (joined != null) {
                      setState(() {
                        if (!_classes.any((c) => c.id == joined.id)) {
                          _classes.insert(0, joined);
                        }
                      });
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(SnackBar(
                          content: Text('Joined "${joined.name}" successfully!',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                          backgroundColor: KineticColors.secondary,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(KineticRadii.dflt)),
                        ));
                    } else {
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(const SnackBar(
                          content: Text(
                              'No class found with that code. Please check with your trainer.'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          SnackBar(
                            content: Text('Error joining class: $e'),
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
                    borderRadius: BorderRadius.circular(KineticRadii.full)),
              ),
              child: const Text('Join Class',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Navigate to tracking screen (student read-only view)
  // ---------------------------------------------------------------------------
  void _navigateToTracking(ClassModel classModel) {
    // Find this student's data in the class
    final studentData = classModel.students.firstWhere(
      (s) => s.name.toLowerCase() == _effectiveStudentName.toLowerCase(),
      orElse: () => StudentData.newEnrollment(
        name: _effectiveStudentName,
        trainerName: classModel.trainerName,
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentTrackingScreen(
          student: studentData,
          isTrainerView: false,
          classId: classModel.id,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSidebar = constraints.maxWidth >= 900;
        if (useSidebar) {
          return _buildSidebarLayout(context);
        } else {
          return _buildBottomNavLayout(context);
        }
      },
    );
  }

  // ---- Sidebar layout (≥ 900px) -------------------------------------------
  Widget _buildSidebarLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: KineticColors.surface,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _navIndex,
            onDestinationSelected: (i) => setState(() => _navIndex = i),
            extended: true,
            backgroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: _buildLogoMark(),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildSignOutTile(),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.school_outlined),
                selectedIcon: Icon(Icons.school_rounded),
                label: Text('My Classes'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: Text('Profile'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _buildCurrentTab()),
        ],
      ),
    );
  }

  // ---- Bottom nav layout (< 900px) -----------------------------------------
  Widget _buildBottomNavLayout(BuildContext context) {
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
              child: const Icon(Icons.person_rounded,
                  size: 20, color: KineticColors.coolBlue),
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
                      fontSize: 17),
                ),
                Text(
                  'Student Dashboard',
                  style: KineticTypography.bodySm.copyWith(
                      color: KineticColors.coolMutedText,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.logout_rounded, color: KineticColors.coolDark),
            onPressed: () async {
              final nav = Navigator.of(context);
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              nav.pushNamedAndRemoveUntil('/', (route) => false);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildCurrentTab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: KineticColors.coolBlue.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school_rounded,
                color: KineticColors.coolBlue),
            label: 'My Classes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded,
                color: KineticColors.coolBlue),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_navIndex) {
      case 1:
        return _buildProfileTab();
      default:
        return _buildClassesTab();
    }
  }

  // ---------------------------------------------------------------------------
  // Classes Tab
  // ---------------------------------------------------------------------------
  Widget _buildClassesTab() {
    return StreamBuilder<List<ClassModel>>(
      stream: _classService.streamStudentClasses(
          _effectiveStudentId, _effectiveStudentName),
      builder: (context, snapshot) {
        if (snapshot.hasData) _classes = snapshot.data!;

        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile incomplete banner
              if (!_loadingProfile &&
                  _profileIncomplete &&
                  !_profileBannerDismissed)
                _buildProfileBanner(),

              // Motivational Banner
              _buildMotivationalBanner(),

              // Section Title & Join Button
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: KineticSpacing.gutter,
                    vertical: KineticSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Joined Classes (${_classes.length})',
                      style: KineticTypography.titleMd.copyWith(
                          color: KineticColors.coolDark,
                          fontWeight: FontWeight.w800),
                    ),
                    InkWell(
                      onTap: _openJoinClassDialog,
                      borderRadius: BorderRadius.circular(KineticRadii.sm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(children: [
                          const Icon(Icons.add_circle_outline_rounded,
                              size: 16, color: KineticColors.coolBlue),
                          const SizedBox(width: 4),
                          Text('Enter Code',
                              style: KineticTypography.labelSm.copyWith(
                                  color: KineticColors.coolBlue,
                                  fontWeight: FontWeight.w800)),
                        ]),
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
                            horizontal: KineticSpacing.gutter, vertical: 4),
                        itemCount: _classes.length,
                        itemBuilder: (context, index) {
                          return _buildClassCard(_classes[index]);
                        },
                      ),
              ),

              // Join button at bottom
              Padding(
                padding: const EdgeInsets.all(KineticSpacing.gutter),
                child: Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(KineticRadii.full),
                      boxShadow: KineticShadows.coolDarkPop),
                  child: ElevatedButton.icon(
                    onPressed: _openJoinClassDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KineticColors.coolDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(KineticRadii.full)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 22),
                    label: const Text('Join Class with Private Code',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Edit Profile Sheet (Address & Birthdate)
  // ---------------------------------------------------------------------------
  void _openEditProfileSheet() {
    final nameCtrl = TextEditingController(text: _effectiveStudentName);
    final addressCtrl = TextEditingController(text: _userModel?.address ?? '');
    DateTime? pickedBirthdate = _userModel?.birthdate;
    bool isSavingProfile = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(KineticRadii.lg)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final formattedBirthdate = pickedBirthdate != null
                ? '${pickedBirthdate!.year}-${pickedBirthdate!.month.toString().padLeft(2, '0')}-${pickedBirthdate!.day.toString().padLeft(2, '0')}'
                : 'Not set';

            return Padding(
              padding: EdgeInsets.only(
                left: KineticSpacing.gutter,
                right: KineticSpacing.gutter,
                top: KineticSpacing.lg,
                bottom:
                    MediaQuery.of(ctx).viewInsets.bottom + KineticSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: KineticColors.coolBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: KineticSpacing.md),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: KineticColors.coolBlue
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.badge_rounded,
                              color: KineticColors.coolBlue, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Edit Profile',
                          style: KineticTypography.headlineSm.copyWith(
                            fontWeight: FontWeight.w800,
                            color: KineticColors.coolDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Update your address and birthdate so your trainer can verify your information.',
                      style: KineticTypography.bodySm
                          .copyWith(color: KineticColors.coolMutedText),
                    ),
                    const SizedBox(height: KineticSpacing.lg),

                    // Full Name
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person_rounded,
                            color: KineticColors.coolBlue),
                        fillColor: KineticColors.coolInputBg,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(KineticRadii.dflt),
                          borderSide:
                              const BorderSide(color: KineticColors.coolBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: KineticSpacing.md),

                    // Address
                    TextField(
                      controller: addressCtrl,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        hintText: 'e.g. 123 Rizal St, Barangay 4, Manila',
                        prefixIcon: const Icon(Icons.location_on_rounded,
                            color: KineticColors.coolBlue),
                        fillColor: KineticColors.coolInputBg,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(KineticRadii.dflt),
                          borderSide:
                              const BorderSide(color: KineticColors.coolBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: KineticSpacing.md),

                    // Birthdate Picker
                    InkWell(
                      onTap: isSavingProfile
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: pickedBirthdate ??
                                    DateTime(2005, 1, 1),
                                firstDate: DateTime(1930),
                                lastDate: DateTime.now(),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: KineticColors.coolBlue,
                                        onPrimary: Colors.white,
                                        surface: Colors.white,
                                        onSurface: KineticColors.coolDark,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setSheetState(
                                    () => pickedBirthdate = picked);
                              }
                            },
                      borderRadius:
                          BorderRadius.circular(KineticRadii.dflt),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: KineticColors.coolInputBg,
                          borderRadius:
                              BorderRadius.circular(KineticRadii.dflt),
                          border: Border.all(color: KineticColors.coolBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cake_rounded,
                                color: KineticColors.coolBlue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Birthdate',
                                    style: KineticTypography.labelSm.copyWith(
                                      color: KineticColors.coolMutedText,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    formattedBirthdate,
                                    style: KineticTypography.bodyMd.copyWith(
                                      color: pickedBirthdate != null
                                          ? KineticColors.coolDark
                                          : KineticColors.coolMutedText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.calendar_month_rounded,
                                color: KineticColors.coolBlue, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: KineticSpacing.xl),

                    // Save Button
                    ElevatedButton(
                      onPressed: isSavingProfile
                          ? null
                          : () async {
                              final newName = nameCtrl.text.trim();
                              final newAddress = addressCtrl.text.trim();
                              if (newName.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Please enter your full name.')),
                                );
                                return;
                              }
                              final messenger =
                                  ScaffoldMessenger.of(context);
                              final nav = Navigator.of(sheetContext);
                              setSheetState(() => isSavingProfile = true);
                              try {
                                final currentAuth =
                                    FirebaseAuth.instance.currentUser;
                                final uid =
                                    currentAuth?.uid ?? _effectiveStudentId;
                                if (uid.isEmpty) {
                                  throw Exception(
                                      'User is not signed in. Please sign in again.');
                                }

                                await _authService.updateUserProfile(
                                  uid,
                                  fullName: newName,
                                  address: newAddress,
                                  birthdate: pickedBirthdate,
                                );

                                // Non-blocking sync to enrolled classes
                                try {
                                  await _classService
                                      .updateStudentProfileInEnrolledClasses(
                                    studentId: uid,
                                    oldName: _effectiveStudentName,
                                    newName: newName,
                                    address: newAddress,
                                    birthdate: pickedBirthdate,
                                  );
                                } catch (syncErr) {
                                  debugPrint(
                                      'Notice: Enrolled classes sync skipped: $syncErr');
                                }

                                try {
                                  await currentAuth
                                      ?.updateDisplayName(newName);
                                } catch (_) {}

                                nav.pop();
                                await _loadProfile();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Profile updated successfully!'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: KineticColors.secondary,
                                  ),
                                );
                              } catch (e) {
                                debugPrint('Error saving profile: $e');
                                if (mounted) {
                                  setSheetState(
                                      () => isSavingProfile = false);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Error saving profile: $e'),
                                      backgroundColor:
                                          KineticColors.electricCoral,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KineticColors.coolDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(KineticRadii.full),
                        ),
                      ),
                      child: isSavingProfile
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Save Profile',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Profile Tab
  // ---------------------------------------------------------------------------
  Widget _buildProfileTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KineticSpacing.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Profile',
                style: KineticTypography.headlineSm.copyWith(
                    color: KineticColors.coolDark,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: KineticSpacing.lg),

            // Avatar
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor:
                    KineticColors.coolBlue.withValues(alpha: 0.15),
                child: Text(
                  _effectiveStudentName.isNotEmpty
                      ? _effectiveStudentName.substring(0, 1).toUpperCase()
                      : '?',
                  style: KineticTypography.headlineSm.copyWith(
                      color: KineticColors.coolBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 36),
                ),
              ),
            ),
            const SizedBox(height: KineticSpacing.md),
            Center(
              child: Text(_effectiveStudentName,
                  style: KineticTypography.titleMd.copyWith(
                      color: KineticColors.coolDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 20)),
            ),
            const SizedBox(height: KineticSpacing.lg),

            _buildProfileCard(),
            const SizedBox(height: KineticSpacing.md),

            // Edit Profile button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openEditProfileSheet,
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Edit Profile',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KineticColors.coolDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KineticRadii.full)),
                ),
              ),
            ),
            const SizedBox(height: KineticSpacing.lg),

            // Sign out
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return;
                  nav.pushNamedAndRemoveUntil('/', (route) => false);
                },
                icon: const Icon(Icons.logout_rounded,
                    color: KineticColors.electricCoral),
                label: const Text('Sign Out',
                    style: TextStyle(color: KineticColors.electricCoral)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                      color: KineticColors.electricCoral, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KineticRadii.full)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final user = _userModel;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(KineticRadii.md),
        boxShadow: KineticShadows.level1,
        border:
            Border.all(color: KineticColors.coolBorder, width: 1.2),
      ),
      child: Column(
        children: [
          _profileRow(
              icon: Icons.email_rounded,
              label: 'Email',
              value: user?.email ?? FirebaseAuth.instance.currentUser?.email ?? '—'),
          const Divider(height: 1),
          _profileRow(
              icon: Icons.location_on_rounded,
              label: 'Address',
              value: (user?.address.isNotEmpty == true)
                  ? user!.address
                  : 'Not set',
              incomplete: user?.address.isEmpty ?? true,
              onTap: _openEditProfileSheet),
          const Divider(height: 1),
          _profileRow(
              icon: Icons.cake_rounded,
              label: 'Birthdate',
              value: user?.birthdate != null
                  ? '${user!.birthdate!.year}-${user.birthdate!.month.toString().padLeft(2, '0')}-${user.birthdate!.day.toString().padLeft(2, '0')}'
                  : 'Not set',
              incomplete: user?.birthdate == null,
              onTap: _openEditProfileSheet),
          const Divider(height: 1),
          _profileRow(
              icon: Icons.badge_rounded,
              label: 'Role',
              value: 'Student'),
        ],
      ),
    );
  }

  Widget _profileRow({
    required IconData icon,
    required String label,
    required String value,
    bool incomplete = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: KineticSpacing.md, vertical: KineticSpacing.sm),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: incomplete
                    ? KineticColors.electricCoral
                    : KineticColors.coolBlue),
            const SizedBox(width: KineticSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: KineticTypography.labelSm.copyWith(
                          color: KineticColors.coolMutedText,
                          fontSize: 11)),
                  Text(value,
                      style: KineticTypography.bodyMd.copyWith(
                          color: incomplete
                              ? KineticColors.electricCoral
                              : KineticColors.coolDark,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (incomplete)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: KineticColors.electricCoral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(KineticRadii.sm),
                ),
                child: Text('Missing',
                    style: KineticTypography.labelSm.copyWith(
                        color: KineticColors.electricCoral,
                        fontWeight: FontWeight.w700,
                        fontSize: 10)),
              )
            else if (onTap != null)
              const Icon(Icons.edit_outlined,
                  size: 16, color: KineticColors.coolMutedText),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Profile Incomplete Banner
  // ---------------------------------------------------------------------------
  Widget _buildProfileBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: KineticSpacing.gutter, vertical: KineticSpacing.sm),
      padding: const EdgeInsets.all(KineticSpacing.md),
      decoration: BoxDecoration(
        color: KineticColors.sunnyGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KineticRadii.md),
        border: Border.all(
            color: KineticColors.sunnyGold.withValues(alpha: 0.5),
            width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: KineticColors.sunnyGold, size: 22),
          const SizedBox(width: KineticSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Complete your profile',
                    style: KineticTypography.labelMd.copyWith(
                        color: KineticColors.coolDark,
                        fontWeight: FontWeight.w800)),
                Text(
                  'Your trainer needs your address and birthdate.',
                  style: KineticTypography.bodySm
                      .copyWith(color: KineticColors.coolMutedText),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _openEditProfileSheet,
            style: TextButton.styleFrom(
                foregroundColor: KineticColors.sunnyGold),
            child: const Text('Update',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 18, color: KineticColors.coolMutedText),
            onPressed: () =>
                setState(() => _profileBannerDismissed = true),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Motivational Banner
  // ---------------------------------------------------------------------------
  Widget _buildMotivationalBanner() {
    int totalStars = 0;
    for (final c in _classes) {
      final student = c.students.firstWhere(
        (s) => s.name.toLowerCase() == _effectiveStudentName.toLowerCase(),
        orElse: () => StudentData.defaultStudent(),
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
                shape: BoxShape.circle),
            child: const Icon(Icons.star_rounded,
                color: KineticColors.sunnyGold, size: 34),
          ),
          const SizedBox(width: KineticSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalStars Total Stars Collected! 🌟',
                  style: KineticTypography.titleMd.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Keep practicing! Consistency creates champions.',
                  style: KineticTypography.bodySm.copyWith(
                      color: const Color(0xFFCBD5E1),
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty State
  // ---------------------------------------------------------------------------
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
                  shape: BoxShape.circle),
              child: const Icon(Icons.school_outlined,
                  size: 38, color: KineticColors.coolBlue),
            ),
            const SizedBox(height: KineticSpacing.md),
            Text('No Classes Joined Yet',
                style: KineticTypography.titleMd.copyWith(
                    color: KineticColors.coolDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                'Enter the private code from your trainer (e.g. PP-XXXX) to join their class and track your stars!',
                textAlign: TextAlign.center,
                style: KineticTypography.bodySm.copyWith(
                    color: KineticColors.coolMutedText, height: 1.4),
              ),
            ),
            const SizedBox(height: KineticSpacing.lg),
            ElevatedButton.icon(
              onPressed: _openJoinClassDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: KineticColors.coolDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KineticRadii.full)),
              ),
              icon: const Icon(Icons.vpn_key_rounded, size: 18),
              label: const Text('Enter Join Code',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Class Card
  // ---------------------------------------------------------------------------
  Widget _buildClassCard(ClassModel classModel) {
    final student = classModel.students.firstWhere(
      (s) => s.name.toLowerCase() == _effectiveStudentName.toLowerCase(),
      orElse: () => StudentData.newEnrollment(
        name: _effectiveStudentName,
        trainerName: classModel.trainerName,
      ),
    );

    final completed = student.sessions.where((s) => s.isCompleted).length;
    final total =
        student.sessions.isNotEmpty ? student.sessions.length : 8;
    final progress = (completed / total).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: KineticSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(KineticRadii.md),
        boxShadow: KineticShadows.level1,
        border: Border.all(color: KineticColors.coolBorder, width: 1.5),
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
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: KineticColors.coolBlue.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(KineticRadii.dflt),
                    ),
                    child: const Icon(Icons.sports_gymnastics_rounded,
                        color: KineticColors.coolBlue, size: 24),
                  ),
                  const SizedBox(width: KineticSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(classModel.name,
                            style: KineticTypography.titleMd.copyWith(
                                color: KineticColors.coolDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.person_outline_rounded,
                              size: 14,
                              color: KineticColors.coolMutedText),
                          const SizedBox(width: 4),
                          Text(classModel.trainerName,
                              style: KineticTypography.bodySm.copyWith(
                                  color: KineticColors.coolMutedText,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: KineticColors.coolInputBg,
                      borderRadius:
                          BorderRadius.circular(KineticRadii.sm),
                      border: Border.all(color: KineticColors.coolBorder),
                    ),
                    child: Text(classModel.joinCode,
                        style: KineticTypography.labelSm.copyWith(
                            color: KineticColors.coolDark,
                            fontWeight: FontWeight.w800)),
                  ),
                ]),
                const SizedBox(height: KineticSpacing.md),

                // Schedule & location
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: KineticColors.coolInputBg,
                      borderRadius:
                          BorderRadius.circular(KineticRadii.sm),
                      border: Border.all(color: KineticColors.coolBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 12,
                            color: KineticColors.coolMutedText),
                        const SizedBox(width: 4),
                        Text(classModel.schedule,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: KineticColors.coolDark)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(classModel.room,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KineticTypography.labelSm.copyWith(
                            color: KineticColors.coolMutedText,
                            fontSize: 11)),
                  ),
                ]),

                const SizedBox(height: KineticSpacing.sm),

                // Progress bar
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(KineticRadii.full),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: KineticColors.coolInputBg,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            KineticColors.coolBlue),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('$completed/$total Sessions',
                      style: KineticTypography.labelSm.copyWith(
                          color: KineticColors.coolDark,
                          fontWeight: FontWeight.w800)),
                ]),

                // Cycle badge
                const SizedBox(height: KineticSpacing.sm),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: KineticColors.secondary.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(KineticRadii.sm),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.sync_rounded,
                          size: 11, color: KineticColors.secondary),
                      const SizedBox(width: 3),
                      Text('Cycle #${student.cycleNumber}',
                          style: KineticTypography.labelSm.copyWith(
                              color: KineticColors.secondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10)),
                    ]),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  Widget _buildLogoMark() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: KineticColors.electricCoral,
            borderRadius: BorderRadius.circular(KineticRadii.sm),
          ),
          child: const Icon(Icons.sports_gymnastics_rounded,
              size: 18, color: Colors.white),
        ),
        const SizedBox(width: 8),
        RichText(
          text: TextSpan(
            style: KineticTypography.titleMd
                .copyWith(fontWeight: FontWeight.w900),
            children: const [
              TextSpan(
                  text: 'Practice',
                  style: TextStyle(color: KineticColors.deepSlate)),
              TextSpan(
                  text: 'Pal',
                  style: TextStyle(color: KineticColors.electricCoral)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignOutTile() {
    return ListTile(
      leading: const Icon(Icons.logout_rounded,
          color: KineticColors.electricCoral, size: 20),
      title: const Text('Sign Out',
          style: TextStyle(
              color: KineticColors.electricCoral,
              fontWeight: FontWeight.w700,
              fontSize: 14)),
      onTap: () async {
        final nav = Navigator.of(context);
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        nav.pushNamedAndRemoveUntil('/', (route) => false);
      },
    );
  }
}
