import 'package:flutter_media_reader/src/engine/text/text_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('prettyJson', () {
    test('puts each member on a line of its own, indented by its depth', () {
      expect(
        prettyJson('{"name":"Rota","weeks":[1,2],"who":{"lead":"Ruth"}}'),
        '{\n'
        '  "name": "Rota",\n'
        '  "weeks": [\n'
        '    1,\n'
        '    2\n'
        '  ],\n'
        '  "who": {\n'
        '    "lead": "Ruth"\n'
        '  }\n'
        '}',
      );
    });

    test('keeps every value as the file has it', () {
      const written =
          '{ "id": 90071992547409931234, "rate": 1.0, "big": 1e3, '
          r'"text": "a {b}: [c], \"d\"\\" , "none": null, "ok": true }';

      final pretty = prettyJson(written)!;

      for (final value in [
        '90071992547409931234',
        '1.0',
        '1e3',
        r'"a {b}: [c], \"d\"\\"',
        'null',
        'true',
      ]) {
        expect(pretty, contains(value));
      }
    });

    test('closes what is empty on the same line', () {
      expect(prettyJson('{"a":{},"b":[ ]}'), '{\n  "a": {},\n  "b": []\n}');
    });

    test('lays out what is laid out already the same', () {
      const written = '{\n\t"a": [\n\t\t1\n\t]\n}\n';

      expect(prettyJson(written), '{\n  "a": [\n    1\n  ]\n}');
    });

    test('leaves what is not JSON alone', () {
      expect(prettyJson('{"a": '), isNull);
      expect(prettyJson('hello'), isNull);
    });
  });

  group('prettyXml', () {
    test('puts each element on a line of its own, indented by its depth', () {
      expect(
        prettyXml(
          '<?xml version="1.0"?><rota week="40"><slot>'
          '<who>Ruth</who><what>Welcome</what></slot><slot/></rota>',
        ),
        '<?xml version="1.0"?>\n'
        '<rota week="40">\n'
        '  <slot>\n'
        '    <who>Ruth</who>\n'
        '    <what>Welcome</what>\n'
        '  </slot>\n'
        '  <slot/>\n'
        '</rota>',
      );
    });

    test('keeps comments, and what CDATA holds, as they are', () {
      expect(
        prettyXml('<a><!-- a > b --><b><![CDATA[1 < 2]]></b><c></c></a>'),
        '<a>\n'
        '  <!-- a > b -->\n'
        '  <b><![CDATA[1 < 2]]></b>\n'
        '  <c></c>\n'
        '</a>',
      );
    });

    test('lays out what is laid out already the same', () {
      expect(
        prettyXml('<a>\n    <b>text</b>\n</a>\n'),
        '<a>\n  <b>text</b>\n</a>',
      );
    });

    test('leaves alone what does not pair up', () {
      expect(prettyXml('<a><b></a>'), isNull);
      expect(prettyXml('</a>'), isNull);
      expect(prettyXml('<a'), isNull);
    });
  });
}
