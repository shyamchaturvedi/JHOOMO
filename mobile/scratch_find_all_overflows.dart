import 'dart:io';

void main() {
  final file = File(r'C:\Users\sahil\.gemini\antigravity-ide\brain\f63ee13c-0596-41b3-bc4e-088e2824ec74\.system_generated\tasks\task-859.log');
  if (!file.existsSync()) return;
  final lines = file.readAsLinesSync();
  final seenWidgets = <String>{};

  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('overflowed by')) {
      for (int j = i; j <= i + 15 && j < lines.length; j++) {
        if (lines[j].contains('file:///')) {
          seenWidgets.add('${lines[i].trim()} -> ${lines[j].trim()}');
        }
      }
    }
  }
  for (final w in seenWidgets) {
    print(w);
  }
}
