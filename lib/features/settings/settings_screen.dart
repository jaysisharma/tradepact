import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tradepact/core/services/auth_service.dart';
import 'package:tradepact/core/services/notification_service.dart';
import 'package:tradepact/core/services/premium_service.dart';
import 'package:tradepact/core/services/profile_repository.dart';
import 'package:tradepact/core/theme/app_theme.dart';

final _appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return 'v${info.version} (${info.buildNumber})';
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final user = authAsync.valueOrNull;
    final versionAsync = ref.watch(_appVersionProvider);
    final isPremium = ref.watch(isPremiumProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null) ...[
            _ProfileCard(
              name: user.displayName ?? 'Trader',
              email: user.email ?? '',
              photoUrl: user.photoURL,
            ),
            const SizedBox(height: 24),
          ],

          // ── Account ────────────────────────────────────────────────────
          const _SectionHeader('Account'),
          _PropFirmTile(),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            subtitle: 'Daily reminders and weekly reports',
            onTap: () => _showNotificationsDialog(context, ref),
          ),

          const SizedBox(height: 16),

          // ── Subscription ───────────────────────────────────────────────
          const _SectionHeader('Subscription'),
          _SettingsTile(
            icon: Icons.workspace_premium,
            label: 'TradePact Pro',
            subtitle: isPremium
                ? 'Active — full access unlocked'
                : 'Unlock AI insights and advanced analytics',
            onTap: isPremium ? () {} : () => context.push('/paywall'),
            trailingColor: AppColors.gold,
            trailing: isPremium
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Active',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : null,
          ),

          const SizedBox(height: 16),

          // ── Support ────────────────────────────────────────────────────
          const _SectionHeader('Support'),
          _SettingsTile(
            icon: Icons.help_outline,
            label: 'Help & FAQ',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            onTap: () {},
          ),

          const SizedBox(height: 16),

          // ── About ──────────────────────────────────────────────────────
          const _SectionHeader('About'),
          _AboutCard(version: versionAsync.valueOrNull ?? '—'),

          const SizedBox(height: 32),

          OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context, ref),
            icon: const Icon(Icons.logout, color: AppColors.loss),
            label: Text(
              'Sign Out',
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.loss),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.loss),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Sign Out', style: AppTextStyles.labelLarge),
        content: const Text(
          'Are you sure you want to sign out?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTextStyles.labelMedium),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sign Out',
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.loss),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await ref.read(premiumServiceProvider).logOut();
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) context.go('/login');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sign out failed. Please try again.'),
            backgroundColor: AppColors.loss,
          ),
        );
      }
    }
  }

  Future<void> _showNotificationsDialog(
      BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Notifications', style: AppTextStyles.labelLarge),
        content: Text(
          'Daily trade reminder at 8 PM and weekly insight every Sunday at 10 AM.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTextStyles.labelMedium),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final svc = ref.read(notificationServiceProvider);
              await svc.requestPermission();
              await svc.scheduleDailyReminder();
              await svc.scheduleWeeklyInsightReminder();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notifications scheduled.'),
                    backgroundColor: AppColors.win,
                  ),
                );
              }
            },
            child: Text(
              'Enable',
              style:
                  AppTextStyles.labelMedium.copyWith(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile card
// ---------------------------------------------------------------------------

class _ProfileCard extends StatelessWidget {
  final String name;
  final String email;
  final String? photoUrl;
  const _ProfileCard(
      {required this.name, required this.email, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.gold.withAlpha(40),
            backgroundImage:
                photoUrl != null ? NetworkImage(photoUrl!) : null,
            child: photoUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'T',
                    style: AppTextStyles.numberMedium
                        .copyWith(color: AppColors.gold),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.labelLarge),
                const SizedBox(height: 2),
                Text(email, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Prop firm tile (shows configured firm name)
// ---------------------------------------------------------------------------

class _PropFirmTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final propFirm = profileAsync.valueOrNull?.propFirm ?? '';
    final subtitle =
        propFirm.isNotEmpty ? propFirm : 'Configure your firm and limits';

    return _SettingsTile(
      icon: Icons.business,
      label: 'Prop Firm Setup',
      subtitle: subtitle,
      onTap: () => context.push('/prop-firm-setup'),
    );
  }
}

// ---------------------------------------------------------------------------
// About card
// ---------------------------------------------------------------------------

class _AboutCard extends StatelessWidget {
  final String version;
  const _AboutCard({required this.version});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Built by', style: AppTextStyles.caption),
              Text('Jaysi Sharma',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.gold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Instagram', style: AppTextStyles.caption),
              Text('@tradepact',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.gold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Version', style: AppTextStyles.caption),
              Text(version, style: AppTextStyles.numberSmall.copyWith(fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.labelSmall
            .copyWith(letterSpacing: 1.5, fontSize: 11),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings tile
// ---------------------------------------------------------------------------

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? trailingColor;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.trailingColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        tileColor: AppColors.surface,
        leading: Icon(icon, color: trailingColor ?? AppColors.textSecondary),
        title: Text(label, style: AppTextStyles.labelMedium),
        subtitle: subtitle != null
            ? Text(subtitle!, style: AppTextStyles.caption)
            : null,
        trailing: trailing ??
            Icon(
              Icons.chevron_right,
              color: trailingColor ?? AppColors.textSecondary,
              size: 20,
            ),
        onTap: onTap,
      ),
    );
  }
}
