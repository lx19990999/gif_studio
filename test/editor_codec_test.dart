import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gif_studio/editor_codec.dart';
import 'package:gif_studio/editor_frame.dart';
import 'package:image/image.dart' as img;

void main() {
  group('GifProjectCodec', () {
    test('imports raster files into exportable frames', () {
      final result = GifProjectCodec.importRasterFiles([
        RasterImportFile(
          name: 'first.png',
          bytes: _makePng(
            width: 160,
            height: 120,
            color: img.ColorRgba8(220, 38, 38, 255),
          ),
        ),
        RasterImportFile(
          name: 'second.png',
          bytes: _makePng(
            width: 96,
            height: 160,
            color: img.ColorRgba8(37, 99, 235, 255),
          ),
        ),
        RasterImportFile(
          name: 'broken.bin',
          bytes: Uint8List.fromList([1, 2, 3, 4]),
        ),
      ]);

      expect(result.frames, hasLength(2));
      expect(result.rejectedFiles, ['broken.bin']);

      final firstFrame = result.frames.first;
      expect(firstFrame.hasRasterData, isTrue);
      expect(firstFrame.sourceBytes, isNotNull);
      expect(firstFrame.sourceLabel, 'first.png');

      final preview = img.decodePng(firstFrame.canvasPreviewBytes!);
      final thumbnail = img.decodePng(firstFrame.thumbnailBytes!);

      expect(preview?.width, editorCanvasWidth);
      expect(preview?.height, editorCanvasHeight);
      expect(thumbnail?.width, timelineThumbnailWidth);
      expect(thumbnail?.height, timelineThumbnailHeight);
    });

    test('encodes imported frames into an animated gif', () {
      final frames = GifProjectCodec.importRasterFiles([
        RasterImportFile(
          name: 'first.png',
          bytes: _makePng(
            width: 180,
            height: 120,
            color: img.ColorRgba8(16, 185, 129, 255),
          ),
        ),
        RasterImportFile(
          name: 'second.png',
          bytes: _makePng(
            width: 180,
            height: 120,
            color: img.ColorRgba8(251, 146, 60, 255),
          ),
        ),
      ]).frames;

      final gifBytes = GifProjectCodec.encodeGif(frames, loopPlayback: true);

      final decoded = img.decodeGif(gifBytes);

      expect(decoded, isNotNull);
      expect(decoded?.width, editorCanvasWidth);
      expect(decoded?.height, editorCanvasHeight);
      expect(decoded?.numFrames, 2);
      expect(decoded?.loopCount, 0);
      expect(decoded?.frames.first.frameDuration, frames.first.durationMs);
    });

    test('encodes gif with selectable quality presets', () {
      final frames = GifProjectCodec.importRasterFiles([
        RasterImportFile(
          name: 'first.png',
          bytes: _makePng(
            width: 180,
            height: 120,
            color: img.ColorRgba8(16, 185, 129, 255),
          ),
        ),
      ]).frames;

      final draft = GifProjectCodec.encodeGif(
        frames,
        loopPlayback: true,
        quality: GifExportQualityPreset.draft,
      );
      final best = GifProjectCodec.encodeGif(
        frames,
        loopPlayback: true,
        quality: GifExportQualityPreset.best,
      );

      expect(draft, isNotEmpty);
      expect(best, isNotEmpty);
    });

    test('encodes gif with export scale factor', () {
      final frames = GifProjectCodec.importRasterFiles([
        RasterImportFile(
          name: 'scaled.png',
          bytes: _makePng(
            width: 200,
            height: 100,
            color: img.ColorRgba8(80, 120, 240, 255),
          ),
        ),
      ]).frames;

      final gifBytes = GifProjectCodec.encodeGif(
        frames,
        loopPlayback: true,
        scaleFactor: 0.5,
      );

      final decoded = img.decodeGif(gifBytes);

      expect(decoded, isNotNull);
      expect(decoded?.width, editorCanvasWidth ~/ 2);
      expect(decoded?.height, editorCanvasHeight ~/ 2);
    });

    test('rerenderFrame applies contain and cover composition', () {
      final result = GifProjectCodec.importRasterFiles([
        RasterImportFile(
          name: 'portrait.png',
          bytes: _makePng(
            width: 120,
            height: 240,
            color: img.ColorRgba8(200, 32, 32, 255),
          ),
        ),
      ]);

      final containFrame = result.frames.single;
      final containImage = img.decodePng(containFrame.exportFrameBytes!);
      final containCorner = containImage!.getPixel(0, 0);

      expect(containCorner.r.round(), 248);
      expect(containCorner.g.round(), 245);
      expect(containCorner.b.round(), 238);

      final coverFrame = GifProjectCodec.rerenderFrame(
        containFrame.copyWith(fitMode: EditorFrameFitMode.cover),
      );
      final coverImage = img.decodePng(coverFrame.exportFrameBytes!);
      final coverCorner = coverImage!.getPixel(0, 0);

      expect(coverCorner.r.round(), greaterThan(150));
      expect(coverCorner.g.round(), lessThan(80));
      expect(coverCorner.b.round(), lessThan(80));
    });

    test('rerenderFrame can target a different canvas size', () {
      final result = GifProjectCodec.importRasterFiles([
        RasterImportFile(
          name: 'landscape.png',
          bytes: _makePng(
            width: 300,
            height: 150,
            color: img.ColorRgba8(32, 160, 96, 255),
          ),
        ),
      ]);

      final resizedFrame = GifProjectCodec.rerenderFrame(
        result.frames.single,
        canvasWidth: 512,
        canvasHeight: 512,
      );

      final preview = img.decodePng(resizedFrame.canvasPreviewBytes!);

      expect(preview?.width, 512);
      expect(preview?.height, 512);
    });

    test('imports gif frames and preserves timing and loop flag', () {
      final gifBytes = _makeGif(
        frames: [
          (
            _makeSolidImage(
              width: 120,
              height: 120,
              color: img.ColorRgba8(124, 58, 237, 255),
            ),
            15,
          ),
          (
            _makeSolidImage(
              width: 120,
              height: 120,
              color: img.ColorRgba8(245, 158, 11, 255),
            ),
            32,
          ),
        ],
        repeat: 1,
      );

      final result = GifProjectCodec.importGifFile(
        RasterImportFile(name: 'sample.gif', bytes: gifBytes),
      );

      expect(result, isNotNull);
      final imported = result!;
      expect(imported.loopPlayback, isFalse);
      expect(imported.sourceWidth, 120);
      expect(imported.sourceHeight, 120);
      expect(imported.frames, hasLength(2));
      expect(imported.frames.first.sourceLabel, 'sample.gif');
      expect(imported.frames.first.durationMs, 150);
      expect(imported.frames.last.durationMs, 320);
      expect(imported.frames.first.hasRasterData, isTrue);
      expect(
        img.decodePng(imported.frames.first.canvasPreviewBytes!)?.width,
        120,
      );
      expect(
        img.decodePng(imported.frames.first.canvasPreviewBytes!)?.height,
        120,
      );
    });

    test('imports gif frames using an explicit target canvas size', () {
      final gifBytes = _makeGif(
        frames: [
          (
            _makeSolidImage(
              width: 120,
              height: 120,
              color: img.ColorRgba8(32, 96, 220, 255),
            ),
            20,
          ),
        ],
        repeat: 0,
      );

      final result = GifProjectCodec.importGifFile(
        RasterImportFile(name: 'sized.gif', bytes: gifBytes),
        canvasWidth: 960,
        canvasHeight: 540,
      );

      expect(result, isNotNull);
      final preview = img.decodePng(result!.frames.single.canvasPreviewBytes!);
      expect(preview?.width, 960);
      expect(preview?.height, 540);
    });
  });
}

Uint8List _makePng({
  required int width,
  required int height,
  required img.Color color,
}) {
  final image = _makeSolidImage(width: width, height: height, color: color);
  return img.encodePng(image);
}

img.Image _makeSolidImage({
  required int width,
  required int height,
  required img.Color color,
}) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  img.fill(image, color: color);
  return image;
}

Uint8List _makeGif({
  required List<(img.Image, int)> frames,
  required int repeat,
}) {
  final encoder = img.GifEncoder(repeat: repeat);
  for (final frame in frames) {
    encoder.addFrame(frame.$1, duration: frame.$2);
  }
  return encoder.finish()!;
}
