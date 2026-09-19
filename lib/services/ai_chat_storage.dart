import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_chat_message.dart';
import 'user_storage_service.dart';

class AIChatStorage {
  static const _legacyKey = 'tactix_ai_chat';
  static Future<String> _key() async {
    final user = await UserStorageService.loadCurrentUser();
    return user == null ? _legacyKey : '${_legacyKey}_${user.id}';
  }
  static Future<List<AIChatMessage>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AIChatMessage.decodeList(prefs.getStringList(await _key()) ?? const []);
  }
  static Future<void> save(List<AIChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final capped = messages.length > 80 ? messages.sublist(messages.length - 80) : messages;
    await prefs.setStringList(await _key(), capped.map((m) => jsonEncode(m.toJson())).toList());
  }
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(await _key());
  }
}