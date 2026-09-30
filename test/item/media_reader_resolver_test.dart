import 'dart:async';

import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  group('MediaReaderResolver', () {
    late DateTime now;
    setUp(() => now = DateTime(2026, 9, 30, 12));

    MediaReaderResolver resolverOf(FakeResolve host) =>
        MediaReaderResolver(MediaReaderRemoteSource(host.call), now: () => now);

    test('a location is asked for once and kept while it is valid', () async {
      final host = FakeResolve(
        validFor: const Duration(minutes: 15),
        now: () => now,
      );
      final resolver = resolverOf(host);

      final first = await resolver.resolve();
      now = now.add(const Duration(minutes: 14));
      final second = await resolver.resolve();

      expect(host.calls, 1);
      expect(second.uri, first.uri);
    });

    test('a location about to expire is asked for again', () async {
      final host = FakeResolve(
        validFor: const Duration(minutes: 15),
        now: () => now,
      );
      final resolver = resolverOf(host);

      final first = await resolver.resolve();
      // Inside the margin: a request made now might arrive too late.
      now = now.add(const Duration(minutes: 14, seconds: 45));
      final second = await resolver.resolve();

      expect(host.calls, 2);
      expect(second.uri, isNot(first.uri));
    });

    test('a location with no expiry is kept until it is refused', () async {
      final host = FakeResolve();
      final resolver = resolverOf(host);

      final first = await resolver.resolve();
      now = now.add(const Duration(days: 1));
      expect((await resolver.resolve()).uri, first.uri);
      expect(host.calls, 1);

      final renewed = await resolver.renew(first);
      expect(host.calls, 2);
      expect(renewed.uri, isNot(first.uri));
      expect((await resolver.resolve()).uri, renewed.uri);
    });

    test('a caller holding an older location gets the renewed one', () async {
      final host = FakeResolve();
      final resolver = resolverOf(host);

      final first = await resolver.resolve();
      final renewed = await resolver.renew(first);
      // A second engine request, still holding the refused location.
      final again = await resolver.renew(first);

      expect(again.uri, renewed.uri);
      expect(host.calls, 2);
    });

    test('concurrent callers share one call to the host', () async {
      final answer = Completer<MediaReaderLocation>();
      var calls = 0;
      final resolver = MediaReaderResolver(
        MediaReaderRemoteSource(() {
          calls++;
          return answer.future;
        }),
      );

      final both = Future.wait([resolver.resolve(), resolver.resolve()]);
      answer.complete(MediaReaderLocation(Uri.parse('https://files.test/a')));
      final [first, second] = await both;

      expect(calls, 1);
      expect(first.uri, second.uri);
    });

    test('a failed resolve is not kept: the next call asks again', () async {
      final host = FakeResolve()..failure = StateError('offline');
      final resolver = resolverOf(host);

      await expectLater(resolver.resolve(), throwsStateError);
      host.failure = null;
      final location = await resolver.resolve();

      expect(host.calls, 2);
      expect(location.uri, Uri.parse('https://files.test/2'));
    });

    test('a resolve that throws at once is not kept either', () async {
      var calls = 0;
      final resolver = MediaReaderResolver(
        MediaReaderRemoteSource(() {
          calls++;
          if (calls == 1) throw StateError('no session');
          return Future.value(
            MediaReaderLocation(Uri.parse('https://files.test/$calls')),
          );
        }),
      );

      await expectLater(resolver.resolve(), throwsStateError);
      expect((await resolver.resolve()).uri, Uri.parse('https://files.test/2'));
    });

    test('the source can be replaced and the kept location stays', () async {
      final host = FakeResolve();
      final other = FakeResolve();
      final resolver = resolverOf(host);

      final first = await resolver.resolve();
      resolver.source = MediaReaderRemoteSource(other.call);

      expect((await resolver.resolve()).uri, first.uri);
      expect(other.calls, 0);
      await resolver.renew(first);
      expect(other.calls, 1);
    });
  });
}
