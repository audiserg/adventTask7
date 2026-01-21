import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _temperatureKey = 'temperature';
  static const String _systemPromptKey = 'system_prompt';
  static const double _defaultTemperature = 0.7;
  static const String _defaultSystemPrompt = '';

  // Загрузить температуру
  static Future<double> loadTemperature() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getDouble(_temperatureKey) ?? _defaultTemperature;
      print('SettingsService: Загружена температура: $value');
      return value;
    } catch (e) {
      print('SettingsService: Ошибка при загрузке температуры: $e');
      return _defaultTemperature;
    }
  }

  // Сохранить температуру
  static Future<bool> saveTemperature(double temperature) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = await prefs.setDouble(_temperatureKey, temperature);
      print('SettingsService: Сохранена температура $temperature, результат: $result');
      // Дополнительная проверка - читаем обратно
      final verify = prefs.getDouble(_temperatureKey);
      print('SettingsService: Проверка сохранения - прочитано: $verify');
      return result;
    } catch (e, stackTrace) {
      print('SettingsService: Ошибка при сохранении температуры: $e');
      print('SettingsService: Stack trace: $stackTrace');
      return false;
    }
  }

  // Загрузить системный промпт
  static Future<String> loadSystemPrompt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_systemPromptKey) ?? _defaultSystemPrompt;
      print('SettingsService: Загружен системный промпт (длина: ${value.length})');
      return value;
    } catch (e) {
      print('SettingsService: Ошибка при загрузке системного промпта: $e');
      return _defaultSystemPrompt;
    }
  }

  // Сохранить системный промпт
  static Future<bool> saveSystemPrompt(String systemPrompt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = await prefs.setString(_systemPromptKey, systemPrompt);
      print('SettingsService: Сохранен системный промпт (длина: ${systemPrompt.length}), результат: $result');
      // Дополнительная проверка - читаем обратно
      final verify = prefs.getString(_systemPromptKey);
      print('SettingsService: Проверка сохранения - прочитано (длина: ${verify?.length ?? 0})');
      return result;
    } catch (e, stackTrace) {
      print('SettingsService: Ошибка при сохранении системного промпта: $e');
      print('SettingsService: Stack trace: $stackTrace');
      return false;
    }
  }

  // Загрузить все настройки
  static Future<Map<String, dynamic>> loadAllSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final temperature = prefs.getDouble(_temperatureKey) ?? _defaultTemperature;
      final systemPrompt = prefs.getString(_systemPromptKey) ?? _defaultSystemPrompt;
      print('SettingsService: Загружены все настройки - температура: $temperature, промпт длина: ${systemPrompt.length}');
      return {
        'temperature': temperature,
        'systemPrompt': systemPrompt,
      };
    } catch (e) {
      print('SettingsService: Ошибка при загрузке всех настроек: $e');
      return {
        'temperature': _defaultTemperature,
        'systemPrompt': _defaultSystemPrompt,
      };
    }
  }
}
