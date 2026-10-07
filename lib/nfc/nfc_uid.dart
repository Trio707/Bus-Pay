import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

String formatUid(Uint8List id) {
  final hex = id
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
  if (hex.length >= 8 && hex.length.isEven) {
    final pairs = <String>[];
    for (var i = 0; i < hex.length; i += 2) {
      pairs.add(hex.substring(i, i + 2));
    }
    return pairs.join(':');
  }
  return hex;
}

String? uidFromTag(NfcTag tag) {
  if (Platform.isAndroid) {
    final android = NfcTagAndroid.from(tag);
    if (android != null) return formatUid(android.id);
  }
  if (Platform.isIOS) {
    final mifare = MiFareIos.from(tag);
    if (mifare != null) return formatUid(mifare.identifier);
  }
  return null;
}

Future<bool> nfcEnabled() async {
  try {
    final availability = await NfcManager.instance.checkAvailability();
    return availability == NfcAvailability.enabled;
  } catch (_) {
    return false;
  }
}

Future<void> stopNfc() async {
  try {
    await NfcManager.instance.stopSession();
  } catch (_) {}
}

Future<String?> readContactlessUid({
  Duration timeout = const Duration(seconds: 25),
}) async {
  if (!await nfcEnabled()) return null;

  final completer = Completer<String?>();
  await NfcManager.instance.startSession(
    pollingOptions: {NfcPollingOption.iso14443},
    onDiscovered: (tag) {
      if (!completer.isCompleted) {
        completer.complete(uidFromTag(tag));
      }
    },
  );

  try {
    return await completer.future.timeout(timeout, onTimeout: () => null);
  } finally {
    await stopNfc();
  }
}

class NfcUidFormatter extends TextInputFormatter {
  const NfcUidFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final hex = newValue.text
        .replaceAll(RegExp(r'[^0-9a-fA-F]'), '')
        .toUpperCase();
    final clipped = hex.length > 20 ? hex.substring(0, 20) : hex;
    return TextEditingValue(
      text: clipped,
      selection: TextSelection.collapsed(offset: clipped.length),
    );
  }
}
