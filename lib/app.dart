import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'editor_codec.dart';
import 'editor_frame.dart';
import 'video_importer.dart';

class GifStudioApp extends StatelessWidget {
  const GifStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Gif Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: baseScheme,
        scaffoldBackgroundColor: const Color(0xFFF6F1E8),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.82),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const GifStudioHomePage(),
    );
  }
}

class GifStudioHomePage extends StatefulWidget {
  const GifStudioHomePage({super.key});

  @override
  State<GifStudioHomePage> createState() => _GifStudioHomePageState();
}

class _GifStudioHomePageState extends State<GifStudioHomePage> {
  static const List<Color> _palette = [
    Color(0xFF148F77),
    Color(0xFFD97706),
    Color(0xFF0F4C81),
    Color(0xFFB45309),
    Color(0xFF7C3AED),
    Color(0xFFBE123C),
    Color(0xFF0E7490),
  ];

  static const XTypeGroup _imageTypeGroup = XTypeGroup(
    label: 'Images',
    extensions: ['jpg', 'jpeg', 'png', 'bmp', 'webp'],
  );

  static const XTypeGroup _gifTypeGroup = XTypeGroup(
    label: 'GIF',
    extensions: ['gif'],
  );

  static const XTypeGroup _videoTypeGroup = XTypeGroup(
    label: 'MP4',
    extensions: ['mp4'],
  );

  late final List<EditorFrame> _frames = _buildInitialFrames();
  int _selectedIndex = 0;
  Set<int> _selectedIndices = {0};
  int _selectionAnchorIndex = 0;
  int _canvasWidth = editorCanvasWidth;
  int _canvasHeight = editorCanvasHeight;
  bool _showPreviewGrid = true;
  bool _loopPlayback = true;
  bool _isBusy = false;
  double _zoom = 1.0;
  GifExportQualityPreset _exportQuality = GifExportQualityPreset.balanced;
  double _exportScaleFactor = 1.0;
  String _statusText = '示例项目已就绪，可导入图片或直接打开 GIF。';

  EditorFrame get _selectedFrame => _frames[_selectedIndex];

  int get _totalDurationMs =>
      _frames.fold<int>(0, (total, frame) => total + frame.durationMs);

  String get _canvasLabel => '$_canvasWidth×$_canvasHeight';

  List<int> get _sortedSelectedIndices {
    final sorted = _selectedIndices.toList()..sort();
    return sorted;
  }

  int get _selectedCount => _selectedIndices.length;

  bool get _hasMultipleSelection => _selectedIndices.length > 1;

  bool get _selectedFramesShareDuration {
    if (_selectedIndices.isEmpty) {
      return true;
    }
    final firstDuration = _frames[_sortedSelectedIndices.first].durationMs;
    return _sortedSelectedIndices.every(
      (index) => _frames[index].durationMs == firstDuration,
    );
  }

  String get _selectedDurationSummary => _selectedFramesShareDuration
      ? '${_frames[_sortedSelectedIndices.first].durationMs} ms'
      : '多种时长';

  bool get _canDeleteCurrentSelection =>
      _frames.length > 1 && _selectedIndices.length < _frames.length;

  bool get _isPlaceholderProject =>
      _frames.isEmpty || _frames.every((frame) => !frame.hasRasterData);

  bool get _canExportGif =>
      _frames.isNotEmpty && _frames.every((frame) => frame.hasRasterData);

  List<EditorFrame> _buildInitialFrames() {
    return [
      const EditorFrame(
        id: 'frame-01',
        name: 'Frame 01',
        sourceLabel: 'hero_01.png',
        durationMs: 320,
        accent: Color(0xFF148F77),
        description: '首帧，轻微淡入',
        isPlaceholder: true,
      ),
      const EditorFrame(
        id: 'frame-02',
        name: 'Frame 02',
        sourceLabel: 'hero_02.png',
        durationMs: 500,
        accent: Color(0xFFD97706),
        description: '主体停留，保留高光',
        isPlaceholder: true,
      ),
      const EditorFrame(
        id: 'frame-03',
        name: 'Frame 03',
        sourceLabel: 'overlay_title.webp',
        durationMs: 780,
        accent: Color(0xFF0F4C81),
        description: '叠加标题和字幕区域',
        isPlaceholder: true,
      ),
      const EditorFrame(
        id: 'frame-04',
        name: 'Frame 04',
        sourceLabel: 'transition.bmp',
        durationMs: 640,
        accent: Color(0xFFB45309),
        description: '转场帧，准备切入下个镜头',
        isPlaceholder: true,
      ),
      const EditorFrame(
        id: 'frame-05',
        name: 'Frame 05',
        sourceLabel: 'clip_001.jpg',
        durationMs: 860,
        accent: Color(0xFF7C3AED),
        description: '取自视频的关键画面',
        isPlaceholder: true,
      ),
      const EditorFrame(
        id: 'frame-06',
        name: 'Frame 06',
        sourceLabel: 'outro.png',
        durationMs: 980,
        accent: Color(0xFFBE123C),
        description: '尾帧，准备循环播放',
        isPlaceholder: true,
      ),
    ];
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
  }

  void _showComingSoon(String action) {
    _showInfo('$action 已预留入口，后续继续接入。');
  }

  void _logInfo(String message) {
    debugPrint('[GifStudio] $message');
  }

  void _logError(String context, Object error, StackTrace stackTrace) {
    debugPrint('[GifStudio][ERROR] $context: $error');
    debugPrintStack(
      label: '[GifStudio][STACK] $context',
      stackTrace: stackTrace,
    );
  }

  void _applyImportedFrames({
    required List<EditorFrame> frames,
    required bool loopPlayback,
    required String statusText,
    int? canvasWidth,
    int? canvasHeight,
  }) {
    setState(() {
      _frames
        ..clear()
        ..addAll(frames);
      _selectedIndex = 0;
      _selectedIndices = frames.isEmpty ? <int>{} : {0};
      _selectionAnchorIndex = 0;
      if (canvasWidth != null) {
        _canvasWidth = canvasWidth;
      }
      if (canvasHeight != null) {
        _canvasHeight = canvasHeight;
      }
      _zoom = 1.0;
      _showPreviewGrid = true;
      _loopPlayback = loopPlayback;
      _statusText = statusText;
    });
  }

