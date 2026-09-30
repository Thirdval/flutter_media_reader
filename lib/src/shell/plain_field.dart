/// A plain field to type into (MR10): no design system is assumed, so it
/// is Flutter's bare `EditableText` with a hint behind it.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// One line of text in [colour], with [hint] while it is empty.
///
/// The keys a field needs (the arrows, select all) are taken here, before
/// they reach the reader's own shortcuts.
class const MediaReaderPlainField({
  required final TextEditingController controller,
  required final FocusNode focusNode,
  required final Color colour,

  /// What the field is for: shown while it is empty, and what a screen
  /// reader calls it.
  required final String hint,
  final ValueChanged<String>? onChanged,
  final ValueChanged<String>? onSubmitted,

  /// Whether only a number is typed: a page's.
  final bool digitsOnly = false,
  final TextInputAction action = TextInputAction.done,
  final TextAlign textAlign = TextAlign.start,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(color: colour, fontSize: 15);
    return DefaultTextEditingShortcuts(
      child: Semantics(
        label: hint,
        child: Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [
            ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, value, _) => value.text.isNotEmpty
                  ? const SizedBox.shrink()
                  : ExcludeSemantics(
                      child: Text(
                        hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style.copyWith(
                          color: colour.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
            ),
            EditableText(
              controller: controller,
              focusNode: focusNode,
              style: style,
              textAlign: textAlign,
              cursorColor: colour,
              backgroundCursorColor: colour.withValues(alpha: 0.3),
              selectionColor: colour.withValues(alpha: 0.3),
              keyboardType: digitsOnly
                  ? TextInputType.number
                  : TextInputType.text,
              inputFormatters: [
                if (digitsOnly) FilteringTextInputFormatter.digitsOnly,
              ],
              textInputAction: action,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ],
        ),
      ),
    );
  }
}
