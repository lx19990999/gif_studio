import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'editor_frame.dart';

const int editorCanvasWidth = 800;
const int editorCanvasHeight = 600;
const int timelineThumbnailWidth = 180;
const int timelineThumbnailHeight = 135;

typedef CanvasThumbnailSize = ({int width, int height});

class RasterImportFile {
  const RasterImportFile({
    required this.name,
    required this.bytes,
    this.displayLabel,
    this.durationMs,
    this.description,
  });

  final String name;
  final Uint8List bytes;
  final String? displayLabel;
  final int? durationMs;
  final String? description;
}

class FrameImportResult {
  const FrameImportResult({
    required this.frames,
    required this.rejectedFiles,
    required this.failureDetails,
  });

  final List<EditorFrame> frames;
  final List<String> rejectedFiles;
  final List<ImportFailureDetail> failureDetails;
}

class ImportFailureDetail {
  const ImportFailureDetail({required this.fileName, required this.reason});

  final String fileName;
  final String reason;
}

class GifImportResult {
  const GifImportResult({
    required this.frames,
    required this.loopPlayback,
    required this.sourceWidth,
    required this.sourceHeight,
  });

  final List<EditorFrame> frames;
  final bool loopPlayback;
  final int sourceWidth;
  final int sourceHeight;
}

class GifExportFrameData {
  const GifExportFrameData({required this.bytes, required this.durationMs});

  final Uint8List bytes;
  final int durationMs;
}

enum GifExportQualityPreset { draft, balanced, best }

class GifProjectCodec {
  static final _canvasBackground = img.ColorRgba8(248, 245, 238, 255);

  static FrameImportResult importRasterFiles(
    List<RasterImportFile> files, {
    int canvasWidth = editorCanvasWidth,
    int canvasHeight = editorCanvasHeight,
  }) {
    final frames = <EditorFrame>[];
    final rejectedFiles = <String>[];
    final failureDetails = <ImportFailureDetail>[];

    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      final frameNumber = frames.length + 1;
      EditorFrame? frame;
      try {
        frame = createFrameFromSource(
          id: 'frame-${frameNumber.toString().padLeft(2, '0')}',
          name: 'Frame ${frameNumber.toString().padLeft(2, '0')}',
          sourceLabel: file.displayLabel ?? file.name,
          sourceName: file.name,
          sourceBytes: file.bytes,
          durationMs: file.durationMs ?? 320 + index * 90,
          description: file.description ?? '导入自 ${file.name}，可继续调整构图',
          canvasWidth: canvasWidth,
          canvasHeight: canvasHeight,
        );
      } catch (error) {
        frame = null;
        failureDetails.add(
          ImportFailureDetail(
            fileName: file.name,
            reason: 'createFrameFromSource threw: $error',
          ),
        );
      }

      if (frame == null) {
        rejectedFiles.add(file.name);
        if (!failureDetails.any((detail) => detail.fileName == file.name)) {
          failureDetails.add(
            ImportFailureDetail(
              fileName: file.name,
              reason:
                  'Decoder returned null or no renderable frame was produced.',
            ),
          );
        }
        continue;
      }

      frames.add(frame);
    }

