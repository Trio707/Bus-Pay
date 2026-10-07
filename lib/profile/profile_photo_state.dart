class ProfilePhotoView {
  const ProfilePhotoView({this.updatedAt, this.busy = false});

  final String? updatedAt;
  final bool busy;

  bool get hasPhoto => updatedAt != null && updatedAt!.isNotEmpty;

  ProfilePhotoView uploading() => ProfilePhotoView(updatedAt: updatedAt, busy: true);

  /// A failed upload or delete keeps the photo that is already on the server.
  ProfilePhotoView failed() => ProfilePhotoView(updatedAt: updatedAt);

  ProfilePhotoView saved(String version) => ProfilePhotoView(updatedAt: version);

  ProfilePhotoView removed() => const ProfilePhotoView();
}
