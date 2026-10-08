import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../../state/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/responsive_center.dart';

/// Customer login via Firebase Google Sign-In. Google proves who the
/// customer is; this app's `customers` table is still keyed by phone
/// number everywhere (orders, delivery, the admin panel), so the very
/// first time a given Google account signs in, one extra step asks for a
/// delivery phone number - every sign-in after that skips straight
/// through, since link_google_customer() (see
/// supabase/migrations/20260915122700_customer_google_auth.sql) remembers the pairing.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _googleReady = false;
  bool _isSubmitting = false;

  /// Set once Google + Firebase confirm identity but no phone is linked
  /// yet - the screen switches to the one-time phone step, and this is
  /// what [_completePhoneStep] links it to.
  String? _pendingGoogleUid;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Idempotent - safe to call every time [_signInWithGoogle] runs, not
  /// just once in initState. Originally this only ran once in the
  /// background with failures silently debugPrint'd, which meant a real
  /// init failure (e.g. Play Services out of date, a misconfigured
  /// OAuth client) left the button stuck showing "Loading..." forever
  /// with no visible error and no way to retry. Calling it lazily, right
  /// before the tap that needs it, means a failure surfaces through the
  /// same try/catch as everything else in [_signInWithGoogle] instead of
  /// disappearing into the debug console.
  Future<void> _ensureGoogleSignInReady() async {
    if (_googleReady) return;
    final serverClientId = dotenv.env['GOOGLE_SIGN_IN_SERVER_CLIENT_ID'];
    await GoogleSignIn.instance.initialize(
      serverClientId: (serverClientId != null && serverClientId.isNotEmpty)
          ? serverClientId
          : null,
    );
    _googleReady = true;
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final auth = context.read<AuthProvider>();

    try {
      await _ensureGoogleSignInReady();
      // Uses attemptLightweightAuthentication() instead of authenticate().
      // Both are legitimate interactive entry points, but they exercise
      // different Android Credential Manager request types under the hood:
      // authenticate() always uses the newer "Sign in with Google"
      // button-credential flow (GetSignInWithGoogleOption), which on some
      // real devices fails instantly - before any account picker ever shows
      // - with GoogleSignInExceptionCode.canceled / "[16] Account reauth
      // failed", reproducibly for every Google account on the device (ruled
      // out being account-specific by testing two unrelated accounts).
      // attemptLightweightAuthentication()'s second internal attempt (see
      // google_sign_in_android's implementation) falls back to the older,
      // more broadly-supported GetGoogleIdOption request type instead, which
      // still shows an account picker (autoSelectEnabled is false) rather
      // than silently succeeding/failing - reportAllExceptions: true keeps
      // every failure mode (including a real cancellation) visible here
      // rather than swallowed into a silent null, matching authenticate()'s
      // behavior of always surfacing what happened.
      final account = await GoogleSignIn.instance
          .attemptLightweightAuthentication(reportAllExceptions: true);
      if (account == null) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        return;
      }
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'no-id-token',
          message: 'Google did not return an identity token.',
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final uid = userCredential.user?.uid;
      if (uid == null) {
        throw FirebaseAuthException(
          code: 'no-uid',
          message: 'Could not confirm your Google account.',
        );
      }

      final existing = await auth.findCustomerByGoogleUid(uid);
      if (existing != null) {
        await auth.loginAsCustomerViaGoogle(
          googleUid: uid,
          phone: existing['phone'] as String,
          name: existing['name'] as String,
        );
        if (mounted) navigator.pop();
        return;
      }

      // First time this Google account has signed in - one more step to
      // get a delivery phone number. Pre-fill the name from Google so the
      // customer only has to type the phone number.
      if (!mounted) return;
      setState(() {
        _pendingGoogleUid = uid;
        _nameController.text = account.displayName ?? '';
        _isSubmitting = false;
      });
    } on GoogleSignInException catch (e) {
      // "canceled" is ambiguous by the plugin's own admission (see
      // google_sign_in_android's README "Troubleshooting" section): the
      // underlying Android CredentialManager SDK returns this exact code
      // both when the user genuinely backs out of the picker AND when
      // there's a configuration error (wrong/missing SHA, wrong
      // serverClientId, etc.) - the plugin can't tell them apart. Silently
      // swallowing it (as a "user cancelled, nothing to report" no-op)
      // means a real config error looks identical to a normal dismissal,
      // which is exactly what made the underlying bug invisible before -
      // showing it, with the raw code/message, is deliberate so a genuine
      // config problem doesn't hide as "user cancelled" ever again.
      debugPrint('GoogleSignInException: ${e.code} - ${e.description}');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      // "[16] Account reauth failed" is a specific, identified case: Android's
      // AccountManager failing to silently refresh the on-device Google
      // account's auth token (stale after a password/2FA change, or just
      // expired) - nothing to do with this app's config. The picker never
      // even opens when this happens, so there's nothing for the customer to
      // "cancel". Surface the actual fix instead of the raw plugin text.
      final description = e.description ?? '';
      final isStaleAccountReauth = description.toLowerCase().contains(
        'reauth',
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isStaleAccountReauth
                ? 'Could not verify your Google account on this device. '
                      'Please open Settings > Accounts > Google, remove and '
                      're-add the account, then try again.'
                : 'Google sign-in: ${e.code} - ${e.description}',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? 'Could not sign in. Please try again.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      // Catch-all for anything not already handled above (e.g.
      // GoogleSignIn.instance.initialize() itself throwing - a
      // PlatformException from a missing/outdated Play Services, or an
      // OAuth client mismatch). Showing the raw error, not a generic
      // message, is deliberate here: this exact text is what tells us
      // whether it's a config problem (which needs a fix on our end) or
      // a device problem (which the customer needs to resolve, e.g.
      // updating Play Services).
      debugPrint('Google sign-in failed: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not sign in: $e')),
      );
    }
  }

  Future<void> _completePhoneStep() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    if (_pendingGoogleUid == null) return;

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final auth = context.read<AuthProvider>();

    try {
      await auth.loginAsCustomerViaGoogle(
        googleUid: _pendingGoogleUid!,
        phone: _phoneController.text.trim(),
        name: _nameController.text.trim(),
      );
      if (mounted) navigator.pop();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  bool get _firebaseSupported => !kIsWeb && Platform.isAndroid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          _buildHeroBand(context),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: ResponsiveCenter(
                  maxWidth: 420,
                  child: !_firebaseSupported
                      ? _buildUnsupportedPlatform(context)
                      : _pendingGoogleUid != null
                      ? _buildPhoneStep(context)
                      : _buildGoogleSignInStep(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBand(BuildContext context) {
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.brand, AppColors.brandDark],
              ),
            ),
          ),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cream,
                border: Border.all(color: AppColors.gold, width: 2),
              ),
              padding: const EdgeInsets.all(4),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnsupportedPlatform(BuildContext context) {
    // Firebase (Phone/Google) is only registered for Android so far - see
    // the comment in lib/main.dart. Rather than crash on
    // FirebaseAuth.instance with no Firebase app initialized, tell the
    // customer plainly.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.phone_android_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Customer login is currently only available on Android.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }

  Widget _buildGoogleSignInStep(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Log in or sign up',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Continue with your Google account',
          style: textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          onPressed: _isSubmitting ? null : _signInWithGoogle,
          icon: _isSubmitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              // Not Google's actual "G" logo asset (not available to embed
              // here) - a neutral account icon rather than an inaccurate
              // stand-in for Google's trademarked mark.
              : const Icon(Icons.account_circle_outlined, size: 20),
          label: const Text('Continue with Google'),
        ),
        const SizedBox(height: 20),
        Text(
          'By continuing, you agree to our Terms of Service and Privacy Policy.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneStep(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'One last thing',
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'What\'s your delivery phone number?',
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              labelText: 'Phone number',
              hintText: '10-digit mobile number',
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Text(
                  '+91',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Required';
              if (value.trim().length != 10) {
                return 'Enter a valid 10-digit phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.brand,
            ),
            onPressed: _isSubmitting ? null : _completePhoneStep,
            child: _isSubmitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
