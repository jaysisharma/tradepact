import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tradepact/core/models/user_profile_model.dart';
import 'package:tradepact/core/services/auth_service.dart';
import 'package:tradepact/core/services/profile_repository.dart';
import 'package:tradepact/core/theme/app_theme.dart';

class PropFirmSetupScreen extends ConsumerStatefulWidget {
  const PropFirmSetupScreen({super.key});

  @override
  ConsumerState<PropFirmSetupScreen> createState() =>
      _PropFirmSetupScreenState();
}

class _PropFirmSetupScreenState extends ConsumerState<PropFirmSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _propFirmCtrl = TextEditingController();
  final _accountSizeCtrl = TextEditingController();
  final _dailyLossCtrl = TextEditingController();
  final _maxDrawdownCtrl = TextEditingController();

  bool _saving = false;
  bool _loaded = false;

  @override
  void dispose() {
    _propFirmCtrl.dispose();
    _accountSizeCtrl.dispose();
    _dailyLossCtrl.dispose();
    _maxDrawdownCtrl.dispose();
    super.dispose();
  }

  void _prefill(UserProfileModel? profile) {
    if (_loaded || profile == null) return;
    _loaded = true;
    _propFirmCtrl.text = profile.propFirm;
    if (profile.accountSize > 0) {
      _accountSizeCtrl.text = profile.accountSize.toStringAsFixed(0);
    }
    if (profile.dailyLossLimit > 0) {
      _dailyLossCtrl.text = profile.dailyLossLimit.toStringAsFixed(0);
    }
    if (profile.maxDrawdown > 0) {
      _maxDrawdownCtrl.text = profile.maxDrawdown.toStringAsFixed(0);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    setState(() => _saving = true);

    final profile = UserProfileModel(
      uid: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
      propFirm: _propFirmCtrl.text.trim(),
      accountSize: double.tryParse(_accountSizeCtrl.text) ?? 0,
      dailyLossLimit: double.tryParse(_dailyLossCtrl.text) ?? 0,
      maxDrawdown: double.tryParse(_maxDrawdownCtrl.text) ?? 0,
    );

    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(user.uid, profile);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.loss,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    profileAsync.whenData(_prefill);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Prop Firm Setup')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('Firm Details'),
              const SizedBox(height: 12),
              _Field(
                controller: _propFirmCtrl,
                label: 'Prop Firm Name',
                hint: 'e.g. Funding Pips, FTMO',
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _accountSizeCtrl,
                label: 'Account Size (\$)',
                hint: 'e.g. 100000',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _validatePositiveNumber,
              ),
              const SizedBox(height: 24),
              const _SectionLabel('Risk Limits'),
              const SizedBox(height: 12),
              _Field(
                controller: _dailyLossCtrl,
                label: 'Daily Loss Limit (\$)',
                hint: 'e.g. 500',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _validatePositiveNumber,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _maxDrawdownCtrl,
                label: 'Max Drawdown (\$)',
                hint: 'e.g. 1000',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _validatePositiveNumber,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.background,
                        ),
                      )
                    : const Text('Save'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String? _validatePositiveNumber(String? value) {
    if (value == null || value.isEmpty) return null; // optional field
    final n = double.tryParse(value);
    if (n == null || n <= 0) return 'Enter an amount greater than zero';
    return null;
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.labelSmall.copyWith(
        letterSpacing: 1.5,
        fontSize: 11,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: AppTextStyles.labelMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }
}
