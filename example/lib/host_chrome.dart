import 'package:flutter/material.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';

/// What this host knows about a shared file, carried on the item for its
/// chrome.
class const Shared({required final String by, required final String where});

/// A host's chrome: capsules over the canvas, after the file viewer the
/// plan takes as its reference (MEDIA_READER_PLAN.md §1). The top end is
/// left to the package's close button.
final MediaReaderChrome hostChrome = MediaReaderChrome(
  topStart: (context, state) => _Capsule(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(switch (state.item.data) {
          Shared(:final by) => by,
          _ => state.item.name,
        }, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(
          '${state.item.name} · ${state.index + 1} of ${state.count}',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    ),
  ),
  bottomStart: (context, state) => _Capsule(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Action('Reply', onPressed: () {}),
        _Action('Forward', onPressed: () {}),
        // Export is the host's action, and only where its policy allows.
        if (state.canExport) _Action('Share', onPressed: () {}),
      ],
    ),
  ),
  bottomEnd: (context, state) =>
      _Capsule(child: _Action('More', onPressed: () {})),
  contextPill: (context, state) => switch (state.item.data) {
    Shared(:final where) => _Capsule(child: Text('Shared in $where')),
    _ => const SizedBox.shrink(),
  },
  cardActions: (context, state) => state.canExport
      ? FilledButton(onPressed: () {}, child: const Text('Save to device'))
      : const Text(
          'Saving and sharing are turned off in this community.',
          textAlign: TextAlign.center,
        ),
);

class const _Capsule({required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xCC1C1C1E),
    shape: const StadiumBorder(),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: child,
    ),
  );
}

class const _Action(final String label, {required final VoidCallback onPressed})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(foregroundColor: Colors.white),
    child: Text(label),
  );
}
