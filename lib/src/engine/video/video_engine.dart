/// The video engine (MEDIA_READER_PLAN.md R3, MR2, MR3): the
/// `video_player` API, played by AVPlayer on iOS and macOS, by ExoPlayer
/// on Android, and by `fvp` (libmdk) on Windows and Linux, where `fvp`
/// registers itself as `video_player`'s implementation.
library;

import 'package:flutter/widgets.dart';

import '../../item/media_reader_item.dart';
import '../../item/media_reader_source.dart';
import '../../media_kind.dart';
import '../../shell/media_reader_page.dart';
import '../media_reader_engine.dart';
import 'video_view.dart';

/// Plays the videos the platform's player plays. A format it does not
/// play there (a WebM on an iPhone) is shown through the host's preview,
/// an MP4 its server makes, or left to the card.
class const MediaReaderVideoEngine() implements MediaReaderEngine {
  /// What AVPlayer plays.
  static const Set<String> _apple = {'mp4', 'm4v', 'mov', '3gp', 'm3u8'};

  /// What ExoPlayer plays.
  static const Set<String> _android = {..._apple, 'webm', 'mkv', 'ts'};

  /// What libmdk plays, with FFmpeg behind it.
  static const Set<String> _desktop = {
    ..._android,
    'avi',
    'mpeg',
    'wmv',
    'flv',
  };

  @override
  String get id => 'video';

  @override
  bool canShow(MediaReaderItem item, TargetPlatform platform) {
    if (item.kind != MediaKind.video) return false;
    // The players take a URL or a file; bytes in memory are neither.
    if (item.source is MediaReaderBytesSource) return false;
    return switch (platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => _apple,
      TargetPlatform.android => _android,
      TargetPlatform.windows || TargetPlatform.linux => _desktop,
      TargetPlatform.fuchsia => const <String>{},
    }.contains(item.format);
  }

  @override
  Widget build(
    BuildContext context,
    MediaReaderItem item,
    MediaReaderPage page,
  ) => MediaReaderVideoView(item: item, page: page);
}
