import 'package:flutter/material.dart';
import '../theme/theme.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final AuthService _authService = AuthService();
  UserRole _selectedRole = UserRole.trainer;
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? _birthdate;

  String _uid = '';
  String _email = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _uid = args['uid'] ?? '';
      _email = args['email'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty) {
      _showSnack('Please enter your full name.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userModel = UserModel(
        uid: _uid,
        role: _selectedRole,
        fullName: name,
        address: address,
        birthdate: _birthdate,
        email: _email,
      );

      try {
        await _authService.createUserDocument(userModel);
      } catch (firestoreErr) {
        debugPrint('Firestore save warning in complete profile: $firestoreErr');
      }

      if (!mounted) return;

      final route =
          _selectedRole == UserRole.trainer ? '/trainer' : '/student';
      Navigator.pushReplacementNamed(
        context,
        route,
        arguments: {'name': name},
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to save profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: KineticColors.coolDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KineticRadii.dflt),
        ),
      ),
    );
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 15),
      firstDate: DateTime(1940),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
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
    if (picked != null) setState(() => _birthdate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF), Color(0xFFF1F5F9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: KineticSpacing.lg,
                vertical: KineticSpacing.md,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: KineticSpacing.xl),
                    _buildCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [KineticColors.coolDark, KineticColors.coolBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(KineticRadii.md),
            boxShadow: [
              BoxShadow(
                color: KineticColors.coolBlue.withValues(alpha: 0.30),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.person_add_alt_1_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: KineticSpacing.md),
        Text(
          'Complete Your Profile',
          style: KineticTypography.headlineLg.copyWith(
            color: KineticColors.coolDark,
            fontSize: 26,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Just a few more details to get you started!',
          textAlign: TextAlign.center,
          style: KineticTypography.bodyMd.copyWith(
            color: KineticColors.coolMutedText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(KineticRadii.lg),
        boxShadow: KineticShadows.level2,
        border: Border.all(
          color: KineticColors.coolBorder.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(KineticSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step 1: Role selection
          Text(
            'Choose your role:',
            style: KineticTypography.labelMd.copyWith(
              color: KineticColors.coolDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: KineticSpacing.xs),
          Row(
            children: [
              Expanded(child: _buildRoleCard(UserRole.trainer)),
              const SizedBox(width: KineticSpacing.sm),
              Expanded(child: _buildRoleCard(UserRole.student)),
            ],
          ),

          const SizedBox(height: KineticSpacing.lg),

          // Step 2: Profile fields
          _buildFloatingField(
            controller: _nameController,
            label: 'Full Name',
            prefixIcon: Icons.person_rounded,
          ),
          const SizedBox(height: KineticSpacing.md),
          _buildFloatingField(
            controller: _addressController,
            label: 'Address (Optional)',
            prefixIcon: Icons.location_on_outlined,
          ),
          const SizedBox(height: KineticSpacing.md),
          _buildBirthdateField(),
          const SizedBox(height: KineticSpacing.md),

          // Email — locked / read-only
          _buildFloatingField(
            controller: TextEditingController(text: _email),
            label: 'Email (from Google)',
            prefixIcon: Icons.alternate_email_rounded,
            readOnly: true,
            suffixIcon: const Icon(
              Icons.lock_rounded,
              color: KineticColors.coolMutedText,
              size: 18,
            ),
          ),

          const SizedBox(height: KineticSpacing.xl),

          // Submit
          Container(
            decoration: BoxDecoration(
              boxShadow: KineticShadows.coolDarkPop,
              borderRadius: BorderRadius.circular(KineticRadii.full),
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: KineticColors.coolDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KineticRadii.full),
                ),
                disabledBackgroundColor:
                    KineticColors.coolDark.withValues(alpha: 0.5),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Get Started',
                          style: KineticTypography.titleMd.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(UserRole role) {
    final isTrainer = role == UserRole.trainer;
    final isSelected = _selectedRole == role;
    final accentColor =
        isTrainer ? KineticColors.coolBlueLight : KineticColors.neonTeal;
    final icon = isTrainer ? Icons.sports_kabaddi_rounded : Icons.star_rounded;
    final title = isTrainer ? "I'm a Trainer" : "I'm a Student";
    final subtitle =
        isTrainer ? 'Coach & track classes' : 'Practice & view stars';

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          horizontal: KineticSpacing.sm,
          vertical: KineticSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.10)
              : KineticColors.coolInputBg,
          borderRadius: BorderRadius.circular(KineticRadii.md),
          border: Border.all(
            color: isSelected ? accentColor : KineticColors.coolBorder,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? accentColor : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.transparent : KineticColors.coolBorder,
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : KineticColors.coolMutedText,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: KineticTypography.titleMd.copyWith(
                color: isSelected
                    ? KineticColors.coolDark
                    : KineticColors.coolMutedText,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: KineticTypography.labelSm.copyWith(
                color: KineticColors.coolMutedText,
                fontSize: 11,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingField({
    required TextEditingController controller,
    required String label,
    IconData? prefixIcon,
    Widget? suffixIcon,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      cursorColor: KineticColors.coolBlue,
      style: KineticTypography.bodyMd.copyWith(
        color: KineticColors.coolDark,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        labelStyle: KineticTypography.bodyMd.copyWith(
          color: KineticColors.coolMutedText,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: KineticTypography.labelMd.copyWith(
          color: KineticColors.coolBlue,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: KineticColors.coolMutedText, size: 20)
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: KineticColors.coolInputBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: KineticSpacing.md,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KineticRadii.dflt),
          borderSide: const BorderSide(
            color: KineticColors.coolBorder,
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KineticRadii.dflt),
          borderSide: const BorderSide(
            color: KineticColors.coolBorder,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KineticRadii.dflt),
          borderSide: const BorderSide(
            color: KineticColors.coolBlue,
            width: 2.0,
          ),
        ),
      ),
    );
  }

  Widget _buildBirthdateField() {
    final display = _birthdate != null
        ? '${_birthdate!.month.toString().padLeft(2, '0')}/'
            '${_birthdate!.day.toString().padLeft(2, '0')}/'
            '${_birthdate!.year}'
        : '';

    return GestureDetector(
      onTap: _pickBirthdate,
      child: AbsorbPointer(
        child: TextField(
          controller: TextEditingController(text: display),
          readOnly: true,
          style: KineticTypography.bodyMd.copyWith(
            color: KineticColors.coolDark,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            labelText: 'Birthdate (Optional)',
            floatingLabelBehavior: display.isEmpty
                ? FloatingLabelBehavior.never
                : FloatingLabelBehavior.auto,
            hintText: 'Tap to select birthdate',
            hintStyle: KineticTypography.bodyMd.copyWith(
              color: KineticColors.coolMutedText.withValues(alpha: 0.7),
            ),
            labelStyle: KineticTypography.bodyMd.copyWith(
              color: KineticColors.coolMutedText,
              fontWeight: FontWeight.w600,
            ),
            floatingLabelStyle: KineticTypography.labelMd.copyWith(
              color: KineticColors.coolBlue,
              fontWeight: FontWeight.w700,
            ),
            prefixIcon: const Icon(
              Icons.cake_rounded,
              color: KineticColors.coolMutedText,
              size: 20,
            ),
            suffixIcon: const Icon(
              Icons.calendar_today_rounded,
              color: KineticColors.coolMutedText,
              size: 18,
            ),
            filled: true,
            fillColor: KineticColors.coolInputBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: KineticSpacing.md,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KineticRadii.dflt),
              borderSide: const BorderSide(
                color: KineticColors.coolBorder,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KineticRadii.dflt),
              borderSide: const BorderSide(
                color: KineticColors.coolBorder,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KineticRadii.dflt),
              borderSide: const BorderSide(
                color: KineticColors.coolBlue,
                width: 2.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
