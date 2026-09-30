/// The audio engine (MEDIA_READER_PLAN.md R4, MR4): one player for the
/// app, `just_audio` on iOS, Android and macOS and `video_player`
/// through `fvp` on Windows and Linux.
library;

import 'package:flutter/widgets.dart';

import '../../item/media_reader_item.dart';
import '../../item/media_reader_source.dart';
import '../../media_kind.dart';
import '../../shell/media_reader_page.dart';
import '../media_reader_engine.dart';
import 'audio_coordinator.dart';
import 'audio_view.dart';

/// Plays the audio the platform's player plays. A format it does not
/// play there (an Ogg on an iPhone) is played through the host's
/// preview, an MP3 or M4A its server makes, or left to the card.
class const MediaReaderAudioEngine({
  /// The coordinator its pages play through: the app's shared one unless
  /// the host passes another. An inline bar on the same coordinator
  /// shares a file's playing with the reader.
  final MediaReaderAudioCoordinator? coordinator,
}) implements MediaReaderEngine {
  /// What AVPlayer plays.
  static const Set<String> _apple = {
    'mp3',
    'm4a',
    'm4b',
    'aac',
    'wav',
    'aiff',
    'flac',
  };

  /// What ExoPlayer plays.
  static const Set<String> _android = {
    'mp3',
    'm4a',
    'm4b',
    'aac',
    'wav',
    'flac',
    'ogg',
    'opus',
    'weba',
    'amr',
  };

  /// What libmdk plays, with FFmpeg behind it.
  static const Set<String> _desktop = {..._android, 'aiff', 'wma'};

  /// Whether the player of [platform] plays [item] as it is.
  static bool plays(MediaReaderItem item, TargetPlatform platform) {
    if (item.kind != MediaKind.audio) return false;
    // The players take a URL or a file; bytes in memory are neither.
    if (item.source is MediaReaderBytesSource) return false;
    return switch (platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => _apple,
      TargetPlatform.android => _android,
      TargetPlatform.windows || TargetPlatform.linux => _desktop,
      TargetPlatform.fuchsia => const <String>{},
    }.contains(item.format);
  }

  /// What of [item] the player of [platform] plays: the file itself, or
  /// failing that its preview; null when neither.
  static MediaReaderItem? playable(
    MediaReaderItem item,
    TargetPlatform platform,
  ) {
    if (plays(item, platform)) return item;
    final preview = item.asPreview;
    return preview != null && plays(preview, platform) ? preview : null;
  }

  @override
  String get id => 'audio';

  @override
  bool canShow(MediaReaderItem item, TargetPlatform platform) =>
      plays(item, platform);

  @override
  Widget build(
    BuildContext context,
    MediaReaderItem item,
    MediaReaderPage page,
  ) => MediaReaderAudioView(
    coordinator: coordinator ?? MediaReaderAudioCoordinator.shared,
    item: item,
    page: page,
  );
}