    return FrameImportResult(
      frames: frames,
      rejectedFiles: rejectedFiles,
      failureDetails: failureDetails,
    );
  }

  static GifImportResult? importGifFile(
    RasterImportFile file, {
    int? canvasWidth,
    int? canvasHeight,
  }) {
    img.Image? decoded;
    try {
      decoded = img.decodeGif(file.bytes);
    } catch (_) {
      decoded = null;
    }

    if (decoded == null || decoded.numFrames == 0) {
      return null;
    }

    final targetCanvasWidth = canvasWidth ?? decoded.width;
    final targetCanvasHeight = canvasHeight ?? decoded.height;

    final frames = <EditorFrame>[];
    for (var index = 0; index < decoded.frames.length; index++) {
      final gifFrame = decoded.frames[index];
      final frameNumber = index + 1;
      final frameSourceBytes = img.encodePng(gifFrame, level: 3);
      final frame = createFrameFromSource(
        id: 'frame-${frameNumber.toString().padLeft(2, '0')}',
        name: 'Frame ${frameNumber.toString().padLeft(2, '0')}',
        sourceLabel: file.name,
        sourceName: 'gif_frame_${frameNumber.toString().padLeft(2, '0')}.png',
        sourceBytes: frameSourceBytes,
        durationMs: math.max(10, gifFrame.frameDuration),
        description: '从 ${file.name} 的第 $frameNumber 帧导入，可继续调整构图',
        canvasWidth: targetCanvasWidth,
        canvasHeight: targetCanvasHeight,
      );

      if (frame != null) {
        frames.add(frame);
      }
    }

    if (frames.isEmpty) {
      return null;
    }

    return GifImportResult(
      frames: frames,
      loopPlayback: decoded.loopCount == 0,
      sourceWidth: decoded.width,
      sourceHeight: decoded.height,
    );
  }

  static EditorFrame? createFrameFromSource({
    required String id,
    required String name,
    required String sourceLabel,
    required String sourceName,
    required Uint8List sourceBytes,
    required int durationMs,
    required String description,
    EditorFrameFitMode fitMode = EditorFrameFitMode.contain,
    double contentScale = 1,
    double offsetX = 0,
    double offsetY = 0,
    int canvasWidth = editorCanvasWidth,
    int canvasHeight = editorCanvasHeight,
  }) {
    final decoded = _decodeNamedSource(sourceName, sourceBytes);
    if (decoded == null) {
      return null;
    }

    final frame = EditorFrame(
      id: id,
      name: name,
      sourceLabel: sourceLabel,
      durationMs: durationMs,
      accent: _sampleAccent(decoded),
      description: description,
      sourceBytes: sourceBytes,
      fitMode: fitMode,
      contentScale: contentScale,
      offsetX: offsetX,
      offsetY: offsetY,
      isPlaceholder: false,
    );

    return _renderFrameData(
      frame,
      decoded,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
    );
  }

  static EditorFrame? replaceFrameSource(
    EditorFrame frame,
    RasterImportFile file, {
    int canvasWidth = editorCanvasWidth,
    int canvasHeight = editorCanvasHeight,
  }) {
    return createFrameFromSource(
      id: frame.id,
      name: frame.name,
      sourceLabel: file.displayLabel ?? file.name,
      sourceName: file.name,
      sourceBytes: file.bytes,
      durationMs: frame.durationMs,
      description: file.description ?? '已替换为 ${file.name}，当前构图已重置',
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
    );
  }

  static EditorFrame rerenderFrame(
    EditorFrame frame, {
    int canvasWidth = editorCanvasWidth,
    int canvasHeight = editorCanvasHeight,
  }) {
    if (frame.sourceBytes == null) {
      return frame;
    }

    final decoded = _decodeNamedSource(frame.sourceLabel, frame.sourceBytes!);
    if (decoded == null) {
      return frame;
    }

    return _renderFrameData(
      frame,
      decoded,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
    );
  }

  static Uint8List encodeGif(
    List<EditorFrame> frames, {
    required bool loopPlayback,
    GifExportQualityPreset quality = GifExportQualityPreset.balanced,
    double scaleFactor = 1,
  }) {
    if (frames.isEmpty) {
      throw StateError('没有可导出的帧。');
    }

    if (frames.any((frame) => !frame.hasRasterData)) {
      throw StateError('当前项目仍包含未替换素材的占位帧。');
    }

    final exportFrames = frames
        .map(
          (frame) => GifExportFrameData(
            bytes: frame.exportFrameBytes!,
            durationMs: frame.durationMs,
          ),
        )
        .toList();

    return encodeGifFrameData(
      exportFrames,
      loopPlayback: loopPlayback,
      quality: quality,
      scaleFactor: scaleFactor,
    );
  }

  static Uint8List encodeGifFrameData(
    List<GifExportFrameData> frames, {
    required bool loopPlayback,
    GifExportQualityPreset quality = GifExportQualityPreset.balanced,
    double scaleFactor = 1,
  }) {
    if (frames.isEmpty) {
      throw StateError('没有可导出的帧。');
    }

    final encoder = _buildGifEncoder(
      loopPlayback: loopPlayback,
      quality: quality,
    );

    for (final frame in frames) {
      var decoded = img.decodeImage(frame.bytes);
      if (decoded == null) {
        throw StateError('遇到无法解码的导出帧。');
      }

      if (scaleFactor > 0 && scaleFactor != 1) {
        final resizedWidth = math.max(1, (decoded.width * scaleFactor).round());
        final resizedHeight = math.max(
          1,
          (decoded.height * scaleFactor).round(),
        );
        decoded = img.copyResize(
          decoded,
          width: resizedWidth,
          height: resizedHeight,
          interpolation: img.Interpolation.average,
        );
      }

      encoder.addFrame(
        decoded,
        duration: math.max(1, (frame.durationMs / 10).round()),
      );
    }

    final encoded = encoder.finish();
    if (encoded == null) {
      throw StateError('GIF 编码失败。');
    }
    return encoded;
  }

  static img.GifEncoder _buildGifEncoder({
    required bool loopPlayback,
    required GifExportQualityPreset quality,
  }) {
    return switch (quality) {
      GifExportQualityPreset.draft => img.GifEncoder(
        repeat: loopPlayback ? 0 : 1,
        numColors: 64,
        quantizerType: img.QuantizerType.binary,
        dither: img.DitherKernel.none,
      ),
      GifExportQualityPreset.balanced => img.GifEncoder(
        repeat: loopPlayback ? 0 : 1,
        numColors: 128,
        quantizerType: img.QuantizerType.neural,
        samplingFactor: 10,
        dither: img.DitherKernel.none,
      ),
      GifExportQualityPreset.best => img.GifEncoder(
        repeat: loopPlayback ? 0 : 1,
        numColors: 256,
        quantizerType: img.QuantizerType.neural,
        samplingFactor: 8,
        dither: img.DitherKernel.floydSteinberg,
        ditherSerpentine: true,
      ),
    };
  }

  static img.Image? _decodeNamedSource(String name, Uint8List bytes) {
    try {
      return img.decodeNamedImage(name, bytes) ?? img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
  }

  static EditorFrame _renderFrameData(
    EditorFrame frame,
    img.Image source, {
    required int canvasWidth,
    required int canvasHeight,
  }) {
    final thumbnailSize = _thumbnailSizeForCanvas(canvasWidth, canvasHeight);
    final canvasImage = _renderCanvas(
      source,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      fitMode: frame.fitMode,
      contentScale: frame.contentScale,
      offsetX: frame.offsetX,
      offsetY: frame.offsetY,
    );
    final thumbnailImage = _renderCanvas(
      source,
      canvasWidth: thumbnailSize.width,
      canvasHeight: thumbnailSize.height,
      fitMode: frame.fitMode,
      contentScale: frame.contentScale,
      offsetX: frame.offsetX,
      offsetY: frame.offsetY,
    );

    return frame.copyWith(
      accent: _sampleAccent(source),
      sourceWidth: source.width,
      sourceHeight: source.height,
      canvasPreviewBytes: img.encodePng(canvasImage, level: 3),
      thumbnailBytes: img.encodePng(thumbnailImage, level: 3),
      exportFrameBytes: img.encodePng(canvasImage, level: 3),
      isPlaceholder: false,
    );
  }

  static CanvasThumbnailSize _thumbnailSizeForCanvas(
    int canvasWidth,
    int canvasHeight,
  ) {
    var width = timelineThumbnailWidth;
    var height = (width * canvasHeight / canvasWidth).round();

    if (height > timelineThumbnailHeight) {
      height = timelineThumbnailHeight;
      width = (height * canvasWidth / canvasHeight).round();
    }

    return (width: math.max(1, width), height: math.max(1, height));
  }

  static img.Image _renderCanvas(
    img.Image source, {
    required int canvasWidth,
    required int canvasHeight,
    required EditorFrameFitMode fitMode,
    required double contentScale,
    required double offsetX,
    required double offsetY,
  }) {
    final canvas = img.Image(
      width: canvasWidth,
      height: canvasHeight,
      numChannels: 4,
    )..clear(_canvasBackground);

    if (source.width <= 0 || source.height <= 0) {
      return canvas;
    }

    final scaleX = canvasWidth / source.width;
    final scaleY = canvasHeight / source.height;
    final baseScale = switch (fitMode) {
      EditorFrameFitMode.contain => math.min(scaleX, scaleY),
      EditorFrameFitMode.cover => math.max(scaleX, scaleY),
    };
    final finalScale = math.max(0.05, baseScale * contentScale);
    final targetWidth = math.max(1, (source.width * finalScale).round());
    final targetHeight = math.max(1, (source.height * finalScale).round());
    final resized = img.copyResize(
      source,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.average,
    );

    final dstX = ((canvasWidth - targetWidth) / 2 + offsetX * canvasWidth * 0.5)
        .round();
    final dstY =
        ((canvasHeight - targetHeight) / 2 + offsetY * canvasHeight * 0.5)
            .round();
    img.compositeImage(canvas, resized, dstX: dstX, dstY: dstY);

    return canvas;
  }

  static Color _sampleAccent(img.Image image) {
    final pixel = image.getPixelSafe(image.width ~/ 2, image.height ~/ 2);
    return Color.fromARGB(
      255,
      pixel.r.clamp(0, 255).round(),
      pixel.g.clamp(0, 255).round(),
      pixel.b.clamp(0, 255).round(),
    );
  }
}
