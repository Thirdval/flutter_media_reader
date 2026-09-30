/// An in-app reader for the files a host hands it — pictures, video,
/// audio with waveforms, PDF, text, tables and archives — on iOS,
/// Android, macOS, Windows and Linux, through swappable engines. Files
/// never leave the app: exporting is the host's action, under the
/// host's policy.
///
/// Pre-release: phase R7 of MEDIA_READER_PLAN.md. The reader's shell and
/// its host contract are here — `showMediaReader` and [MediaReaderView],
/// items and their sources, the policy, the chrome's slots, and the
/// registry of engines — with the engines for pictures, video, audio,
/// PDF, text, Markdown, tables and archives, Office files through the
/// PDF a host's server makes of them, and [MediaReaderAudioBar] for a
/// voice note in a chat.
library;

export 'src/engine/archive/archive_engine.dart';
export 'src/engine/audio/audio_bar.dart';
export 'src/engine/audio/audio_coordinator.dart';
export 'src/engine/audio/audio_engine.dart';
export 'src/engine/audio/audio_player.dart'
    show MediaReaderAudioPlayer, MediaReaderAudioPlayerFactory;
export 'src/engine/markdown/markdown_engine.dart';
export 'src/engine/media_reader_card_engine.dart';
export 'src/engine/media_reader_engine.dart';
export 'src/engine/media_reader_engines.dart';
export 'src/engine/pdf/pdf_engine.dart';
export 'src/engine/picture/picture_engine.dart';
export 'src/engine/table/table_engine.dart';
export 'src/engine/text/text_engine.dart';
export 'src/engine/video/video_engine.dart';
export 'src/io/media_reader_blocks.dart';
export 'src/io/media_reader_bytes.dart';
export 'src/io/media_reader_fetcher.dart';
export 'src/io/media_reader_transport.dart';
export 'src/item/media_reader_item.dart';
export 'src/item/media_reader_policy.dart';
export 'src/item/media_reader_resolver.dart';
export 'src/item/media_reader_source.dart';
export 'src/media_kind.dart';
export 'src/shell/media_reader_chrome.dart';
export 'src/shell/media_reader_document.dart';
export 'src/shell/media_reader_page.dart' show MediaReaderPage;
export 'src/shell/media_reader_playback.dart';
export 'src/shell/media_reader_strings.dart';
export 'src/shell/media_reader_view.dart';
export 'src/shell/show_media_reader.dart';
export 'src/shell/waveform.dart';
