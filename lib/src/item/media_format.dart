/// A file's format, for an engine to decide whether it can show the file
/// on a platform: a short lower-case name, read from the content type
/// where that is specific and from the extension otherwise.
library;

/// The format of a file: "jpeg", "heic", "mp4", "m4a", "pdf". Empty when
/// neither the content type nor the name says.
///
/// As with the kind, an MPEG-4 container type defers to an audio-only
/// extension: `video/mp4` named `.m4a` is "m4a".
String mediaFormatOf({String? contentType, String? fileName}) {
  final type = (contentType ?? '').split(';').first.trim().toLowerCase();
  final name = fileName ?? '';
  final dot = name.lastIndexOf('.');
  final extension = dot < 0 || dot == name.length - 1
      ? ''
      : name.substring(dot + 1).toLowerCase();
  final byName = _aliases[extension] ?? extension;
  final byType = _byType[type];
  if (byType == null) return byName;
  if (_mp4Containers.contains(type) && _audioOnly.contains(byName)) {
    return byName;
  }
  return byType;
}

const Set<String> _mp4Containers = {
  'video/mp4',
  'audio/mp4',
  'application/mp4',
};

const Set<String> _audioOnly = {'m4a', 'm4b', 'aac'};

/// Extensions that name the same format as another.
const Map<String, String> _aliases = {
  'jpg': 'jpeg',
  'jpe': 'jpeg',
  'heif': 'heic',
  'tif': 'tiff',
  'oga': 'ogg',
  'mpg': 'mpeg',
  'aif': 'aiff',
  'htm': 'html',
  'yml': 'yaml',
  'markdown': 'md',
  'tgz': 'gz',
};

/// Content types that say the format themselves. A generic type
/// (`application/octet-stream`) is not here, and defers to the name.
const Map<String, String> _byType = {
  'image/jpeg': 'jpeg',
  'image/jpg': 'jpeg',
  'image/pjpeg': 'jpeg',
  'image/png': 'png',
  'image/apng': 'png',
  'image/gif': 'gif',
  'image/webp': 'webp',
  'image/bmp': 'bmp',
  'image/x-ms-bmp': 'bmp',
  'image/vnd.microsoft.icon': 'ico',
  'image/x-icon': 'ico',
  'image/vnd.wap.wbmp': 'wbmp',
  'image/heic': 'heic',
  'image/heif': 'heic',
  'image/heic-sequence': 'heic',
  'image/tiff': 'tiff',
  'image/svg+xml': 'svg',
  'image/avif': 'avif',
  'video/mp4': 'mp4',
  'application/mp4': 'mp4',
  'video/quicktime': 'mov',
  'video/x-m4v': 'm4v',
  'video/webm': 'webm',
  'video/x-matroska': 'mkv',
  'video/3gpp': '3gp',
  'video/mp2t': 'ts',
  'video/x-msvideo': 'avi',
  'video/mpeg': 'mpeg',
  'video/x-ms-wmv': 'wmv',
  'application/vnd.apple.mpegurl': 'm3u8',
  'application/x-mpegurl': 'm3u8',
  'audio/mpegurl': 'm3u8',
  'audio/mpeg': 'mp3',
  'audio/mp3': 'mp3',
  'audio/mp4': 'm4a',
  'audio/x-m4a': 'm4a',
  'audio/aac': 'aac',
  'audio/wav': 'wav',
  'audio/x-wav': 'wav',
  'audio/wave': 'wav',
  'audio/ogg': 'ogg',
  'audio/opus': 'opus',
  'audio/flac': 'flac',
  'audio/x-flac': 'flac',
  'audio/webm': 'weba',
  'audio/amr': 'amr',
  'audio/aiff': 'aiff',
  'audio/x-aiff': 'aiff',
  'application/pdf': 'pdf',
  'text/plain': 'txt',
  'text/markdown': 'md',
  'text/x-markdown': 'md',
  'text/csv': 'csv',
  'application/csv': 'csv',
  'text/tab-separated-values': 'tsv',
  'application/json': 'json',
  'application/xml': 'xml',
  'text/xml': 'xml',
  'text/html': 'html',
  'application/yaml': 'yaml',
  'application/x-yaml': 'yaml',
  'application/zip': 'zip',
  'application/x-zip-compressed': 'zip',
  'application/x-tar': 'tar',
  'application/gzip': 'gz',
  'application/x-gzip': 'gz',
};
