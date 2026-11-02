import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../errors/app_failure.dart';

class PositionEvidence {
  const PositionEvidence(this.position, this.status);
  final Map<String, dynamic>? position;
  final String status;
}

abstract interface class EvidenceSensors {
  Future<PositionEvidence> location({required bool ignored});
  Future<Uint8List> selfie();
}

class NativeEvidenceSensors implements EvidenceSensors {
  @override
  Future<PositionEvidence> location({required bool ignored}) async {
    if (ignored) {
      return const PositionEvidence(null, 'dispensada_pela_politica');
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const PositionEvidence(null, 'servico_desligado');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const PositionEvidence(null, 'permissao_negada');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!position.latitude.isFinite ||
          !position.longitude.isFinite ||
          !position.accuracy.isFinite ||
          position.accuracy < 0) {
        return const PositionEvidence(null, 'captura_invalida');
      }
      return PositionEvidence({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'precisao_metros': position.accuracy,
      }, position.accuracy > 100 ? 'baixa_precisao' : 'capturada');
    } on TimeoutException {
      return const PositionEvidence(null, 'tempo_esgotado');
    } catch (_) {
      return const PositionEvidence(null, 'indisponivel');
    }
  }

  @override
  Future<Uint8List> selfie() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (photo == null) {
        throw const AppFailure(
          'Captura cancelada. A marcação ainda não foi salva.',
        );
      }
      return await compute(prepareSelfie, await photo.readAsBytes());
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'Não foi possível usar a câmera. Verifique a permissão e tente novamente.',
      );
    }
  }

  Future<List<XFile>> lostPhotos() async {
    if (!Platform.isAndroid) return [];
    final response = await ImagePicker().retrieveLostData();
    return response.files ?? [];
  }
}

Uint8List prepareSelfie(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.numFrames != 1) {
    throw const AppFailure('A câmera retornou uma imagem inválida.');
  }
  var photo = img.bakeOrientation(decoded);
  if (photo.width > 1600 || photo.height > 1600) {
    photo = img.copyResize(
      photo,
      width: photo.width >= photo.height ? 1600 : null,
      height: photo.height > photo.width ? 1600 : null,
    );
  }
  final result = Uint8List.fromList(img.encodeJpg(photo, quality: 85));
  if (result.length > 2 * 1024 * 1024) {
    throw const AppFailure('A selfie excedeu 2 MiB. Faça outra captura.');
  }
  return result;
}
