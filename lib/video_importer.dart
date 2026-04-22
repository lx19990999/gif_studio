import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'editor_codec.dart';

const double preferredVideoImportFps = 12;
const double minimumVideoImportFps = 0.2;
const int maximumVideoImportFrames = 120;

class VideoImportResult {
  const VideoImportResult({
    required this.frameFiles,
    required this.sampleFps,
    required this.frameDurationMs,
    required this.durationSeconds,
    required this.sourceWidth,
    required this.sourceHeight,
  });

  final List<RasterImportFile> frameFiles;
  final double sampleFps;
  final int frameDurationMs;
  final double durationSeconds;
  final int? sourceWidth;
  final int? sourceHeight;
}

class DesktopVideoImporter {
  static Future<bool> isAvailable() async {
    final ffmpegOk = await _toolAvailable('ffmpeg');
    final ffprobeOk = await _toolAvailable('ffprobe');
    return ffmpegOk && ffprobeOk;
  }

  static double chooseSampleFps({
    required double durationSeconds,
    required double sourceFps,
    double preferredFps = preferredVideoImportFps,
    double minimumFps = minimumVideoImportFps,
    int maximumFrames = maximumVideoImportFrames,
  }) {
    var fps = preferredFps;

    if (sourceFps > 0) {
      fps = math.min(fps, sourceFps);
    }

    if (durationSeconds > 0) {
      fps = math.min(fps, maximumFrames / durationSeconds);
    }

    if (!fps.isFinite || fps <= 0) {
      return preferredFps;
    }

    return fps.clamp(minimumFps, preferredFps);
  }

  static int frameDurationMsForFps(double fps) {
    if (!fps.isFinite || fps <= 0) {
      return 1000 ~/ preferredVideoImportFps;
    }
    return math.max(1, (1000 / fps).round());
  }

  static Future<VideoImportResult> importMp4(String videoPath) async {
    final available = await isAvailable();
    if (!available) {
      throw StateError('未找到 ffmpeg 或 ffprobe。请先确保它们在 PATH 中可用。');
    }

    final metadata = await _probeVideo(videoPath);
    final sampleFps = chooseSampleFps(
      durationSeconds: metadata.durationSeconds,
      sourceFps: metadata.sourceFps,
    );
    final frameDurationMs = frameDurationMsForFps(sampleFps);
    final tempDir = await Directory.systemTemp.createTemp('gif_studio_video_');
    final baseName = _extractFileName(videoPath);
    final outputPattern =
        '${tempDir.path}${Platform.pathSeparator}frame_%05d.png';

    try {
      final result = await Process.run('ffmpeg', [
        '-v',
        'error',
        '-i',
        videoPath,
        '-vf',
        'fps=$sampleFps',
        '-frames:v',
        '$maximumVideoImportFrames',
        '-y',
        outputPattern,
      ]);

      if (result.exitCode != 0) {
        final stderr = (result.stderr ?? '').toString().trim();
        throw StateError(stderr.isEmpty ? 'ffmpeg 抽帧失败。' : stderr);
      }

      final files = await tempDir
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .toList();
      files.sort((left, right) => left.path.compareTo(right.path));

      if (files.isEmpty) {
        throw StateError('没有从视频中提取到任何帧。');
      }

      final frameFiles = <RasterImportFile>[];
      for (var index = 0; index < files.length; index++) {
        final number = index + 1;
        frameFiles.add(
          RasterImportFile(
            name: '${baseName}_frame_${number.toString().padLeft(3, '0')}.png',
            displayLabel: baseName,
            durationMs: frameDurationMs,
            description:
                '从视频 $baseName 抽取第 $number 帧，按 ${sampleFps.toStringAsFixed(2)} FPS 采样',
            bytes: await files[index].readAsBytes(),
          ),
        );
      }

      return VideoImportResult(
        frameFiles: frameFiles,
        sampleFps: sampleFps,
        frameDurationMs: frameDurationMs,
        durationSeconds: metadata.durationSeconds,
        sourceWidth: metadata.width,
        sourceHeight: metadata.height,
      );
    } on ProcessException {
      throw StateError('无法启动 ffmpeg 或 ffprobe。请先确保它们在 PATH 中可用。');
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  static Future<_VideoMetadata> _probeVideo(String videoPath) async {
    final result = await Process.run('ffprobe', [
      '-v',
      'error',
      '-select_streams',
      'v:0',
      '-show_entries',
      'stream=width,height,avg_frame_rate:format=duration',
      '-of',
      'json',
      videoPath,
    ]);

    if (result.exitCode != 0) {
      final stderr = (result.stderr ?? '').toString().trim();
      throw StateError(stderr.isEmpty ? 'ffprobe 读取视频信息失败。' : stderr);
    }

    final payload =
        jsonDecode((result.stdout ?? '').toString()) as Map<String, dynamic>;
    final streams = (payload['streams'] as List<dynamic>? ?? const []);
    final stream = streams.isNotEmpty
        ? streams.first as Map<String, dynamic>
        : const {};
    final format = payload['format'] as Map<String, dynamic>? ?? const {};

    return _VideoMetadata(
      width: _asInt(stream['width']),
      height: _asInt(stream['height']),
      durationSeconds: _asDouble(format['duration']) ?? 0,
      sourceFps: _parseFps(stream['avg_frame_rate']?.toString()),
    );
  }

  static Future<bool> _toolAvailable(String tool) async {
    try {
      final result = await Process.run(tool, ['-version']);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  static double _parseFps(String? raw) {
    if (raw == null || raw.isEmpty) {
      return 0;
    }

    if (!raw.contains('/')) {
      return double.tryParse(raw) ?? 0;
    }

    final parts = raw.split('/');
    if (parts.length != 2) {
      return 0;
    }

    final numerator = double.tryParse(parts[0]) ?? 0;
    final denominator = double.tryParse(parts[1]) ?? 0;
    if (denominator == 0) {
      return 0;
    }

    return numerator / denominator;
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value');
  }

  static double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value');
  }

  static String _extractFileName(String path) {
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isEmpty ? path : segments.last;
  }
}

class _VideoMetadata {
  const _VideoMetadata({
    required this.width,
    required this.height,
    required this.durationSeconds,
    required this.sourceFps,
  });

  final int? width;
  final int? height;
  final double durationSeconds;
  final double sourceFps;
}