  void _resetProject() {
    setState(() {
      _frames
        ..clear()
        ..addAll(_buildInitialFrames());
      _selectedIndex = 0;
      _selectedIndices = {0};
      _selectionAnchorIndex = 0;
      _canvasWidth = editorCanvasWidth;
      _canvasHeight = editorCanvasHeight;
      _showPreviewGrid = true;
      _loopPlayback = true;
      _zoom = 1.0;
      _statusText = '已重置为示例项目。';
    });
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case '新建项目':
        _resetProject();
        return;
      case '打开 GIF':
        if (!_isBusy) {
          await _openGif();
        }
        return;
      case '导出 GIF':
        if (_canExportGif && !_isBusy) {
          await _exportGif();
        } else {
          _showError('当前项目仍包含占位帧，先导入图片或删除空白帧。');
        }
        return;
      case '复制帧':
        if (!_isBusy) {
          _duplicateSelectedFrame();
        }
        return;
      case '删除帧':
        if (!_isBusy) {
          _removeSelectedFrame();
        }
        return;
      case '导入图片':
        if (!_isBusy) {
          await _importImages();
        }
        return;
      case '导入 MP4':
        if (!_isBusy) {
          await _importVideo();
        }
        return;
      case '画布设置':
        if (!_isBusy) {
          await _openCanvasSettings();
        }
        return;
      default:
        _showComingSoon(action);
    }
  }

  void _rerenderSelectedFrame(EditorFrame frame, {String? statusText}) {
    final rendered = GifProjectCodec.rerenderFrame(
      frame,
      canvasWidth: _canvasWidth,
      canvasHeight: _canvasHeight,
    );
    setState(() {
      _frames[_selectedIndex] = rendered;
      if (statusText != null) {
        _statusText = statusText;
      }
    });
  }

  bool get _isToggleSelectionPressed {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
  }

  bool get _isRangeSelectionPressed {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
  }

  void _selectFrame(int index) {
    final rangeSelection = _isRangeSelectionPressed;
    final toggleSelection = _isToggleSelectionPressed;

    if (rangeSelection && _frames.isNotEmpty) {
      final start = _selectionAnchorIndex < index
          ? _selectionAnchorIndex
          : index;
      final end = _selectionAnchorIndex > index ? _selectionAnchorIndex : index;
      setState(() {
        _selectedIndices = {
          for (var current = start; current <= end; current++) current,
        };
        _selectedIndex = index;
      });
      return;
    }

    if (toggleSelection) {
      final nextSelection = {..._selectedIndices};
      if (nextSelection.contains(index)) {
        if (nextSelection.length == 1) {
          return;
        }
        nextSelection.remove(index);
      } else {
        nextSelection.add(index);
      }

      final sorted = nextSelection.toList()..sort();
      setState(() {
        _selectedIndices = nextSelection;
        _selectedIndex = nextSelection.contains(index) ? index : sorted.first;
        _selectionAnchorIndex = _selectedIndex;
      });
      return;
    }

    setState(() {
      _selectedIndices = {index};
      _selectedIndex = index;
      _selectionAnchorIndex = index;
    });
  }

  void _keepOnlyPrimarySelection() {
    setState(() {
      _selectedIndices = {_selectedIndex};
      _selectionAnchorIndex = _selectedIndex;
      _statusText = '已退出多选。';
    });
  }

  void _selectAllFrames() {
    if (_frames.isEmpty) {
      return;
    }

    setState(() {
      _selectedIndices = {
        for (var index = 0; index < _frames.length; index++) index,
      };
      _selectedIndex = _selectedIndices.contains(_selectedIndex)
          ? _selectedIndex
          : 0;
      _selectionAnchorIndex = _selectedIndex;
      _statusText = '已全选 ${_frames.length} 帧。';
    });
  }

  void _updateSelectedFramesDuration(int durationMs) {
    final clampedDuration = durationMs.clamp(10, 5000);
    final indices = _sortedSelectedIndices;

    setState(() {
      for (final index in indices) {
        _frames[index] = _frames[index].copyWith(durationMs: clampedDuration);
      }
      _statusText = indices.length == 1
          ? '已将 ${_frames[_selectedIndex].name} 设为 $clampedDuration ms。'
          : '已将选中 ${indices.length} 帧统一设为 $clampedDuration ms。';
    });
  }

  void _adjustSelectedFramesDuration(int deltaMs) {
    final indices = _sortedSelectedIndices;

    setState(() {
      for (final index in indices) {
        final nextDuration = (_frames[index].durationMs + deltaMs).clamp(
          10,
          5000,
        );
        _frames[index] = _frames[index].copyWith(durationMs: nextDuration);
      }
      _statusText = indices.length == 1
          ? '已调整 ${_frames[_selectedIndex].name} 的时长。'
          : '已批量调整 ${indices.length} 帧的时长。';
    });
  }

  void _setSelectedFrameFitMode(EditorFrameFitMode fitMode) {
    if (_hasMultipleSelection || !_selectedFrame.canEditTransform) {
      return;
    }

    _rerenderSelectedFrame(
      _selectedFrame.copyWith(fitMode: fitMode),
      statusText:
          '已将 ${_selectedFrame.name} 切换为${fitMode == EditorFrameFitMode.contain ? '适应' : '铺满'}画布。',
    );
  }

  void _setSelectedFrameContentScale(double scale) {
    if (_hasMultipleSelection || !_selectedFrame.canEditTransform) {
      return;
    }

    _rerenderSelectedFrame(_selectedFrame.copyWith(contentScale: scale));
  }

  void _setSelectedFrameOffsetX(double offsetX) {
    if (_hasMultipleSelection || !_selectedFrame.canEditTransform) {
      return;
    }

    _rerenderSelectedFrame(_selectedFrame.copyWith(offsetX: offsetX));
  }

  void _setSelectedFrameOffsetY(double offsetY) {
    if (_hasMultipleSelection || !_selectedFrame.canEditTransform) {
      return;
    }

    _rerenderSelectedFrame(_selectedFrame.copyWith(offsetY: offsetY));
  }

  void _resetSelectedFrameTransform() {
    if (_hasMultipleSelection || !_selectedFrame.canEditTransform) {
      return;
    }

    _rerenderSelectedFrame(
      _selectedFrame.copyWith(
        fitMode: EditorFrameFitMode.contain,
        contentScale: 1,
        offsetX: 0,
        offsetY: 0,
      ),
      statusText: '已重置 ${_selectedFrame.name} 的构图。',
    );
  }

  Future<void> _openCanvasSettings() async {
    final result = await _showCanvasSettingsDialog(
      context: context,
      initialWidth: _canvasWidth,
      initialHeight: _canvasHeight,
    );

    if (!mounted || result == null) {
      return;
    }

    final rerenderedFrames = _frames
        .map(
          (frame) => GifProjectCodec.rerenderFrame(
            frame,
            canvasWidth: result.width,
            canvasHeight: result.height,
          ),
        )
        .toList();

    setState(() {
      _canvasWidth = result.width;
      _canvasHeight = result.height;
      _frames
        ..clear()
        ..addAll(rerenderedFrames);
      _statusText = '已更新项目画布为 ${result.width}×${result.height}。';
    });

    _showInfo('项目画布已更新为 ${result.width}×${result.height}。');
  }

  void _addFrame() {
    final frameNumber = _frames.length + 1;
    final accent = _palette[_frames.length % _palette.length];
    final newFrame = EditorFrame(
      id: 'frame-$frameNumber',
      name: 'Frame ${frameNumber.toString().padLeft(2, '0')}',
      sourceLabel: 'empty_${frameNumber.toString().padLeft(2, '0')}.png',
      durationMs: 420 + (_frames.length * 30),
      accent: accent,
      description: '新建空白帧，导出前请替换素材',
      isPlaceholder: true,
    );

    setState(() {
      _frames.add(newFrame);
      _selectedIndex = _frames.length - 1;
      _selectedIndices = {_selectedIndex};
      _selectionAnchorIndex = _selectedIndex;
      _statusText = '已新增空白帧，导出功能暂不可用。';
    });
  }

  void _duplicateSelectedFrame() {
    if (_hasMultipleSelection) {
      return;
    }

    final source = _selectedFrame;
    final copyIndex = _selectedIndex + 1;
    final frameNumber = copyIndex + 1;
    final copy = source.copyWith(
      id: '${source.id}-copy-$copyIndex',
      name: 'Frame ${frameNumber.toString().padLeft(2, '0')}',
      description: '从 ${source.name} 复制而来',
    );

    setState(() {
      _frames.insert(copyIndex, copy);
      _selectedIndex = copyIndex;
      _selectedIndices = {copyIndex};
      _selectionAnchorIndex = copyIndex;
      _statusText = '已复制 ${source.name}。';
    });
  }

  void _removeSelectedFrame() {
    if (!_canDeleteCurrentSelection) {
      return;
    }

    final selectedIndices = _sortedSelectedIndices;
    final removedCount = selectedIndices.length;
    final removedName = _selectedFrame.name;
    final nextIndex = selectedIndices.first;

    setState(() {
      for (final index in selectedIndices.reversed) {
        _frames.removeAt(index);
      }

      _selectedIndex = nextIndex.clamp(0, _frames.length - 1);
      _selectedIndices = {_selectedIndex};
      _selectionAnchorIndex = _selectedIndex;
      if (_selectedIndex >= _frames.length) {
        _selectedIndex = _frames.length - 1;
      }
      _statusText = removedCount == 1
          ? '已删除 $removedName。'
          : '已删除 $removedCount 帧。';
    });
  }

  void _moveSelectedFrame(int direction) {
    if (_hasMultipleSelection) {
      return;
    }

    final targetIndex = _selectedIndex + direction;
    if (targetIndex < 0 || targetIndex >= _frames.length) {
      return;
    }

    setState(() {
      final current = _frames.removeAt(_selectedIndex);
      _frames.insert(targetIndex, current);
      _selectedIndex = targetIndex;
      _selectedIndices = {targetIndex};
      _selectionAnchorIndex = targetIndex;
      _statusText = '已调整 ${current.name} 的顺序。';
    });
  }

  Future<void> _importImages() async {
    setState(() {
      _isBusy = true;
      _statusText = '正在读取图片...';
    });
    _logInfo('Import images requested. canvas=$_canvasLabel');

    try {
      final files = await openFiles(
        acceptedTypeGroups: const [_imageTypeGroup],
        confirmButtonText: '导入图片',
      );
      _logInfo('File picker returned ${files.length} file(s).');

      if (files.isEmpty) {
        _logInfo('Import images canceled or no file selected.');
      }

      if (!mounted || files.isEmpty) {
        return;
      }

      final rasterFiles = <RasterImportFile>[];
      final readFailures = <String>[];
      for (final file in files) {
        try {
          _logInfo('Reading image file: name=${file.name}, path=${file.path}');
          final bytes = await file.readAsBytes();
          _logInfo('Read image file ${file.name}: ${bytes.length} bytes');
          rasterFiles.add(RasterImportFile(name: file.name, bytes: bytes));
        } catch (error, stackTrace) {
          readFailures.add(file.name);
          _logError(
            'Reading image file failed for ${file.name}',
            error,
            stackTrace,
          );
        }
      }

      if (rasterFiles.isEmpty) {
        setState(() {
          _statusText = '没有可导入的图片。';
        });
        _showError('所选文件均读取失败，请查看控制台日志。');
        return;
      }

      final canvasWidth = _canvasWidth;
      final canvasHeight = _canvasHeight;
      _logInfo(
        'Starting background image import for ${rasterFiles.length} readable file(s). targetCanvas=${canvasWidth}x$canvasHeight',
      );
      final result = await compute(
        _runRasterImport,
        _RasterImportRequest(
          files: rasterFiles,
          canvasWidth: canvasWidth,
          canvasHeight: canvasHeight,
        ),
      );
      _logInfo(
        'Background image import finished. frames=${result.frames.length}, rejected=${result.rejectedFiles.length}, readFailures=${readFailures.length}',
      );
      for (final failure in result.failureDetails) {
        _logInfo(
          'Rejected image file ${failure.fileName}. reason=${failure.reason}',
        );
      }
      if (!mounted) {
        return;
      }

      if (result.frames.isEmpty) {
        setState(() {
          _statusText = '没有可导入的图片。';
        });
        final rejectedSummary = [
          ...readFailures.map((name) => '$name: read failed'),
          ...result.failureDetails.map(
            (failure) => '${failure.fileName}: ${failure.reason}',
          ),
        ].join(' | ');
        _logInfo('Import images produced no frames. details=$rejectedSummary');
        _showError('没有成功解码任何图片文件。');
        return;
      }

      _applyImportedFrames(
        frames: result.frames,
        loopPlayback: true,
        statusText: result.rejectedFiles.isEmpty
            ? '已导入 ${result.frames.length} 张图片。'
            : '已导入 ${result.frames.length} 张图片，跳过 ${result.rejectedFiles.length} 个文件。',
      );

      final rejectedCount = result.rejectedFiles.length + readFailures.length;
      if (rejectedCount == 0) {
        _showInfo('已导入 ${result.frames.length} 张图片。');
      } else {
        _showInfo(
          '已导入 ${result.frames.length} 张图片，跳过 $rejectedCount 个无法解码的文件。',
        );
      }
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = '导入失败。';
      });
      _logError('Import images failed', error, stackTrace);
      _showError('导入图片失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _openGif() async {
    setState(() {
      _isBusy = true;
      _statusText = '正在读取 GIF...';
    });
    _logInfo('Open GIF requested. canvas=$_canvasLabel');

    try {
      final file = await openFile(
        acceptedTypeGroups: const [_gifTypeGroup],
        confirmButtonText: '打开 GIF',
      );
      _logInfo(
        file == null
            ? 'Open GIF canceled.'
            : 'Open GIF selected: name=${file.name}, path=${file.path}',
      );

      if (!mounted || file == null) {
        return;
      }

      final adoptGifCanvas = _isPlaceholderProject;
      final canvasWidth = _canvasWidth;
      final canvasHeight = _canvasHeight;
      final gifFile = RasterImportFile(
        name: file.name,
        bytes: await file.readAsBytes(),
      );
      _logInfo('Read GIF file ${file.name}: ${gifFile.bytes.length} bytes');
      final result = await compute(
        _runGifImport,
        _GifImportRequest(
          file: gifFile,
          canvasWidth: adoptGifCanvas ? null : canvasWidth,
          canvasHeight: adoptGifCanvas ? null : canvasHeight,
        ),
      );
      _logInfo(
        'GIF import finished. frames=${result?.frames.length ?? 0}, adoptCanvas=$adoptGifCanvas',
      );

      if (!mounted) {
        return;
      }

      if (result == null || result.frames.isEmpty) {
        setState(() {
          _statusText = 'GIF 打开失败。';
        });
        _showError('无法解析这个 GIF 文件。');
        return;
      }

      _applyImportedFrames(
        frames: result.frames,
        loopPlayback: true,
        statusText: adoptGifCanvas
            ? '已打开 ${file.name}，共 ${result.frames.length} 帧，画布已切换为 ${result.sourceWidth}×${result.sourceHeight}。'
            : '已打开 ${file.name}，共 ${result.frames.length} 帧，默认循环播放开启。',
        canvasWidth: adoptGifCanvas ? result.sourceWidth : null,
        canvasHeight: adoptGifCanvas ? result.sourceHeight : null,
      );
      _showInfo(
        adoptGifCanvas
            ? '已打开 ${file.name}，并将画布设为 ${result.sourceWidth}×${result.sourceHeight}。'
            : '已打开 ${file.name}。',
      );
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = 'GIF 打开失败。';
      });
      _logError('Open GIF failed', error, stackTrace);
      _showError('打开 GIF 失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _importVideo() async {
    setState(() {
      _isBusy = true;
      _statusText = '正在读取 MP4...';
    });
    _logInfo('Import MP4 requested. canvas=$_canvasLabel');

    try {
      final file = await openFile(
        acceptedTypeGroups: const [_videoTypeGroup],
        confirmButtonText: '导入 MP4',
      );
      _logInfo(
        file == null
            ? 'Import MP4 canceled.'
            : 'Import MP4 selected: name=${file.name}, path=${file.path}',
      );

      if (!mounted || file == null) {
        return;
      }

      final result = await DesktopVideoImporter.importMp4(file.path);
      _logInfo(
        'Video extraction finished. source=${result.sourceWidth}x${result.sourceHeight}, duration=${result.durationSeconds}, sampleFps=${result.sampleFps}, frames=${result.frameFiles.length}',
      );
      if (!mounted) {
        return;
      }

      final adoptVideoCanvas =
          _isPlaceholderProject &&
          result.sourceWidth != null &&
          result.sourceHeight != null;
      final targetCanvasWidth = adoptVideoCanvas
          ? result.sourceWidth!
          : _canvasWidth;
      final targetCanvasHeight = adoptVideoCanvas
          ? result.sourceHeight!
          : _canvasHeight;
      final imported = await compute(
        _runRasterImport,
        _RasterImportRequest(
          files: result.frameFiles,
          canvasWidth: targetCanvasWidth,
          canvasHeight: targetCanvasHeight,
        ),
      );
      _logInfo(
        'Background MP4 frame import finished. frames=${imported.frames.length}, rejected=${imported.rejectedFiles.length}',
      );
      if (imported.frames.isEmpty) {
        setState(() {
          _statusText = 'MP4 导入失败。';
        });
        _showError('没有从视频中提取到可用帧。');
        return;
      }

      _applyImportedFrames(
        frames: imported.frames,
        loopPlayback: true,
        statusText: adoptVideoCanvas
            ? '已导入 ${file.name}，共 ${imported.frames.length} 帧，画布已切换为 $targetCanvasWidth×$targetCanvasHeight。'
            : '已导入 ${file.name}，共 ${imported.frames.length} 帧，采样 ${result.sampleFps.toStringAsFixed(2)} FPS。',
        canvasWidth: adoptVideoCanvas ? targetCanvasWidth : null,
        canvasHeight: adoptVideoCanvas ? targetCanvasHeight : null,
      );
      _showInfo(
        adoptVideoCanvas
            ? '已从 ${file.name} 提取 ${imported.frames.length} 帧，并将画布设为 $targetCanvasWidth×$targetCanvasHeight。'
            : '已从 ${file.name} 提取 ${imported.frames.length} 帧，单帧时长 ${result.frameDurationMs} ms。',
      );
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = 'MP4 导入失败。';
      });
      _logError('Import MP4 failed', error, stackTrace);
      _showError('导入 MP4 失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _exportGif() async {
    if (!_canExportGif) {
      _showError('当前项目仍包含占位帧，导出前请先替换或删除。');
      return;
    }

    setState(() {
      _isBusy = true;
      _statusText = '正在编码 GIF...';
    });
    _logInfo(
      'Export GIF requested. frames=${_frames.length}, loop=$_loopPlayback, canvas=$_canvasLabel, quality=$_exportQuality, scale=$_exportScaleFactor',
    );

    try {
      final exportFrames = _frames
          .map(
            (frame) => GifExportFrameData(
              bytes: frame.exportFrameBytes!,
              durationMs: frame.durationMs,
            ),
          )
          .toList();

      final selectedSettings = await _showGifExportSettingsDialog(
        context: context,
        initialQuality: _exportQuality,
        initialScaleFactor: _exportScaleFactor,
        canvasWidth: _canvasWidth,
        canvasHeight: _canvasHeight,
        loopPlayback: _loopPlayback,
        exportFrames: exportFrames,
      );
      _logInfo(
        selectedSettings == null
            ? 'Export GIF settings selection canceled.'
            : 'Export GIF settings selected: quality=${selectedSettings.quality}, scale=${selectedSettings.scaleFactor}',
      );

      if (!mounted || selectedSettings == null) {
        return;
      }

      final location = await getSaveLocation(
        acceptedTypeGroups: const [_gifTypeGroup],
        suggestedName: 'animation.gif',
        confirmButtonText: '导出 GIF',
      );
      _logInfo(
        location == null
            ? 'Export GIF canceled.'
            : 'Export GIF target selected: path=${location.path}',
      );

      if (!mounted || location == null) {
        return;
      }

      _logInfo(
        'Starting background GIF encoding. exportFrames=${exportFrames.length}, quality=${selectedSettings.quality}, scale=${selectedSettings.scaleFactor}',
      );
      final gifBytes = await compute(
        _runGifExport,
        _GifExportRequest(
          frames: exportFrames,
          loopPlayback: _loopPlayback,
          quality: selectedSettings.quality,
          scaleFactor: selectedSettings.scaleFactor,
        ),
      );
      _logInfo('Background GIF encoding finished. bytes=${gifBytes.length}');

      final outputPath = _ensureGifExtension(location.path);
      await File(outputPath).writeAsBytes(gifBytes, flush: true);
      _logInfo('GIF bytes written to $outputPath');

      if (!mounted) {
        return;
      }

      final savedName = _extractFileName(outputPath);
      setState(() {
        _exportQuality = selectedSettings.quality;
        _exportScaleFactor = selectedSettings.scaleFactor;
        _statusText = '已导出 $savedName。';
      });
      _showInfo('GIF 已导出到 $savedName');
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = '导出失败。';
      });
      _logError('Export GIF failed', error, stackTrace);
      _showError('导出 GIF 失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _replaceSelectedFrameSource() async {
    if (_hasMultipleSelection) {
      return;
    }

    setState(() {
      _isBusy = true;
      _statusText = '正在替换当前帧素材...';
    });
    _logInfo(
      'Replace current frame source requested for ${_selectedFrame.name}.',
    );

    try {
      final file = await openFile(
        acceptedTypeGroups: const [_imageTypeGroup],
        confirmButtonText: '替换当前帧',
      );
      _logInfo(
        file == null
            ? 'Replace frame source canceled.'
            : 'Replace frame source selected: name=${file.name}, path=${file.path}',
      );

      if (!mounted || file == null) {
        return;
      }

      final selectedFrame = _selectedFrame;
      final canvasWidth = _canvasWidth;
      final canvasHeight = _canvasHeight;
      final replacementFile = RasterImportFile(
        name: file.name,
        bytes: await file.readAsBytes(),
      );
      _logInfo(
        'Read replacement image file ${file.name}: ${replacementFile.bytes.length} bytes',
      );
      final updated = await compute(
        _runReplaceFrameSource,
        _ReplaceFrameSourceRequest(
          frameId: selectedFrame.id,
          frameName: selectedFrame.name,
          durationMs: selectedFrame.durationMs,
          file: replacementFile,
          canvasWidth: canvasWidth,
          canvasHeight: canvasHeight,
        ),
      );

      if (!mounted) {
        return;
      }

      if (updated == null) {
        setState(() {
          _statusText = '替换素材失败。';
        });
        _showError('无法读取新的图片素材。');
        return;
      }

      setState(() {
        _frames[_selectedIndex] = updated;
        _statusText = '已替换 ${updated.name} 的素材。';
      });
      _showInfo('已替换当前帧素材为 ${file.name}。');
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = '替换素材失败。';
      });
      _logError('Replace frame source failed', error, stackTrace);
      _showError('替换素材失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  String _ensureGifExtension(String path) {
    if (path.toLowerCase().endsWith('.gif')) {
      return path;
    }
    return '$path.gif';
  }

  String _extractFileName(String path) {
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isEmpty ? path : segments.last;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyA, control: true):
            _selectAllFrames,
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
            _selectAllFrames,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF7F1E7),
                  Color(0xFFEEF7F5),
                  Color(0xFFF9F4EC),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _TopToolbar(
                    onMenuAction: _handleMenuAction,
                    onImportImages: _isBusy ? null : _importImages,
                    onOpenGif: _isBusy ? null : _openGif,
                    onImportVideo: _isBusy ? null : _importVideo,
                    onExportGif: _isBusy || !_canExportGif ? null : _exportGif,
                    onAddFrame: _isBusy ? null : _addFrame,
                    isBusy: _isBusy,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 1080;

                          if (isCompact) {
                            final timelinePanel = SizedBox(
                              height: constraints.maxHeight < 640
                                  ? 320
                                  : (constraints.maxHeight * 0.42).clamp(
                                      180.0,
                                      280.0,
                                    ),
                              child: _TimelinePanel(
                                frames: _frames,
                                selectedIndices: _selectedIndices,
                                primarySelectedIndex: _selectedIndex,
                                totalDurationMs: _totalDurationMs,
                                selectedCount: _selectedCount,
                                hasMultipleSelection: _hasMultipleSelection,
                                canDeleteSelection: _canDeleteCurrentSelection,
                                onDeleteSelection: _removeSelectedFrame,
                                onAdjustSelectedDuration:
                                    _adjustSelectedFramesDuration,
                                onKeepOnlyPrimarySelection:
                                    _keepOnlyPrimarySelection,
                                onSelectFrame: _selectFrame,
                              ),
                            );

                            final editorPanel = _EditorPanel(
                              frame: _selectedFrame,
                              selectedCount: _selectedCount,
                              selectedDurationSummary: _selectedDurationSummary,
                              hasMultipleSelection: _hasMultipleSelection,
                              frameIndex: _selectedIndex,
                              frameCount: _frames.length,
                              canvasWidth: _canvasWidth,
                              canvasHeight: _canvasHeight,
                              zoom: _zoom,
                              showPreviewGrid: _showPreviewGrid,
                              canMoveUp:
                                  !_hasMultipleSelection && _selectedIndex > 0,
                              canMoveDown:
                                  !_hasMultipleSelection &&
                                  _selectedIndex < _frames.length - 1,
                              canRemove: _canDeleteCurrentSelection,
                              onDurationChanged: (value) {
                                _updateSelectedFramesDuration(value.round());
                              },
                              onZoomChanged: (value) {
                                setState(() {
                                  _zoom = value;
                                });
                              },
                              onToggleGrid: () {
                                setState(() {
                                  _showPreviewGrid = !_showPreviewGrid;
                                });
                              },
                              onToggleLoop: () {
                                setState(() {
                                  _loopPlayback = !_loopPlayback;
                                });
                              },
                              loopPlayback: _loopPlayback,
                              onMoveFrameUp: () => _moveSelectedFrame(-1),
                              onMoveFrameDown: () => _moveSelectedFrame(1),
                              onDuplicateFrame: _duplicateSelectedFrame,
                              onRemoveFrame: _removeSelectedFrame,
                              onFitModeChanged: _setSelectedFrameFitMode,
                              onContentScaleChanged:
                                  _setSelectedFrameContentScale,
                              onOffsetXChanged: _setSelectedFrameOffsetX,
                              onOffsetYChanged: _setSelectedFrameOffsetY,
                              onResetTransform: _resetSelectedFrameTransform,
                              onReplaceFrameSource: _isBusy
                                  ? null
                                  : _replaceSelectedFrameSource,
                              onBatchAdjustDuration:
                                  _adjustSelectedFramesDuration,
                              onKeepOnlyPrimarySelection:
                                  _keepOnlyPrimarySelection,
                            );

                            if (constraints.maxHeight < 640) {
                              return ListView(
                                children: [
                                  timelinePanel,
                                  const SizedBox(height: 16),
                                  SizedBox(height: 760, child: editorPanel),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                timelinePanel,
                                const SizedBox(height: 16),
                                Expanded(child: editorPanel),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: 320,
                                child: _TimelinePanel(
                                  frames: _frames,
                                  selectedIndices: _selectedIndices,
                                  primarySelectedIndex: _selectedIndex,
                                  totalDurationMs: _totalDurationMs,
                                  selectedCount: _selectedCount,
                                  hasMultipleSelection: _hasMultipleSelection,
                                  canDeleteSelection:
                                      _canDeleteCurrentSelection,
                                  onDeleteSelection: _removeSelectedFrame,
                                  onAdjustSelectedDuration:
                                      _adjustSelectedFramesDuration,
                                  onKeepOnlyPrimarySelection:
                                      _keepOnlyPrimarySelection,
                                  onSelectFrame: _selectFrame,
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: _EditorPanel(
                                  frame: _selectedFrame,
                                  selectedCount: _selectedCount,
                                  selectedDurationSummary:
                                      _selectedDurationSummary,
                                  hasMultipleSelection: _hasMultipleSelection,
                                  frameIndex: _selectedIndex,
                                  frameCount: _frames.length,
                                  canvasWidth: _canvasWidth,
                                  canvasHeight: _canvasHeight,
                                  zoom: _zoom,
                                  showPreviewGrid: _showPreviewGrid,
                                  canMoveUp:
                                      !_hasMultipleSelection &&
                                      _selectedIndex > 0,
                                  canMoveDown:
                                      !_hasMultipleSelection &&
                                      _selectedIndex < _frames.length - 1,
                                  canRemove: _canDeleteCurrentSelection,
                                  onDurationChanged: (value) {
                                    _updateSelectedFramesDuration(
                                      value.round(),
                                    );
                                  },
                                  onZoomChanged: (value) {
                                    setState(() {
                                      _zoom = value;
                                    });
                                  },
                                  onToggleGrid: () {
                                    setState(() {
                                      _showPreviewGrid = !_showPreviewGrid;
                                    });
                                  },
                                  onToggleLoop: () {
                                    setState(() {
                                      _loopPlayback = !_loopPlayback;
                                    });
                                  },
                                  loopPlayback: _loopPlayback,
                                  onMoveFrameUp: () => _moveSelectedFrame(-1),
                                  onMoveFrameDown: () => _moveSelectedFrame(1),
                                  onDuplicateFrame: _duplicateSelectedFrame,
                                  onRemoveFrame: _removeSelectedFrame,
                                  onFitModeChanged: _setSelectedFrameFitMode,
                                  onContentScaleChanged:
                                      _setSelectedFrameContentScale,
                                  onOffsetXChanged: _setSelectedFrameOffsetX,
                                  onOffsetYChanged: _setSelectedFrameOffsetY,
                                  onResetTransform:
                                      _resetSelectedFrameTransform,
                                  onReplaceFrameSource: _isBusy
                                      ? null
                                      : _replaceSelectedFrameSource,
                                  onBatchAdjustDuration:
                                      _adjustSelectedFramesDuration,
                                  onKeepOnlyPrimarySelection:
                                      _keepOnlyPrimarySelection,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.76),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 900;
                        final leading = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isBusy)
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                ),
                              )
                            else
                              Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _statusText,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                        final trailing = Text(
                          _loopPlayback ? '循环播放已开启' : '循环播放已关闭',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        );

                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              leading,
                              const SizedBox(height: 8),
                              Text(
                                '当前项目 ${_frames.length} 帧，总时长 ${(_totalDurationMs / 1000).toStringAsFixed(2)} 秒，画布 $_canvasLabel。',
                              ),
                              const SizedBox(height: 6),
                              trailing,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: leading),
                            const SizedBox(width: 12),
                            Text(
                              '当前项目 ${_frames.length} 帧，总时长 ${(_totalDurationMs / 1000).toStringAsFixed(2)} 秒，画布 $_canvasLabel。',
                            ),
                            const SizedBox(width: 16),
                            trailing,
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopToolbar extends StatelessWidget {
  const _TopToolbar({
    required this.onMenuAction,
    required this.onImportImages,
    required this.onOpenGif,
    required this.onImportVideo,
    required this.onExportGif,
    required this.onAddFrame,
    required this.isBusy,
  });

  final ValueChanged<String> onMenuAction;
  final VoidCallback? onImportImages;
  final VoidCallback? onOpenGif;
  final VoidCallback? onImportVideo;
  final VoidCallback? onExportGif;
  final VoidCallback? onAddFrame;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final menuButtons = [
      _ToolbarMenu(
        label: '文件',
        onSelected: onMenuAction,
        items: const {'新建项目': '新建项目', '打开 GIF': '打开 GIF', '导出 GIF': '导出 GIF'},
      ),
      _ToolbarMenu(
        label: '编辑',
        onSelected: onMenuAction,
        items: const {'复制帧': '复制帧', '删除帧': '删除帧', '画布设置': '画布设置'},
      ),
      _ToolbarMenu(
        label: '片段',
        onSelected: onMenuAction,
        items: const {'导入图片': '导入图片', '导入 MP4': '导入 MP4', '调整排序': '调整排序'},
      ),
      _ToolbarMenu(
        label: '帮助',
        onSelected: onMenuAction,
        items: const {'快捷键': '快捷键', '导出建议': '导出建议'},
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 920;

          return Column(
            children: [
              if (compact)
                Wrap(
                  spacing: 4,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [const _BrandMark(), ...menuButtons],
                )
              else
                Row(
                  children: [
                    const _BrandMark(),
                    const SizedBox(width: 14),
                    ...menuButtons,
                  ],
                ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: onImportImages,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('导入图片'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonalIcon(
                      onPressed: onOpenGif,
                      icon: const Icon(Icons.gif_box_outlined),
                      label: const Text('打开 GIF'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonalIcon(
                      onPressed: onImportVideo,
                      icon: const Icon(Icons.movie_creation_outlined),
                      label: const Text('导入 MP4'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: onExportGif,
                      child: Text(isBusy ? '处理中...' : '导出 GIF'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      key: const ValueKey('add-frame-button'),
                      onPressed: onAddFrame,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('新增帧'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TimelinePanel extends StatelessWidget {
  const _TimelinePanel({
    required this.frames,
    required this.selectedIndices,
    required this.primarySelectedIndex,
    required this.totalDurationMs,
    required this.selectedCount,
    required this.hasMultipleSelection,
    required this.canDeleteSelection,
    required this.onDeleteSelection,
    required this.onAdjustSelectedDuration,
    required this.onKeepOnlyPrimarySelection,
    required this.onSelectFrame,
  });

  final List<EditorFrame> frames;
  final Set<int> selectedIndices;
  final int primarySelectedIndex;
  final int totalDurationMs;
  final int selectedCount;
  final bool hasMultipleSelection;
  final bool canDeleteSelection;
  final VoidCallback onDeleteSelection;
  final ValueChanged<int> onAdjustSelectedDuration;
  final VoidCallback onKeepOnlyPrimarySelection;
  final ValueChanged<int> onSelectFrame;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '时间线',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '${frames.length} 帧 / ${(totalDurationMs / 1000).toStringAsFixed(2)} 秒',
              key: const ValueKey('frame-summary'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            if (hasMultipleSelection) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '已选 $selectedCount 帧',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ctrl/Cmd + 点击增减选择，Shift + 点击连续选择',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => onAdjustSelectedDuration(-50),
                          child: const Text('-50 ms'),
                        ),
                        OutlinedButton(
                          onPressed: () => onAdjustSelectedDuration(50),
                          child: const Text('+50 ms'),
                        ),
                        OutlinedButton(
                          onPressed: onKeepOnlyPrimarySelection,
                          child: const Text('仅保留当前'),
                        ),
                        FilledButton.tonal(
                          onPressed: canDeleteSelection
                              ? onDeleteSelection
                              : null,
                          child: const Text('删除选中'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            Expanded(
              child: ListView.separated(
                itemCount: frames.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final frame = frames[index];
                  final isSelected = selectedIndices.contains(index);
                  final isPrimary = index == primarySelectedIndex;

                  return _FrameTile(
                    frame: frame,
                    isSelected: isSelected,
                    isPrimary: isPrimary,
                    index: index,
                    onTap: () => onSelectFrame(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorPanel extends StatelessWidget {
  const _EditorPanel({
    required this.frame,
    required this.selectedCount,
    required this.selectedDurationSummary,
    required this.hasMultipleSelection,
    required this.frameIndex,
    required this.frameCount,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.zoom,
    required this.showPreviewGrid,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canRemove,
    required this.onDurationChanged,
    required this.onZoomChanged,
    required this.onToggleGrid,
    required this.onToggleLoop,
    required this.loopPlayback,
    required this.onMoveFrameUp,
    required this.onMoveFrameDown,
    required this.onDuplicateFrame,
    required this.onRemoveFrame,
    required this.onFitModeChanged,
    required this.onContentScaleChanged,
    required this.onOffsetXChanged,
    required this.onOffsetYChanged,
    required this.onResetTransform,
    required this.onReplaceFrameSource,
    required this.onBatchAdjustDuration,
    required this.onKeepOnlyPrimarySelection,
  });

  final EditorFrame frame;
  final int selectedCount;
  final String selectedDurationSummary;
  final bool hasMultipleSelection;
  final int frameIndex;
  final int frameCount;
  final int canvasWidth;
  final int canvasHeight;
  final double zoom;
  final bool showPreviewGrid;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool canRemove;
  final ValueChanged<double> onDurationChanged;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onToggleGrid;
  final VoidCallback onToggleLoop;
  final bool loopPlayback;
  final VoidCallback onMoveFrameUp;
  final VoidCallback onMoveFrameDown;
  final VoidCallback onDuplicateFrame;
  final VoidCallback onRemoveFrame;
  final ValueChanged<EditorFrameFitMode> onFitModeChanged;
  final ValueChanged<double> onContentScaleChanged;
  final ValueChanged<double> onOffsetXChanged;
  final ValueChanged<double> onOffsetYChanged;
  final VoidCallback onResetTransform;
  final VoidCallback? onReplaceFrameSource;
  final ValueChanged<int> onBatchAdjustDuration;
  final VoidCallback onKeepOnlyPrimarySelection;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 940;
        final preview = _PreviewStage(
          frame: frame,
          frameIndex: frameIndex,
          frameCount: frameCount,
          canvasWidth: canvasWidth,
          canvasHeight: canvasHeight,
          zoom: zoom,
          showPreviewGrid: showPreviewGrid,
          canMoveUp: canMoveUp,
          canMoveDown: canMoveDown,
          onZoomChanged: onZoomChanged,
          onToggleGrid: onToggleGrid,
          onMoveFrameUp: onMoveFrameUp,
          onMoveFrameDown: onMoveFrameDown,
          onResetTransform: onResetTransform,
        );
        final inspector = hasMultipleSelection
            ? _BatchInspectorPanel(
                selectedCount: selectedCount,
                selectedDurationSummary: selectedDurationSummary,
                referenceDurationMs: frame.durationMs,
                canRemove: canRemove,
                onDurationChanged: onDurationChanged,
                onAdjustDuration: onBatchAdjustDuration,
                onRemoveFrames: onRemoveFrame,
                onKeepOnlyPrimarySelection: onKeepOnlyPrimarySelection,
              )
            : _InspectorPanel(
                frame: frame,
                canRemove: canRemove,
                loopPlayback: loopPlayback,
                onDurationChanged: onDurationChanged,
                onToggleLoop: onToggleLoop,
                onDuplicateFrame: onDuplicateFrame,
                onRemoveFrame: onRemoveFrame,
                onFitModeChanged: onFitModeChanged,
                onContentScaleChanged: onContentScaleChanged,
                onOffsetXChanged: onOffsetXChanged,
                onOffsetYChanged: onOffsetYChanged,
                onResetTransform: onResetTransform,
                onReplaceFrameSource: onReplaceFrameSource,
              );

        if (compact) {
          return Column(
            children: [
              Expanded(flex: 5, child: preview),
              const SizedBox(height: 16),
              Expanded(flex: 4, child: inspector),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 6, child: preview),
            const SizedBox(width: 16),
            SizedBox(width: 330, child: inspector),
          ],
        );
      },
    );
  }
}

class _PreviewStage extends StatelessWidget {
  const _PreviewStage({
    required this.frame,
    required this.frameIndex,
    required this.frameCount,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.zoom,
    required this.showPreviewGrid,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onZoomChanged,
    required this.onToggleGrid,
    required this.onMoveFrameUp,
    required this.onMoveFrameDown,
    required this.onResetTransform,
  });

  final EditorFrame frame;
  final int frameIndex;
  final int frameCount;
  final int canvasWidth;
  final int canvasHeight;
  final double zoom;
  final bool showPreviewGrid;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onToggleGrid;
  final VoidCallback onMoveFrameUp;
  final VoidCallback onMoveFrameDown;
  final VoidCallback onResetTransform;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '画布预览',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '第 ${frameIndex + 1} / $frameCount 帧 · ${frame.name}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: canMoveUp ? onMoveFrameUp : null,
                  icon: const Icon(Icons.arrow_upward_rounded),
                  tooltip: '上移',
                ),
                IconButton(
                  onPressed: canMoveDown ? onMoveFrameDown : null,
                  icon: const Icon(Icons.arrow_downward_rounded),
                  tooltip: '下移',
                ),
                IconButton(
                  onPressed: onToggleGrid,
                  icon: Icon(
                    showPreviewGrid
                        ? Icons.grid_on_rounded
                        : Icons.grid_off_rounded,
                  ),
                  tooltip: '切换网格',
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Center(
                child: AnimatedScale(
                  scale: zoom,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: AspectRatio(
                    aspectRatio: canvasWidth / canvasHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: frame.accent.withValues(alpha: 0.22),
                            blurRadius: 32,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: frame.canvasPreviewBytes != null
                                  ? Image.memory(
                                      frame.canvasPreviewBytes!,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                    )
                                  : _PlaceholderPreview(frame: frame),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withValues(alpha: 0.1),
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.34),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                            if (showPreviewGrid)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _PreviewGridPainter(
                                    color: Colors.white.withValues(alpha: 0.14),
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _OverlayChip(label: frame.sourceLabel),
                                      _OverlayChip(
                                        label: frame.hasRasterData
                                            ? '已导入'
                                            : '占位帧',
                                      ),
                                      if (frame.sourceSizeLabel != null)
                                        _OverlayChip(
                                          label: frame.sourceSizeLabel!,
                                        ),
                                      _OverlayChip(
                                        label: '$canvasWidth×$canvasHeight',
                                      ),
                                      if (frame.canEditTransform)
                                        _OverlayChip(
                                          label:
                                              '${frame.fitModeLabel} · ${frame.contentScale.toStringAsFixed(2)}x',
                                        ),
                                    ],
                                  ),
                                  const Spacer(),
                                  if (!frame.hasRasterData)
                                    const Icon(
                                      Icons.auto_awesome_motion_rounded,
                                      size: 56,
                                      color: Colors.white,
                                    ),
                                  if (!frame.hasRasterData)
                                    const SizedBox(height: 14),
                                  Text(
                                    frame.description,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${frame.durationMs} ms · ${frame.hasRasterData ? '已进入 GIF 导出链路' : '导入真实素材后可直接导出'}',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '缩放 ${(zoom * 100).round()}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: Slider(
                    value: zoom,
                    min: 0.7,
                    max: 1.35,
                    divisions: 13,
                    onChanged: onZoomChanged,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: frame.canEditTransform ? onResetTransform : null,
                  icon: const Icon(Icons.center_focus_strong_outlined),
                  label: const Text('重置构图'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel({
    required this.frame,
    required this.canRemove,
    required this.loopPlayback,
    required this.onDurationChanged,
    required this.onToggleLoop,
    required this.onDuplicateFrame,
    required this.onRemoveFrame,
    required this.onFitModeChanged,
    required this.onContentScaleChanged,
    required this.onOffsetXChanged,
    required this.onOffsetYChanged,
    required this.onResetTransform,
    required this.onReplaceFrameSource,
  });

  final EditorFrame frame;
  final bool canRemove;
  final bool loopPlayback;
  final ValueChanged<double> onDurationChanged;
  final VoidCallback onToggleLoop;
  final VoidCallback onDuplicateFrame;
  final VoidCallback onRemoveFrame;
  final ValueChanged<EditorFrameFitMode> onFitModeChanged;
  final ValueChanged<double> onContentScaleChanged;
  final ValueChanged<double> onOffsetXChanged;
  final ValueChanged<double> onOffsetYChanged;
  final VoidCallback onResetTransform;
  final VoidCallback? onReplaceFrameSource;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '单帧编辑',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '当前已支持图片导入、GIF 打开、MP4 抽帧和 GIF 导出。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              _PanelSection(
                title: '帧时间',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${frame.durationMs} ms',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Slider(
                      value: frame.durationMs.toDouble(),
                      min: 10,
                      max: 5000,
                      divisions: 499,
                      label: '${frame.durationMs} ms',
                      onChanged: onDurationChanged,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => onDurationChanged(
                              (frame.durationMs - 50)
                                  .clamp(10, 5000)
                                  .toDouble(),
                            ),
                            child: const Text('-50 ms'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => onDurationChanged(
                              (frame.durationMs + 50)
                                  .clamp(10, 5000)
                                  .toDouble(),
                            ),
                            child: const Text('+50 ms'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _PanelSection(
                title: '来源',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(label: '文件', value: frame.sourceLabel),
                    if (frame.sourceSizeLabel != null) ...[
                      const SizedBox(height: 8),
                      _InfoRow(label: '尺寸', value: frame.sourceSizeLabel!),
                    ],
                    const SizedBox(height: 8),
                    _InfoRow(label: '说明', value: frame.description),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _PanelSection(
                title: '画布构图',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<EditorFrameFitMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment<EditorFrameFitMode>(
                          value: EditorFrameFitMode.contain,
                          label: Text('适应'),
                          icon: Icon(Icons.fit_screen_outlined),
                        ),
                        ButtonSegment<EditorFrameFitMode>(
                          value: EditorFrameFitMode.cover,
                          label: Text('铺满'),
                          icon: Icon(Icons.crop_16_9_rounded),
                        ),
                      ],
                      selected: {frame.fitMode},
                      onSelectionChanged: frame.canEditTransform
                          ? (selection) => onFitModeChanged(selection.first)
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '内容缩放 ${(frame.contentScale * 100).round()}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Slider(
                      value: frame.contentScale,
                      min: 0.6,
                      max: 3,
                      divisions: 24,
                      label: '${(frame.contentScale * 100).round()}%',
                      onChanged: frame.canEditTransform
                          ? onContentScaleChanged
                          : null,
                    ),
                    Text(
                      '水平偏移 ${(frame.offsetX * 100).round()}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Slider(
                      value: frame.offsetX,
                      min: -1,
                      max: 1,
                      divisions: 40,
                      label: '${(frame.offsetX * 100).round()}%',
                      onChanged: frame.canEditTransform
                          ? onOffsetXChanged
                          : null,
                    ),
                    Text(
                      '垂直偏移 ${(frame.offsetY * 100).round()}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Slider(
                      value: frame.offsetY,
                      min: -1,
                      max: 1,
                      divisions: 40,
                      label: '${(frame.offsetY * 100).round()}%',
                      onChanged: frame.canEditTransform
                          ? onOffsetYChanged
                          : null,
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: frame.canEditTransform
                            ? onResetTransform
                            : null,
                        icon: const Icon(Icons.center_focus_strong_outlined),
                        label: const Text('重置构图'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _PanelSection(
                title: '播放与导出',
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('循环播放'),
                      subtitle: Text(
                        frame.hasRasterData
                            ? '当前帧已接入 GIF 导出'
                            : '当前帧仍是占位素材，导出前需要替换',
                      ),
                      value: loopPlayback,
                      onChanged: (_) => onToggleLoop(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: onReplaceFrameSource,
                            icon: const Icon(Icons.swap_horiz_rounded),
                            label: const Text('替换素材'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: frame.canEditTransform
                                ? onResetTransform
                                : null,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('重置构图'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _PanelSection(
                title: '帧操作',
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onDuplicateFrame,
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('复制当前帧'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: canRemove ? onRemoveFrame : null,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('删除当前帧'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatchInspectorPanel extends StatelessWidget {
  const _BatchInspectorPanel({
    required this.selectedCount,
    required this.selectedDurationSummary,
    required this.referenceDurationMs,
    required this.canRemove,
    required this.onDurationChanged,
    required this.onAdjustDuration,
    required this.onRemoveFrames,
    required this.onKeepOnlyPrimarySelection,
  });

  final int selectedCount;
  final String selectedDurationSummary;
  final int referenceDurationMs;
  final bool canRemove;
  final ValueChanged<double> onDurationChanged;
  final ValueChanged<int> onAdjustDuration;
  final VoidCallback onRemoveFrames;
  final VoidCallback onKeepOnlyPrimarySelection;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '批量编辑',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '当前已选 $selectedCount 帧。可以统一修改时长，或直接批量删除。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              _PanelSection(
                title: '批量时长',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedDurationSummary,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '拖动滑块会把所有选中帧统一设为该时长。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Slider(
                      value: referenceDurationMs.toDouble(),
                      min: 10,
                      max: 5000,
                      divisions: 499,
                      label: '$referenceDurationMs ms',
                      onChanged: onDurationChanged,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => onAdjustDuration(-50),
                            child: const Text('全部 -50 ms'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => onAdjustDuration(50),
                            child: const Text('全部 +50 ms'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _PanelSection(
                title: '选择',
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onKeepOnlyPrimarySelection,
                        icon: const Icon(Icons.filter_1_outlined),
                        label: const Text('仅保留当前主选中帧'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: canRemove ? onRemoveFrames : null,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('删除选中帧'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarMenu extends StatelessWidget {
  const _ToolbarMenu({
    required this.label,
    required this.items,
    required this.onSelected,
  });

  final String label;
  final Map<String, String> items;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: label,
      onSelected: onSelected,
      itemBuilder: (context) {
        return items.entries
            .map(
              (entry) => PopupMenuItem<String>(
                value: entry.value,
                child: Text(entry.key),
              ),
            )
            .toList();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gif_box_rounded, color: Colors.white),
          SizedBox(width: 10),
          Text(
            'Gif Studio',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _FrameTile extends StatelessWidget {
  const _FrameTile({
    required this.frame,
    required this.isSelected,
    required this.isPrimary,
    required this.index,
    required this.onTap,
  });

  final EditorFrame frame;
  final bool isSelected;
  final bool isPrimary;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = isSelected
        ? frame.accent.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.58);

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isPrimary
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: isPrimary ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: frame.thumbnailBytes == null
                      ? LinearGradient(
                          colors: [
                            frame.accent,
                            frame.accent.withValues(alpha: 0.78),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: frame.thumbnailBytes != null
                    ? Image.memory(
                        frame.thumbnailBytes!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    : const Icon(
                        Icons.image_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            frame.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '#${index + 1}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          Icon(
                            isPrimary
                                ? Icons.check_circle_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      frame.sourceLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.76),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${frame.durationMs} ms',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: frame.hasRasterData
                                ? const Color(0xFFE6F7EF)
                                : const Color(0xFFF5E9DD),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            frame.hasRasterData ? '已就绪' : '占位',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: frame.hasRasterData
                                  ? const Color(0xFF0F766E)
                                  : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelSection extends StatelessWidget {
  const _PanelSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _OverlayChip extends StatelessWidget {
  const _OverlayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PlaceholderPreview extends StatelessWidget {
  const _PlaceholderPreview({required this.frame});

  final EditorFrame frame;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            frame.accent,
            Color.alphaBlend(
              Colors.white.withValues(alpha: 0.18),
              frame.accent,
            ),
            frame.accent.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_size_select_actual_outlined,
              color: Colors.white,
              size: 54,
            ),
            const SizedBox(height: 14),
            Text(
              '等待导入真实素材',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewGridPainter extends CustomPainter {
  const _PreviewGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 1; i < 4; i++) {
      final dx = size.width / 4 * i;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
    }

    for (var i = 1; i < 3; i++) {
      final dy = size.height / 3 * i;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewGridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _RasterImportRequest {
  const _RasterImportRequest({
    required this.files,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  final List<RasterImportFile> files;
  final int canvasWidth;
  final int canvasHeight;
}

class _GifImportRequest {
  const _GifImportRequest({
    required this.file,
    this.canvasWidth,
    this.canvasHeight,
  });

  final RasterImportFile file;
  final int? canvasWidth;
  final int? canvasHeight;
}

class _ReplaceFrameSourceRequest {
  const _ReplaceFrameSourceRequest({
    required this.frameId,
    required this.frameName,
    required this.durationMs,
    required this.file,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  final String frameId;
  final String frameName;
  final int durationMs;
  final RasterImportFile file;
  final int canvasWidth;
  final int canvasHeight;
}

class _GifExportRequest {
  const _GifExportRequest({
    required this.frames,
    required this.loopPlayback,
    required this.quality,
    required this.scaleFactor,
  });

  final List<GifExportFrameData> frames;
  final bool loopPlayback;
  final GifExportQualityPreset quality;
  final double scaleFactor;
}

class _GifExportEstimateRequest {
  const _GifExportEstimateRequest({
    required this.frames,
    required this.loopPlayback,
    required this.quality,
    required this.scaleFactor,
  });

  final List<GifExportFrameData> frames;
  final bool loopPlayback;
  final GifExportQualityPreset quality;
  final double scaleFactor;
}

FrameImportResult _runRasterImport(_RasterImportRequest request) {
  return GifProjectCodec.importRasterFiles(
    request.files,
    canvasWidth: request.canvasWidth,
    canvasHeight: request.canvasHeight,
  );
}

GifImportResult? _runGifImport(_GifImportRequest request) {
  return GifProjectCodec.importGifFile(
    request.file,
    canvasWidth: request.canvasWidth,
    canvasHeight: request.canvasHeight,
  );
}

EditorFrame? _runReplaceFrameSource(_ReplaceFrameSourceRequest request) {
  return GifProjectCodec.createFrameFromSource(
    id: request.frameId,
    name: request.frameName,
    sourceLabel: request.file.displayLabel ?? request.file.name,
    sourceName: request.file.name,
    sourceBytes: request.file.bytes,
    durationMs: request.durationMs,
    description:
        request.file.description ?? '已替换为 ${request.file.name}，当前构图已重置',
    canvasWidth: request.canvasWidth,
    canvasHeight: request.canvasHeight,
  );
}

Uint8List _runGifExport(_GifExportRequest request) {
  return GifProjectCodec.encodeGifFrameData(
    request.frames,
    loopPlayback: request.loopPlayback,
    quality: request.quality,
    scaleFactor: request.scaleFactor,
  );
}

int _runGifExportEstimate(_GifExportEstimateRequest request) {
  return GifProjectCodec.encodeGifFrameData(
    request.frames,
    loopPlayback: request.loopPlayback,
    quality: request.quality,
    scaleFactor: request.scaleFactor,
  ).length;
}

Future<_CanvasSettingsResult?> _showCanvasSettingsDialog({
  required BuildContext context,
  required int initialWidth,
  required int initialHeight,
}) async {
  final widthController = TextEditingController(text: '$initialWidth');
  final heightController = TextEditingController(text: '$initialHeight');
  String? errorText;

  final result = await showDialog<_CanvasSettingsResult>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          void applyPreset(_CanvasPreset preset) {
            widthController.text = '${preset.width}';
            heightController.text = '${preset.height}';
          }

          void submit() {
            final width = int.tryParse(widthController.text.trim());
            final height = int.tryParse(heightController.text.trim());

            if (width == null || height == null) {
              setState(() {
                errorText = '请输入有效的整数宽高。';
              });
              return;
            }

            if (width < 64 || height < 64 || width > 4096 || height > 4096) {
              setState(() {
                errorText = '宽高需要在 64 到 4096 之间。';
              });
              return;
            }

            Navigator.of(
              dialogContext,
            ).pop(_CanvasSettingsResult(width: width, height: height));
          }

          return AlertDialog(
            title: const Text('画布设置'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '调整整个项目的输出画布尺寸，现有帧会按当前构图重新渲染。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        const [
                          _CanvasPresetButton(
                            preset: _CanvasPreset('GIF 4:3', 800, 600),
                          ),
                          _CanvasPresetButton(
                            preset: _CanvasPreset('正方形', 512, 512),
                          ),
                          _CanvasPresetButton(
                            preset: _CanvasPreset('竖屏', 720, 1280),
                          ),
                          _CanvasPresetButton(
                            preset: _CanvasPreset('宽屏', 1280, 720),
                          ),
                        ].map((button) {
                          return InkWell(
                            onTap: () => applyPreset(button.preset),
                            borderRadius: BorderRadius.circular(999),
                            child: button,
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widthController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '宽度'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: heightController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '高度'),
                        ),
                      ),
                    ],
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(onPressed: submit, child: const Text('应用')),
            ],
          );
        },
      );
    },
  );

  widthController.dispose();
  heightController.dispose();
  return result;
}

Future<_GifExportSettingsResult?> _showGifExportSettingsDialog({
  required BuildContext context,
  required GifExportQualityPreset initialQuality,
  required double initialScaleFactor,
  required int canvasWidth,
  required int canvasHeight,
  required bool loopPlayback,
  required List<GifExportFrameData> exportFrames,
}) async {
  GifExportQualityPreset selectedQuality = initialQuality;
  double selectedScaleFactor = initialScaleFactor;
  int? estimatedBytes;
  bool estimating = true;
  Object? estimateError;
  var estimateGeneration = 0;
  const scaleOptions = <_GifExportScaleOption>[
    _GifExportScaleOption(label: '100%', scaleFactor: 1),
    _GifExportScaleOption(label: '75%', scaleFactor: 0.75),
    _GifExportScaleOption(label: '50%', scaleFactor: 0.5),
    _GifExportScaleOption(label: '25%', scaleFactor: 0.25),
  ];

  return showDialog<_GifExportSettingsResult>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> refreshEstimate() async {
            final generation = ++estimateGeneration;
            setState(() {
              estimating = true;
              estimateError = null;
            });

            try {
              final bytes = await compute(
                _runGifExportEstimate,
                _GifExportEstimateRequest(
                  frames: exportFrames,
                  loopPlayback: loopPlayback,
                  quality: selectedQuality,
                  scaleFactor: selectedScaleFactor,
                ),
              );
              if (generation != estimateGeneration || !context.mounted) {
                return;
              }
              setState(() {
                estimatedBytes = bytes;
                estimating = false;
              });
            } catch (error) {
              if (generation != estimateGeneration || !context.mounted) {
                return;
              }
              setState(() {
                estimateError = error;
                estimating = false;
              });
            }
          }

          if (estimateGeneration == 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              refreshEstimate();
            });
          }

          return AlertDialog(
            title: const Text('导出设置'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '画质',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...GifExportQualityPreset.values.map((quality) {
                    final selected = quality == selectedQuality;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          selectedQuality = quality;
                        });
                        refreshEstimate();
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selected
                              ? Theme.of(context).colorScheme.primaryContainer
                                    .withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                selected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_gifExportQualityLabel(quality)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _gifExportQualityDescription(quality),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Text(
                    '导出尺寸缩放',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: scaleOptions.map((option) {
                      final selected =
                          option.scaleFactor == selectedScaleFactor;
                      final scaledWidth = (canvasWidth * option.scaleFactor)
                          .round();
                      final scaledHeight = (canvasHeight * option.scaleFactor)
                          .round();
                      return ChoiceChip(
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            selectedScaleFactor = option.scaleFactor;
                          });
                          refreshEstimate();
                        },
                        label: Text(
                          '${option.label} $scaledWidth×$scaledHeight',
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  if (estimating)
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '预估文件大小计算中...',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    )
                  else if (estimateError != null)
                    Text(
                      '预估失败：$estimateError',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else if (estimatedBytes != null)
                    Text(
                      '预估文件大小：${_formatBytes(estimatedBytes!)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(
                  _GifExportSettingsResult(
                    quality: selectedQuality,
                    scaleFactor: selectedScaleFactor,
                  ),
                ),
                child: const Text('继续导出'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _GifExportSettingsResult {
  const _GifExportSettingsResult({
    required this.quality,
    required this.scaleFactor,
  });

  final GifExportQualityPreset quality;
  final double scaleFactor;
}

class _GifExportScaleOption {
  const _GifExportScaleOption({required this.label, required this.scaleFactor});

  final String label;
  final double scaleFactor;
}

String _gifExportQualityLabel(GifExportQualityPreset quality) {
  return switch (quality) {
    GifExportQualityPreset.draft => '草稿',
    GifExportQualityPreset.balanced => '均衡',
    GifExportQualityPreset.best => '高质量',
  };
}

String _gifExportQualityDescription(GifExportQualityPreset quality) {
  return switch (quality) {
    GifExportQualityPreset.draft => '更小体积，颜色更少，不使用抖动。',
    GifExportQualityPreset.balanced => '默认推荐，128 色稳定编码，体积和画质比较均衡。',
    GifExportQualityPreset.best => '更多颜色和抖动，画质更好，编码更慢，体积更大。',
  };
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

class _CanvasPreset {
  const _CanvasPreset(this.label, this.width, this.height);

  final String label;
  final int width;
  final int height;
}

class _CanvasSettingsResult {
  const _CanvasSettingsResult({required this.width, required this.height});

  final int width;
  final int height;
}

class _CanvasPresetButton extends StatelessWidget {
  const _CanvasPresetButton({required this.preset});

  final _CanvasPreset preset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(
        '${preset.label} ${preset.width}×${preset.height}',
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
