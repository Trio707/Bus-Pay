import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/login_id.dart';
import '../l10n/strings.dart';
import '../profile/profile_avatar.dart';
import '../profile/profile_photo_cache.dart';
import '../profile/profile_photo_state.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController name = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _loaded = false;
  ProfilePhotoView _photo = const ProfilePhotoView();
  File? _photoFile;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final app = AppScope.of(context);
    name.text = app.displayName;
    email.text = app.displayEmail;
    phone.text = app.displayPhone;
    _photo = ProfilePhotoView(updatedAt: app.profilePhotoUpdatedAt);
    _loadCachedPhoto();
  }

  String get _userId => AppScope.of(context).currentUser?.id ?? '';

  Future<void> _loadCachedPhoto() async {
    final version = _photo.updatedAt;
    final userId = _userId;
    final token = AppScope.of(context).authToken;
    if (version == null || userId.isEmpty) return;
    final cached = await ProfilePhotoCache.fileFor(userId, version);
    if (cached.existsSync()) {
      if (mounted) setState(() => _photoFile = cached);
      return;
    }
    if (token == null || token.isEmpty) return;
    try {
      final bytes = await ApiService.downloadProfilePhoto(token: token);
      if (bytes == null || !mounted) return;
      await ProfilePhotoCache.remember(userId, version, bytes);
      final file = await ProfilePhotoCache.fileFor(userId, version);
      if (mounted) setState(() => _photoFile = file);
    } catch (_) {}
  }

  Future<void> _choose(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    await _upload(bytes);
  }

  Future<void> _upload(List<int> bytes) async {
    final app = AppScope.of(context);
    final token = app.authToken;
    final previous = _photoFile;
    if (token == null || token.isEmpty) return;
    setState(() => _photo = _photo.uploading());
    try {
      final data = await ApiService.uploadProfilePhoto(token: token, bytes: bytes);
      final version = (data['profilePhotoUpdatedAt'] ?? '').toString();
      if (version.isEmpty) throw ApiException(S(app.language).photoUploadFailed);
      await ProfilePhotoCache.remember(_userId, version, bytes);
      final file = await ProfilePhotoCache.fileFor(_userId, version);
      if (!mounted) return;
      app.setProfilePhotoVersion(version);
      setState(() {
        _photo = _photo.saved(version);
        _photoFile = file;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S(app.language).photoUpdated)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _photo = _photo.failed();
        _photoFile = previous;
      });
      final message = error is ApiException ? error.message : S(app.language).photoUploadFailed;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _remove() async {
    final app = AppScope.of(context);
    final token = app.authToken;
    final previous = _photoFile;
    final previousView = _photo;
    if (token == null || token.isEmpty) return;
    setState(() => _photo = _photo.uploading());
    try {
      await ApiService.deleteProfilePhoto(token: token);
      await ProfilePhotoCache.forget(_userId);
      if (!mounted) return;
      app.setProfilePhotoVersion(null);
      setState(() {
        _photo = _photo.removed();
        _photoFile = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S(app.language).photoRemoved)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _photo = previousView.failed();
        _photoFile = previous;
      });
      final message = error is ApiException ? error.message : S(app.language).photoUploadFailed;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openMenu() async {
    final s = S(AppScope.of(context).language);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(s.takePhoto),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(s.chooseGallery),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (_photo.hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(s.removePhoto),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(s.isSw ? 'Ghairi' : 'Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'camera') {
      await _choose(ImageSource.camera);
    } else if (action == 'gallery') {
      await _choose(ImageSource.gallery);
    } else if (action == 'remove') {
      await _remove();
    }
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = S(app.language);
    final initials = _initials(app.displayName);
    final idLabel = app.currentRole == UserRole.agent
        ? (s.isSw ? 'Kitambulisho cha wakala' : 'Agent ID')
        : s.conductorId;
    final nameLabel =
        app.currentRole == UserRole.agent ? s.agent : s.conductor;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Column(
            children: [
              ProfileAvatar(
                initials: initials,
                file: _photoFile,
                busy: _photo.busy,
                onTap: _openMenu,
              ),
              if (_photo.busy) ...[
                const SizedBox(height: 8),
                Text(s.uploadingPhoto),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            app.displayId,
            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: name,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: nameLabel,
            prefixIcon: const Icon(Icons.badge_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          enabled: false,
          initialValue: app.displayId,
          decoration: InputDecoration(
            labelText: idLabel,
            prefixIcon: const Icon(Icons.fingerprint),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: s.email,
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: s.mobile,
            prefixIcon: const Icon(Icons.phone_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: () {
              app.updateProfile(
                name: name.text,
                email: email.text,
                phone: phone.text,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(s.success)),
              );
            },
            child: Text(
              s.save,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'C';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
