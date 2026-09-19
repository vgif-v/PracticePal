import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/theme.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({super.key});

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();

  // Shared
  UserRole _selectedRole = UserRole.trainer;
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? _birthdate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Auth Handlers
  // ---------------------------------------------------------------------------

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack('Please enter both your email and password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final cred = await _authService.signInWithEmail(email, password);
      final uid = cred.user!.uid;

      UserModel? userModel;
      try {
        userModel = await _authService.getUserModel(uid);
      } catch (firestoreErr) {
        debugPrint('Firestore read warning: $firestoreErr');
      }

      if (!mounted) return;
      final role = userModel?.role ?? _selectedRole;
      final name = userModel?.fullName ?? cred.user!.displayName ?? cred.user!.email ?? 'User';
      _navigateToDashboard(role, name, uid);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Login failed: ${_friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty) {
      _showSnack('Please enter your full name.');
      return;
    }
    if (email.isEmpty) {
      _showSnack('Please enter your email address.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      _showSnack('Please enter a valid email address.');
      return;
    }
    if (password.isEmpty) {
      _showSnack('Please enter a password.');
      return;
    }
    if (password.length < 6) {
      _showSnack('Password must be at least 6 characters long.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final cred = await _authService.registerWithEmail(email, password);
      final uid = cred.user!.uid;

      // Ensure display name is recorded in Firebase Auth
      try {
        await cred.user?.updateDisplayName(name);
      } catch (e) {
        debugPrint('Could not set displayName: $e');
      }

      final userModel = UserModel(
        uid: uid,
        role: _selectedRole,
        fullName: name,
        address: address,
        birthdate: _birthdate,
        email: email,
      );

      // Save user doc to Firestore; do NOT let a Firestore rules/network issue block login
      try {
        await _authService.createUserDocument(userModel);
      } catch (firestoreError) {
        debugPrint('Warning: Firestore createUserDocument failed: $firestoreError');
      }

      if (!mounted) return;
      _navigateToDashboard(_selectedRole, name, uid);
    } catch (e) {
      debugPrint('Registration Error: $e');
      if (!mounted) return;
      if (e is FirebaseAuthException && e.code == 'email-already-in-use') {
        _showSnack('This email is already registered. Switched to Log In tab.');
        _tabController.animateTo(0);
      } else {
        _showSnack('Registration failed: ${_friendlyError(e)}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final cred = await _authService.signInWithGoogle();
      if (cred == null) {
        // User dismissed/cancelled Google dialog
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final uid = cred.user!.uid;
      final displayName = cred.user!.displayName ?? cred.user!.email?.split('@').first ?? 'User';

      bool exists = false;
      try {
        exists = await _authService.checkUserExists(uid);
      } catch (e) {
        debugPrint('Firestore checkUserExists error: $e');
      }

      if (!mounted) return;

      if (exists) {
        UserModel? userModel;
        try {
          userModel = await _authService.getUserModel(uid);
        } catch (_) {}

        if (!mounted) return;
        final role = userModel?.role ?? _selectedRole;
        final name = userModel?.fullName ?? displayName;
        _navigateToDashboard(role, name, uid);
      } else {
        // New Google user → seamlessly save profile with chosen role & enter app
        final userModel = UserModel(
          uid: uid,
          role: _selectedRole,
          fullName: displayName,
          address: '',
          email: cred.user!.email ?? '',
          birthdate: _birthdate,
        );

        try {
          await _authService.createUserDocument(userModel);
        } catch (e) {
          debugPrint('Firestore createUserDocument warning: $e');
        }

        if (!mounted) return;
        _navigateToDashboard(_selectedRole, displayName, uid);
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      if (!mounted) return;
      _showSnack('Google Sign-In failed: ${_friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToDashboard(UserRole role, String userName, String uid) {
    final route = role == UserRole.trainer ? '/trainer' : '/student';
    Navigator.pushReplacementNamed(
      context,
      route,
      arguments: {'name': userName, 'uid': uid},
    );
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

  String _friendlyError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'operation-not-allowed':
          return 'Email/password sign-in is not enabled in Firebase Console. Please use Google Sign-In or enable it in Firebase Console.';
        case 'email-already-in-use':
          return 'This email is already registered. Please log in instead.';
        case 'invalid-email':
          return 'The email address is invalid.';
        case 'weak-password':
          return 'Password is too weak. Please use at least 6 characters.';
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment and try again.';
        default:
          return e.message ?? e.code;
      }
    }
    final s = e.toString();
    if (s.contains('network-request-failed') || s.contains('SocketException')) {
      return 'Network error. Please check your internet connection.';
    }
    if (s.contains('permission-denied')) {
      return 'Firestore permission denied. Check your Firestore Security Rules in Firebase Console.';
    }
    if (s.contains('ApiException: 10') || s.contains('10:')) {
      return 'Google Sign-In configuration error (API 10): Ensure SHA-1 fingerprint is added in Firebase Console.';
    }
    if (s.contains('12500:')) {
      return 'Google Sign-In error (12500): Please ensure Google Play Services is up to date.';
    }
    return s.contains(']') ? s.split(']').last.trim() : s;
  }

  // ---------------------------------------------------------------------------
  // Birthdate Picker
  // ---------------------------------------------------------------------------

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
    if (picked != null) {
      setState(() => _birthdate = picked);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isLogin = _tabController.index == 0;

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
            child: isLogin ? _buildLoginLayout() : _buildRegisterLayout(),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LOGIN LAYOUT
  // ---------------------------------------------------------------------------

  Widget _buildLoginLayout() {
    return SingleChildScrollView(
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
            const SizedBox(height: KineticSpacing.lg),
            _buildCardShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTabBarToggle(),
                  const SizedBox(height: KineticSpacing.md),
                  _buildRoleSelector(),
                  const SizedBox(height: KineticSpacing.lg),

                  // Email & Password Fields
                  _buildFloatingField(
                    controller: _emailController,
                    label: 'Email Address',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.alternate_email_rounded,
                  ),
                  const SizedBox(height: KineticSpacing.md),
                  _buildFloatingField(
                    controller: _passwordController,
                    label: 'Password',
                    obscureText: _obscurePassword,
                    prefixIcon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: KineticColors.coolMutedText,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: KineticSpacing.lg),
                  _buildContinueButton(
                    label: 'Sign In with Email',
                    onPressed: _isLoading ? null : _handleLogin,
                  ),
                  _buildOrDivider(),
                  _buildGoogleSignInButton(
                    label: 'Continue with Google',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REGISTER LAYOUT
  // ---------------------------------------------------------------------------

  Widget _buildRegisterLayout() {
    return SingleChildScrollView(
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
            const SizedBox(height: KineticSpacing.lg),
            _buildCardShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTabBarToggle(),
                  const SizedBox(height: KineticSpacing.md),

                  // Step 1: Role selector
                  _buildRoleSelector(),
                  const SizedBox(height: KineticSpacing.lg),

                  // Step 2: Registration fields (cool/dark styled)
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
                  _buildFloatingField(
                    controller: _emailController,
                    label: 'Email Address',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.alternate_email_rounded,
                  ),
                  const SizedBox(height: KineticSpacing.md),
                  _buildFloatingField(
                    controller: _passwordController,
                    label: 'Password (min. 6 characters)',
                    obscureText: _obscurePassword,
                    prefixIcon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: KineticColors.coolMutedText,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: KineticSpacing.lg),
                  _buildContinueButton(
                    label: 'Create Account with Email',
                    onPressed: _isLoading ? null : _handleRegister,
                  ),
                  _buildOrDivider(),
                  _buildGoogleSignInButton(
                    label: 'Sign up with Google',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header Widget (Cool & Dark Styling)
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(KineticRadii.lg),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withValues(alpha: 0.20),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: KineticColors.coolBorder.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(KineticRadii.md),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: KineticSpacing.sm),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Practice',
              style: KineticTypography.displayHero.copyWith(
                color: KineticColors.coolDark,
                fontSize: 32,
                letterSpacing: -1,
              ),
            ),
            Text(
              'Pal',
              style: KineticTypography.displayHero.copyWith(
                color: KineticColors.coolBlue,
                fontSize: 32,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: KineticColors.coolDark,
                borderRadius: BorderRadius.circular(KineticRadii.sm),
              ),
              child: const Text(
                'PRO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Track routines, smash goals & celebrate practice!',
          textAlign: TextAlign.center,
          style: KineticTypography.bodyMd.copyWith(
            color: KineticColors.coolMutedText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCardShell({required Widget child}) {
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
      child: child,
    );
  }

  Widget _buildTabBarToggle() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: KineticColors.coolInputBg,
        borderRadius: BorderRadius.circular(KineticRadii.full),
        border: Border.all(color: KineticColors.coolBorder),
      ),
      padding: const EdgeInsets.all(3),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: KineticColors.coolDark,
          borderRadius: BorderRadius.circular(KineticRadii.full),
          boxShadow: [
            BoxShadow(
              color: KineticColors.coolDark.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: KineticColors.coolMutedText,
        labelStyle: KineticTypography.titleMd.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: KineticTypography.bodyMd.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: 'Log In'),
          Tab(text: 'Register'),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tabController.index == 0 ? 'Select your role:' : 'Register as:',
          style: KineticTypography.labelMd.copyWith(
            color: KineticColors.coolDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: KineticSpacing.xs),
        Row(
          children: [
            Expanded(
              child: _buildRoleCard(
                title: "I'm a Trainer",
                subtitle: 'Coach & track classes',
                role: UserRole.trainer,
                icon: Icons.sports_kabaddi_rounded,
                accentColor: KineticColors.coolBlueLight,
              ),
            ),
            const SizedBox(width: KineticSpacing.sm),
            Expanded(
              child: _buildRoleCard(
                title: "I'm a Student",
                subtitle: 'Practice & view stars',
                role: UserRole.student,
                icon: Icons.star_rounded,
                accentColor: KineticColors.neonTeal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required UserRole role,
    required IconData icon,
    required Color accentColor,
  }) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          horizontal: KineticSpacing.sm,
          vertical: KineticSpacing.sm + 2,
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
              width: 38,
              height: 38,
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
                size: 20,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: KineticTypography.titleMd.copyWith(
                color: isSelected
                    ? KineticColors.coolDark
                    : KineticColors.coolMutedText,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: KineticTypography.labelSm.copyWith(
                color: KineticColors.coolMutedText,
                fontSize: 10.5,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In Button (DEFAULT & Prominent)
  // ---------------------------------------------------------------------------

  Widget _buildGoogleSignInButton({
    required String label,
    bool isDefault = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(KineticRadii.full),
        border: Border.all(
          color: isDefault ? KineticColors.coolBlueLight : KineticColors.coolBorder,
          width: isDefault ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDefault ? KineticColors.coolBlue : KineticColors.coolDark)
                .withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(KineticRadii.full),
          onTap: _isLoading ? null : _handleGoogleSignIn,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildGoogleIcon(),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: KineticTypography.titleMd.copyWith(
                    color: KineticColors.coolDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (isDefault) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: KineticColors.coolBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Default',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: KineticColors.coolBlue,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(
        painter: _GoogleGPainter(),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KineticSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: KineticColors.coolBorder.withValues(alpha: 0.7),
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'or continue with',
              style: KineticTypography.labelSm.copyWith(
                color: KineticColors.coolMutedText,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: KineticColors.coolBorder.withValues(alpha: 0.7),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Floating-label input field (Cool & Dark Theme)
  // ---------------------------------------------------------------------------

  Widget _buildFloatingField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    IconData? prefixIcon,
    Widget? suffixIcon,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
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

  // ---------------------------------------------------------------------------
  // Birthdate Field (Cool & Dark Theme)
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Action Button (Cool Dark Palette)
  // ---------------------------------------------------------------------------

  Widget _buildContinueButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: KineticShadows.coolDarkPop,
        borderRadius: BorderRadius.circular(KineticRadii.full),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: KineticColors.coolDark,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KineticRadii.full),
          ),
          disabledBackgroundColor: KineticColors.coolDark.withValues(alpha: 0.5),
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
                    label,
                    style: KineticTypography.titleMd.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 19,
                    color: Colors.white,
                  ),
                ],
              ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Official Google Multi-Color "G" Icon Painter
// -----------------------------------------------------------------------------
class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeW = w * 0.22;
    final radius = (w - strokeW) / 2;
    final center = Offset(w / 2, h / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;

    // Red: Top arc
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.4, 1.4, false, paint);

    // Yellow: Bottom-left arc
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.2, 1.2, false, paint);

    // Green: Bottom arc
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.7, 1.5, false, paint);

    // Blue: Right arc
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.9, 1.6, false, paint);

    // Blue horizontal bar into the center
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final barRect = Rect.fromLTWH(
      center.dx - 1,
      center.dy - (strokeW / 2),
      (w / 2) + 1,
      strokeW,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
