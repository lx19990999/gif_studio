import 'dart:typed_data';

import 'package:flutter/material.dart';

enum EditorFrameFitMode { contain, cover }

class EditorFrame {
  const EditorFrame({
    required this.id,
    required this.name,
    required this.sourceLabel,
    required this.durationMs,
    required this.accent,
    required this.description,
    this.sourceWidth,
    this.sourceHeight,
    this.canvasPreviewBytes,
    this.thumbnailBytes,
    this.exportFrameBytes,
    this.sourceBytes,
    this.fitMode = EditorFrameFitMode.contain,
    this.contentScale = 1,
    this.offsetX = 0,
    this.offsetY = 0,
    this.isPlaceholder = false,
  });

  final String id;
  final String name;
  final String sourceLabel;
  final int durationMs;
  final Color accent;
  final String description;
  final int? sourceWidth;
  final int? sourceHeight;
  final Uint8List? canvasPreviewBytes;
  final Uint8List? thumbnailBytes;
  final Uint8List? exportFrameBytes;
  final Uint8List? sourceBytes;
  final EditorFrameFitMode fitMode;
  final double contentScale;
  final double offsetX;
  final double offsetY;
  final bool isPlaceholder;

  bool get hasRasterData => exportFrameBytes != null;
  bool get canEditTransform => sourceBytes != null;

  String? get sourceSizeLabel {
    if (sourceWidth == null || sourceHeight == null) {
      return null;
    }
    return '${sourceWidth!}×${sourceHeight!}';
  }

  String get fitModeLabel {
    switch (fitMode) {
      case EditorFrameFitMode.contain:
        return '适应';
      case EditorFrameFitMode.cover:
        return '铺满';
    }
  }

  EditorFrame copyWith({
    String? id,
    String? name,
    String? sourceLabel,
    int? durationMs,
    Color? accent,
    String? description,
    int? sourceWidth,
    int? sourceHeight,
    Uint8List? canvasPreviewBytes,
    Uint8List? thumbnailBytes,
    Uint8List? exportFrameBytes,
    Uint8List? sourceBytes,
    EditorFrameFitMode? fitMode,
    double? contentScale,
    double? offsetX,
    double? offsetY,
    bool? isPlaceholder,
  }) {
    return EditorFrame(
      id: id ?? this.id,
      name: name ?? this.name,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      durationMs: durationMs ?? this.durationMs,
      accent: accent ?? this.accent,
      description: description ?? this.description,
      sourceWidth: sourceWidth ?? this.sourceWidth,
      sourceHeight: sourceHeight ?? this.sourceHeight,
      canvasPreviewBytes: canvasPreviewBytes ?? this.canvasPreviewBytes,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
      exportFrameBytes: exportFrameBytes ?? this.exportFrameBytes,
      sourceBytes: sourceBytes ?? this.sourceBytes,
      fitMode: fitMode ?? this.fitMode,
      contentScale: contentScale ?? this.contentScale,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
    );
  }
}
