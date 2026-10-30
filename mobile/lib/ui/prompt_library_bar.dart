import 'package:flutter/material.dart';

/// One button of a [PromptLibraryBar].
typedef PromptLibraryAction = ({
  Key key,
  IconData icon,
  String label,
  VoidCallback? onPressed,
});

/// Saved-prompt library buttons that stay visible under a prompt field, like
/// the desktop app's library bar: equal-width buttons in one row. Where the
/// labels would not fit on one line, the row drops its icons first and then
/// stacks the buttons full-width (narrow phones, large text).
class PromptLibraryBar extends StatelessWidget {
  final List<PromptLibraryAction> actions;
  final String? semanticLabel;

  const PromptLibraryBar({
    super.key,
    required this.actions,
    this.semanticLabel,
  });

  static const _gap = 8.0;
  static const _iconSize = 16.0;
  // Narrow side padding so the three positive actions share one row on
  // 375-point-wide iPhones at the default text size.
  static const _padding = EdgeInsets.symmetric(horizontal: 6, vertical: 8);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    // OutlinedButton.icon's icon-label gap: 8, shrinking to 4 at double text.
    final iconGap =
        8 - 4 * ((scaler.scale(14) / 14).clamp(1.0, 2.0) - 1);
    double labelWidth(String label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final buttonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: _padding,
    );
    Widget button(PromptLibraryAction action, {required bool icon}) => icon
        ? OutlinedButton.icon(
            key: action.key,
            onPressed: action.onPressed,
            icon: Icon(action.icon, size: _iconSize),
            label: Text(action.label, textAlign: TextAlign.center),
            style: buttonStyle,
          )
        : OutlinedButton(
            key: action.key,
            onPressed: action.onPressed,
            style: buttonStyle,
            child: Text(action.label, textAlign: TextAlign.center),
          );

    return Semantics(
      container: true,
      label: semanticLabel,
      child: LayoutBuilder(
        builder: (context, box) {
          final share =
              (box.maxWidth - _gap * (actions.length - 1)) / actions.length;
          final widest = actions
              .map((action) => labelWidth(action.label))
              .reduce((a, b) => a > b ? a : b);
          final withIcons =
              widest + _iconSize + iconGap + _padding.horizontal <= share;
          if (withIcons || widest + _padding.horizontal <= share) {
            return Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  Expanded(child: button(actions[i], icon: withIcons)),
                ],
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(height: _gap),
                button(actions[i], icon: true),
              ],
            ],
          );
        },
      ),
    );
  }
}
