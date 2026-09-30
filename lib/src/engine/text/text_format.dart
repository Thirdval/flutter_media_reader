/// JSON and XML laid out to be read (MEDIA_READER_PLAN.md R6). Only the
/// space between the parts changes: every name, number and string stays
/// as the file has it.
library;

import 'dart:convert';

/// [text] with each member and element on a line of its own, indented by
/// its depth. Null when [text] is not JSON.
String? prettyJson(String text) {
  try {
    jsonDecode(text);
  } on FormatException {
    return null;
  }
  final out = StringBuffer();
  var depth = 0;
  void line() => out
    ..write('\n')
    ..write('  ' * depth);
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    switch (char) {
      case '"':
        // A string, copied as it is, its escapes with it.
        final start = i;
        for (i++; i < text.length && text[i] != '"'; i++) {
          if (text[i] == r'\') i++;
        }
        out.write(text.substring(start, i + 1));
      case '{' || '[':
        out.write(char);
        // Nothing in it: it closes on the same line.
        var next = i + 1;
        while (next < text.length && _space.contains(text[next])) {
          next++;
        }
        if (next < text.length && (text[next] == '}' || text[next] == ']')) {
          out.write(text[next]);
          i = next;
        } else {
          depth++;
          line();
        }
      case '}' || ']':
        depth--;
        line();
        out.write(char);
      case ',':
        out.write(char);
        line();
      case ':':
        out.write(': ');
      case ' ' || '\n' || '\r' || '\t':
        break;
      default:
        out.write(char);
    }
  }
  return out.toString();
}

const _space = {' ', '\n', '\r', '\t'};

/// [text] with each element on a line of its own, indented by its depth.
/// An element that holds only text stays on one line with it. Null when
/// the tags of [text] do not pair up.
String? prettyXml(String text) {
  final tokens = <({String kind, String raw})>[];
  var at = 0;
  while (at < text.length) {
    if (text[at] != '<') {
      final end = text.indexOf('<', at);
      final raw = text.substring(at, end < 0 ? text.length : end);
      if (raw.trim().isNotEmpty) tokens.add((kind: 'text', raw: raw.trim()));
      at = end < 0 ? text.length : end;
      continue;
    }
    // What a tag ends with depends on what it is.
    final (kind, close) = switch (text) {
      _ when text.startsWith('<!--', at) => ('other', '-->'),
      _ when text.startsWith('<![CDATA[', at) => ('text', ']]>'),
      _ when text.startsWith('<?', at) => ('other', '?>'),
      _ when text.startsWith('<!', at) => ('other', '>'),
      _ when text.startsWith('</', at) => ('close', '>'),
      _ => ('open', '>'),
    };
    final end = text.indexOf(close, at);
    if (end < 0) return null;
    final raw = text.substring(at, end + close.length);
    tokens.add((
      kind: kind == 'open' && raw.endsWith('/>') ? 'other' : kind,
      raw: raw,
    ));
    at = end + close.length;
  }

  final out = <String>[];
  var depth = 0;
  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    switch (token.kind) {
      case 'open':
        // <a>text</a> stays together.
        if (i + 2 < tokens.length &&
            tokens[i + 1].kind == 'text' &&
            tokens[i + 2].kind == 'close') {
          out.add(
            '${'  ' * depth}${token.raw}${tokens[i + 1].raw}'
            '${tokens[i + 2].raw}',
          );
          i += 2;
        } else if (i + 1 < tokens.length && tokens[i + 1].kind == 'close') {
          out.add('${'  ' * depth}${token.raw}${tokens[i + 1].raw}');
          i += 1;
        } else {
          out.add('${'  ' * depth}${token.raw}');
          depth++;
        }
      case 'close':
        depth--;
        if (depth < 0) return null;
        out.add('${'  ' * depth}${token.raw}');
      default:
        out.add('${'  ' * depth}${token.raw}');
    }
  }
  return depth == 0 ? out.join('\n') : null;
}
