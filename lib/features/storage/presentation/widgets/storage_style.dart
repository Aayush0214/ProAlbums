import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/storage/domain/entities/storage_usage.dart';

/// Colour, name and icon of each kind of storage, in one place so the card,
/// the ring and the grid always agree.
Color storageColorOf(StorageKind kind, BuildContext context) => switch (kind) {
  StorageKind.photos => AppColors.storagePhotos,
  StorageKind.videos => AppColors.storageVideos,
  StorageKind.screenshots => AppColors.storageScreenshots,
  StorageKind.trash => AppColors.storageTrash,
  StorageKind.hidden => AppColors.storageHidden,
  StorageKind.other => AppColors.storageOther,
  // Free space: green ("safe"), clearly different from the grey "Other".
  StorageKind.free => AppColors.vaultEmerald,
  StorageKind.camera => AppColors.storageCamera,
  StorageKind.whatsapp => AppColors.storageWhatsapp,
  StorageKind.downloads => AppColors.storageDownloads,
};

String storageLabelOf(StorageKind kind) => switch (kind) {
  StorageKind.photos => 'Photos',
  StorageKind.videos => 'Videos',
  StorageKind.screenshots => 'Screenshots',
  StorageKind.trash => 'Recently deleted',
  StorageKind.hidden => 'Hidden',
  StorageKind.other => 'Other',
  StorageKind.free => 'Free',
  StorageKind.camera => 'Camera',
  StorageKind.whatsapp => 'WhatsApp',
  StorageKind.downloads => 'Downloads',
};

IconData storageIconOf(StorageKind kind) => switch (kind) {
  StorageKind.photos => LucideIcons.image,
  StorageKind.videos => LucideIcons.video,
  StorageKind.screenshots => LucideIcons.smartphone,
  StorageKind.trash => LucideIcons.trash2,
  StorageKind.hidden => LucideIcons.eyeOff,
  StorageKind.other => LucideIcons.hardDrive,
  StorageKind.free => LucideIcons.database,
  StorageKind.camera => LucideIcons.camera,
  StorageKind.whatsapp => LucideIcons.messageCircle,
  StorageKind.downloads => LucideIcons.download,
};
