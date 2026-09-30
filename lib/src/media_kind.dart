/// What a file is, for the reader: the kind decides which engine is
/// asked first to show it (MEDIA_READER_PLAN.md §2.3). It names the
/// file's nature, not what an engine can do — an SVG is a picture even
/// where no engine draws one; the registry falls back to the file's
/// card.
library;

/// A file's kind.
enum MediaKind() {
  picture,
  video,
  audio,
  pdf,

  /// Word, Excel, PowerPoint, OpenDocument, RTF: shown through a PDF the
  /// host makes on its server; never parsed here (MR7).
  office,

  /// Plain text, logs, code, JSON, XML, YAML.
  text,
  markdown,

  /// Comma- or tab-separated rows.
  table,
  archive,
  other;

  /// The kind of a file from its content type and name. The content
  /// type decides when it is specific; a generic one
  /// (`application/octet-stream`) or none defers to the extension. An
  /// MPEG-4 container type defers to an audio-only extension: a voice
  /// note uploaded as `video/mp4` named `.m4a` is audio.
  static MediaKind of({String? contentType, String? fileName}) {
    final type = _essence(contentType);
    final byName = _byExtension[_extension(fileName)];
    if (byName == MediaKind.audio && _mp4Containers.contains(type)) {
      return MediaKind.audio;
    }
    final byType = _byType(type);
    if (byType != null) return byType;
    if (byName != null) return byName;
    return switch (type.split('/').first) {
      'image' => MediaKind.picture,
      'video' => MediaKind.video,
      'audio' => MediaKind.audio,
      'text' => MediaKind.text,
      _ => MediaKind.other,
    };
  }

  /// The content type without its parameters, lower case.
  static String _essence(String? contentType) =>
      (contentType ?? '').split(';').first.trim().toLowerCase();

  /// The name's last extension, lower case, without the dot.
  static String _extension(String? fileName) {
    final name = fileName ?? '';
    final dot = name.lastIndexOf('.');
    return dot < 0 || dot == name.length - 1
        ? ''
        : name.substring(dot + 1).toLowerCase();
  }

  static const Set<String> _mp4Containers = {
    'video/mp4',
    'audio/mp4',
    'application/mp4',
  };

  /// A specific content type's kind; null for a generic or unknown one.
  static MediaKind? _byType(String type) {
    if (type.isEmpty || _generic.contains(type)) return null;
    if (type == 'application/pdf') return MediaKind.pdf;
    if (_office.contains(type) ||
        type.startsWith('application/vnd.openxmlformats-officedocument.') ||
        type.startsWith('application/vnd.oasis.opendocument.')) {
      return MediaKind.office;
    }
    if (_archives.contains(type)) return MediaKind.archive;
    if (_markdown.contains(type)) return MediaKind.markdown;
    if (_tables.contains(type)) return MediaKind.table;
    if (_structuredText.contains(type)) return MediaKind.text;
    return switch (type.split('/').first) {
      'image' => MediaKind.picture,
      'video' => MediaKind.video,
      'audio' => MediaKind.audio,
      'text' => MediaKind.text,
      _ => null,
    };
  }

  static const Set<String> _generic = {
    'application/octet-stream',
    'binary/octet-stream',
    'application/x-download',
    'application/force-download',
    'application/unknown',
  };

  static const Set<String> _office = {
    'application/msword',
    'application/vnd.ms-excel',
    'application/vnd.ms-powerpoint',
    'application/rtf',
    'text/rtf',
  };

  static const Set<String> _archives = {
    'application/zip',
    'application/x-zip-compressed',
    'application/x-tar',
    'application/gzip',
    'application/x-gzip',
    'application/x-7z-compressed',
    'application/vnd.rar',
    'application/x-rar-compressed',
  };

  static const Set<String> _markdown = {'text/markdown', 'text/x-markdown'};

  static const Set<String> _tables = {
    'text/csv',
    'text/tab-separated-values',
    'application/csv',
  };

  static const Set<String> _structuredText = {
    'application/json',
    'application/xml',
    'application/yaml',
    'application/x-yaml',
    'application/javascript',
    'application/x-sh',
  };

  /// Extensions by kind; `.ts` reads as TypeScript — an MPEG transport
  /// stream comes with its own content type (`video/mp2t`).
  static final Map<String, MediaKind> _byExtension = {
    for (final (kind, extensions) in const [
      (
        MediaKind.picture,
        'jpg jpeg png gif webp heic heif bmp tif tiff svg avif ico',
      ),
      (MediaKind.video, 'mp4 mov m4v webm mkv avi 3gp mpeg mpg wmv'),
      (
        MediaKind.audio,
        'mp3 m4a m4b aac wav flac ogg oga opus weba amr aif aiff wma',
      ),
      (MediaKind.pdf, 'pdf'),
      (
        MediaKind.office,
        'doc docx xls xlsx ppt pptx odt ods odp rtf pages numbers key',
      ),
      (MediaKind.markdown, 'md markdown'),
      (MediaKind.table, 'csv tsv'),
      (
        MediaKind.text,
        'txt log json xml yaml yml ini conf dart js ts py kt swift java c h cpp cs go rs rb php sh sql html css srt vtt',
      ),
      (MediaKind.archive, 'zip tar gz tgz 7z rar'),
    ])
      for (final extension in extensions.split(' ')) extension: kind,
  };
}
