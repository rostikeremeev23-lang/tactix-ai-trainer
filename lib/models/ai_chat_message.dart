import 'dart:convert';

enum AIChatRole { user, assistant }
enum AIChatContextType { general, coach, debrief }

class AIChatMessage {
  final String id;
  final AIChatRole role;
  final String text;
  final DateTime timestamp;
  final AIChatContextType contextType;

  const AIChatMessage({required this.id, required this.role, required this.text, required this.timestamp, required this.contextType});

  Map<String, dynamic> toJson() => {
    'id': id, 'role': role.name, 'text': text,
    'timestamp': timestamp.toIso8601String(), 'contextType': contextType.name,
  };

  factory AIChatMessage.fromJson(Map<String, dynamic> json) {
    final role = AIChatRole.values.firstWhere((v) => v.name == json['role'], orElse: () => AIChatRole.assistant);
    final context = AIChatContextType.values.firstWhere((v) => v.name == json['contextType'], orElse: () => AIChatContextType.general);
    final text = json['text']?.toString().trim() ?? '';
    if (text.isEmpty) throw const FormatException('Empty chat message');
    return AIChatMessage(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      role: role, text: text,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      contextType: context,
    );
  }

  static List<AIChatMessage> decodeList(List<String> raw) {
    final messages = <AIChatMessage>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map) messages.add(AIChatMessage.fromJson(Map<String, dynamic>.from(decoded)));
      } catch (_) { /* one damaged record must not block chat */ }
    }
    return messages..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }
}