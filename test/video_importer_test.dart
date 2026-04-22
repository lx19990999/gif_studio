import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gif_studio/editor_codec.dart';
import 'package:gif_studio/video_importer.dart';

void main() {
  group('DesktopVideoImporter', () {
    test('chooses sampling fps within frame budget', () {
      final fps = DesktopVideoImporter.chooseSampleFps(
        durationSeconds: 20,
        sourceFps: 30,
      );

      expect(fps, closeTo(6, 0.001));
      expect(DesktopVideoImporter.frameDurationMsForFps(fps), 167);
    });

    test('imports mp4 into raster files when ffmpeg is available', () async {
      if (!await DesktopVideoImporter.isAvailable()) {
        return;
      }

      final tempDir = await Directory.systemTemp.createTemp(
        'gif_studio_video_test_',
      );
      final videoPath = '${tempDir.path}${Platform.pathSeparator}clip.mp4';

      try {
        final createResult = await Process.run('ffmpeg', [
          '-v',
          'error',
          '-f',
          'lavfi',
          '-i',
          'testsrc=duration=1:size=160x120:rate=6',
          '-pix_fmt',
          'yuv420p',
          '-y',
          videoPath,
        ]);

        expect(createResult.exitCode, 0, reason: '${createResult.stderr}');

        final importResult = await DesktopVideoImporter.importMp4(videoPath);
        final frames = GifProjectCodec.importRasterFiles(
          importResult.frameFiles,
        );

        expect(importResult.frameFiles, isNotEmpty);
        expect(importResult.sampleFps, lessThanOrEqualTo(6.0));
        expect(importResult.frameDurationMs, greaterThan(0));
        expect(frames.frames, isNotEmpty);
        expect(frames.frames.first.hasRasterData, isTrue);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
