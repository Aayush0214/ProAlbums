import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/permissions/domain/entities/media_permission_status.dart';
import 'package:proalbums/features/permissions/presentation/providers/media_permission_notifier.dart';

/// The ONLY first-run screen. It is not onboarding: the app cannot show a
/// single photo without this permission, so this is a required gate.
///
/// It never navigates by itself. When access is granted the router's
/// `redirect` (see app_router.dart) moves the user to Photos.
class PermissionPage extends ConsumerStatefulWidget {
  const PermissionPage({super.key});

  @override
  ConsumerState<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends ConsumerState<PermissionPage> {
  // Ephemeral UI state (not business logic), so it lives in the widget.
  bool _askedOnce = false;

  Future<void> _requestAccess() async {
    setState(() => _askedOnce = true);
    await ref.read(mediaPermissionProvider.notifier).request();
  }

  @override
  Widget build(BuildContext context) {
    final permission = ref.watch(mediaPermissionProvider);
    final notifier = ref.read(mediaPermissionProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: permission.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _PermissionContent(
            icon: Icons.error_outline,
            title: 'Something went wrong',
            message: error is Failure ? error.message : 'Please try again.',
            primaryLabel: 'Try again',
            onPrimary: notifier.refresh,
          ),
          data: (status) => switch (status) {
            MediaPermissionStatus.restricted => const _PermissionContent(
                icon: Icons.lock_outline,
                title: 'Access is restricted',
                message: 'Photo access is blocked on this device, for example '
                    'by parental controls.',
              ),
            MediaPermissionStatus.denied when _askedOnce => _PermissionContent(
                icon: Icons.photo_library_outlined,
                title: 'Permission needed',
                message: 'Photo access is turned off. Open Settings and allow '
                    'access to photos and videos.',
                primaryLabel: 'Open Settings',
                onPrimary: notifier.openSettings,
                secondaryLabel: 'Try again',
                onSecondary: _requestAccess,
              ),
            // notDetermined / first denied check. (granted and limited never
            // stay here, the router redirects them to Photos.)
            _ => _PermissionContent(
                icon: Icons.photo_library_outlined,
                title: 'Allow access to your photos',
                message: 'ProAlbums needs access to show and organize the '
                    'photos and videos on this device.',
                primaryLabel: 'Allow access',
                onPrimary: _requestAccess,
              ),
          },
        ),
      ),
    );
  }
}

class _PermissionContent extends StatelessWidget {
  const _PermissionContent({
    required this.icon,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accentTintedSurface,
              ),
              child: SizedBox(
                width: 96,
                height: 96,
                child: Icon(icon, size: 44, color: colors.activeAccent),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            if (primaryLabel case final label?) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: onPrimary, child: Text(label)),
              ),
            ],
            if (secondaryLabel case final label?) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onSecondary, child: Text(label)),
            ],
          ],
        ),
      ),
    );
  }
}
