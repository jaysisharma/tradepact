import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tradepact/core/services/auth_service.dart';
import 'package:tradepact/core/theme/app_theme.dart';
import 'package:tradepact/core/widgets/tradepact_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final auth = ref.read(authServiceProvider);
      if (_isSignUp) {
        await auth.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        await auth.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
      if (mounted) context.go('/dashboard');
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_friendlyError(e.code));
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final credential = await ref.read(authServiceProvider).signInWithGoogle();
      if (credential == null) return; // user cancelled the Google sheet
      if (mounted) context.go('/dashboard');
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_friendlyError(e.code));
    } catch (e) {
      if (mounted) _showError('Google sign-in failed.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Enter your email above first.');
      return;
    }
    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent.'),
            backgroundColor: AppColors.win,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_friendlyError(e.code));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.loss),
    );
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              _buildLogo(),
              const SizedBox(height: 16),
              Text(
                'TradePact',
                style: AppTextStyles.numberLarge.copyWith(
                  color: AppColors.gold,
                  fontSize: 36,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Make a pact. Keep it.',
                style: AppTextStyles.labelSmall.copyWith(fontSize: 14, letterSpacing: 1),
              ),
              const SizedBox(height: 48),
              _buildTabToggle(),
              const SizedBox(height: 28),
              _buildForm(),
              const SizedBox(height: 20),
              _buildSubmitButton(),
              if (!_isSignUp) ...[
                const SizedBox(height: 12),
                _buildForgotPassword(),
              ],
              const SizedBox(height: 28),
              _buildDivider(),
              const SizedBox(height: 28),
              _buildGoogleButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return const TradePactLogo(size: 88);
  }

  Widget _buildTabToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _tabButton('Sign In', !_isSignUp),
          _tabButton('Create Account', _isSignUp),
        ],
      ),
    );
  }

  Widget _tabButton(String label, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isSignUp = label == 'Create Account'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: active ? AppColors.background : AppColors.textSecondary,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: AppTextStyles.bodyMedium,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary, size: 20),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outlined, color: AppColors.textSecondary, size: 20),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (_isSignUp && v.length < 6) return 'Minimum 6 characters';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submitEmailPassword,
      child: _isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
            )
          : Text(_isSignUp ? 'Create Account' : 'Sign In'),
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _forgotPassword,
        child: Text(
          'Forgot password?',
          style: AppTextStyles.caption.copyWith(color: AppColors.gold),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('or', style: AppTextStyles.caption),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _signInWithGoogle,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _GoogleLogo(size: 22),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  final double size;
  const _GoogleLogo({this.size = 24});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    const strokeW = 0.26; // fraction of diameter

    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = r * strokeW * 2;

    // Blue: top-right arc (~-30° to 90°, i.e. 330° to 90° going clockwise = -30° to 90°)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, _deg(-30), _deg(120), false, paint);

    // Red: top-left arc (90° to 180°)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, _deg(90), _deg(90), false, paint);

    // Yellow: bottom-left arc (180° to 270°)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, _deg(180), _deg(90), false, paint);

    // Green: bottom-right arc (270° to 330°)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, _deg(270), _deg(60), false, paint);

    // Blue horizontal bar at the middle-right
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4285F4);
    final barTop = cy - r * strokeW;
    final barBottom = cy + r * strokeW;
    final barLeft = cx;
    final barRight = cx + r + r * strokeW;
    canvas.drawRect(
      Rect.fromLTRB(barLeft, barTop, barRight, barBottom),
      paint,
    );
  }

  double _deg(double degrees) => degrees * 3.141592653589793 / 180;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
