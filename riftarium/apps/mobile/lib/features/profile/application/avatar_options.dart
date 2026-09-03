import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/domain/session.dart';

/// Légendes proposées comme avatar (`GET /api/auth/avatars`).
///
/// `autoDispose` : la liste ne sert qu'à l'écran de modification du profil.
final avatarOptionsProvider = FutureProvider.autoDispose<List<AvatarOption>>((
  ref,
) async {
  final signedIn = ref.watch(
    authControllerProvider.select((state) => state.isSignedIn),
  );
  if (!signedIn) return const [];
  return ref.watch(authApiProvider).avatars();
});
