import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradepact/core/models/user_profile_model.dart';
import 'package:tradepact/core/services/auth_service.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final userProfileProvider = StreamProvider<UserProfileModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(profileRepositoryProvider).watchProfile(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

class ProfileRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _profileRef(String uid) {
    return _db.collection('users').doc(uid).collection('profile').doc('data');
  }

  Stream<UserProfileModel?> watchProfile(String uid) {
    return _profileRef(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return UserProfileModel.fromJson(snap.data()!, uid);
    });
  }

  Future<void> updateProfile(String uid, UserProfileModel profile) async {
    await _profileRef(uid).set(profile.toJson(), SetOptions(merge: true));
  }
}
