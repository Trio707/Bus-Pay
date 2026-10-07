import 'dart:io';

import 'package:flutter/material.dart';

bool profilePhotoFileReady(File? file) => file != null && file.existsSync();

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.initials,
    required this.onTap,
    this.file,
    this.busy = false,
  });

  final String initials;
  final VoidCallback? onTap;
  final File? file;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final hasFile = profilePhotoFileReady(file);
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 52,
            backgroundImage: hasFile ? FileImage(file!) : null,
            child: hasFile
                ? null
                : Text(
                    initials,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(
                busy ? Icons.hourglass_top : Icons.camera_alt,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
