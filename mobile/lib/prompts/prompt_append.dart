/// Appends saved prompt text after the current prompt with one comma
/// separator. The saved text keeps its literal weights, repetitions and line
/// breaks; only whitespace at the join point is dropped. Mirrors the desktop
/// app's src/prompt-append.ts.
String appendPromptText(String current, String addition) {
  if (addition.trim().isEmpty) return current;
  if (current.trim().isEmpty) return addition;
  final base = current.trimRight();
  final separator = RegExp(r'[,，]$').hasMatch(base) ? ' ' : ', ';
  return '$base$separator${addition.trimLeft()}';
}

/// Inserts a saved prompt chunk at the end of the prompt, followed by ", " so
/// the next tag can be typed straight away. Mirrors the desktop app's
/// appendPromptChunk in src/PromptChunks.tsx.
String appendPromptChunk(String value, String chunk) {
  final current = value.trim();
  final addition = chunk
      .trim()
      .replaceFirst(RegExp(r'^,+\s*'), '')
      .replaceFirst(RegExp(r'\s*,+$'), '');
  if (addition.isEmpty) return value;
  if (current.isEmpty) return '$addition, ';
  return '${current.replaceFirst(RegExp(r'\s*,?\s*$'), '')}, $addition, ';
}
