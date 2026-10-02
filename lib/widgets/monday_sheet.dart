import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';
import 'monday_buttons.dart';
import 'screen_header.dart';

/// Opens a creation sheet using the design's shared presentation: rounded top
/// corners, a tinted scrim and room for the keyboard.
Future<T?> showMondaySheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: builder(context),
    ),
  );
}

/// The shared chrome of every creation sheet: drag handle, "MAKE IT HAPPEN"
/// eyebrow, title, close control and a full-width call to action.
class MondaySheet extends StatelessWidget {
  const MondaySheet({
    super.key,
    required this.title,
    required this.children,
    required this.actionLabel,
    required this.onAction,
    this.eyebrow = 'MAKE IT HAPPEN',
  });

  final String title;
  final List<Widget> children;
  final String actionLabel;

  /// A null callback renders the action in its disabled state.
  final VoidCallback? onAction;
  final String eyebrow;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(MondayRadius.sheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: EyebrowLabel(eyebrow),
                      ),
                    ),
                    MondayCircleButton(
                      icon: Icons.close,
                      onPressed: () => Navigator.of(context).pop(),
                      background: p.surfaceMuted,
                      foreground: p.inkMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: MondayType.sheetTitle.copyWith(color: p.ink),
                ),
                const SizedBox(height: 26),
                ...children,
                const SizedBox(height: 28),
                MondayPrimaryButton(label: actionLabel, onPressed: onAction),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled field slot, with the design's optional "OPTIONAL" marker.
class MondayField extends StatelessWidget {
  const MondayField({
    super.key,
    required this.label,
    required this.child,
    this.optional = false,
  });

  final String label;
  final Widget child;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: MondayType.fieldLabel.copyWith(color: p.ink),
              ),
            ),
            if (optional)
              Text(
                'OPTIONAL',
                style: MondayType.eyebrow.copyWith(
                  color: p.inkFaint,
                  fontSize: 10,
                ),
              ),
          ],
        ),
        const SizedBox(height: 9),
        child,
      ],
    );
  }
}

/// Text input styled to match the sheets: recessed fill, hairline border and a
/// green focus ring.
class MondayTextField extends StatelessWidget {
  const MondayTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.maxLines = 1,
    this.autofocus = false,
    this.readOnly = false,
    this.suffixIcon,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String? hintText;
  final int maxLines;
  final bool autofocus;
  final bool readOnly;
  final Widget? suffixIcon;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(MondayRadius.field),
          borderSide: BorderSide(color: color, width: width),
        );

    return TextField(
      controller: controller,
      maxLines: maxLines,
      autofocus: autofocus,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      style: MondayType.body.copyWith(color: p.ink),
      cursorColor: p.green,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: MondayType.body.copyWith(color: p.inkFaint),
        filled: true,
        fillColor: p.surfaceMuted,
        isDense: true,
        suffixIcon: suffixIcon,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border(p.hairline),
        enabledBorder: border(p.hairline),
        focusedBorder: border(p.green, 1.6),
      ),
    );
  }
}

/// A read-only field that opens a chooser. Visually identical to
/// [MondayTextField] so priority and project sit beside the typed fields
/// without introducing a second form style.
class MondaySelectField extends StatelessWidget {
  const MondaySelectField({
    super.key,
    required this.value,
    required this.onTap,
    this.icon = Icons.expand_more,
    this.placeholder = false,
  });

  final String value;
  final VoidCallback onTap;
  final IconData icon;

  /// Renders [value] in the hint colour, for "No project" style empties.
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surfaceMuted,
      borderRadius: BorderRadius.circular(MondayRadius.field),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MondayRadius.field),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MondayRadius.field),
            border: Border.all(color: p.hairline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: MondayType.body.copyWith(
                    color: placeholder ? p.inkFaint : p.ink,
                  ),
                ),
              ),
              Icon(icon, size: 18, color: p.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact chooser sheet used by [MondaySelectField]. Returns the picked
/// value, or null if dismissed.
Future<T?> showMondayOptionSheet<T>({
  required BuildContext context,
  required String title,
  required List<({T value, String label})> options,
  T? selected,
}) {
  return showMondaySheet<T>(
    context: context,
    builder: (context) {
      final p = context.palette;
      return Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(MondayRadius.sheet),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: EyebrowLabel(title.toUpperCase()),
              ),
              const SizedBox(height: 14),
              for (final option in options)
                InkWell(
                  onTap: () => Navigator.of(context).pop(option.value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.label,
                            style: MondayType.rowTitle.copyWith(color: p.ink),
                          ),
                        ),
                        if (option.value == selected)
                          Icon(Icons.check, size: 19, color: p.green),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    },
  );
}
