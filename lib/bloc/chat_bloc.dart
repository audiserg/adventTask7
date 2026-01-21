import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ApiService _apiService;

  ChatBloc({ApiService? apiService})
      : _apiService = apiService ?? ApiService(),
        super(const ChatInitial()) {
    on<SendMessage>(_onSendMessage);
    on<ClearChat>(_onClearChat);
    on<UpdateTemperature>(_onUpdateTemperature);
    on<UpdateSystemPrompt>(_onUpdateSystemPrompt);
    on<LoadSettings>(_onLoadSettings);
    on<UpdateProvider>(_onUpdateProvider);
    on<UpdateModel>(_onUpdateModel);
    on<LoadModels>(_onLoadModels);
    on<DeleteMessage>(_onDeleteMessage);
    
    // Загружаем настройки при инициализации
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    // Небольшая задержка для инициализации SharedPreferences на веб-платформе
    await Future.delayed(const Duration(milliseconds: 100));
    add(const LoadSettings());
  }

  // Парсинг ответа в формате topic:<Тема>: body:<Ответ>: emotion:<Цвет>:
  Map<String, dynamic> _parseResponse(String response) {
    String? topic;
    String? body;
    Emotion? emotion;

    // Улучшенный парсинг: ищем паттерны topic:, body:, emotion:
    // Формат: topic:Тема: body:Ответ: emotion:Цвет:
    // Разделитель - двоеточие после значения, перед следующим ключевым словом
    
    final lowerResponse = response.toLowerCase();
    
    // Находим позиции всех ключевых слов
    final topicIndex = lowerResponse.indexOf('topic:');
    final bodyIndex = lowerResponse.indexOf('body:');
    final emotionIndex = lowerResponse.indexOf('emotion:');
    
    // Парсим topic: берем текст между "topic:" и следующим ключевым словом или концом
    if (topicIndex != -1) {
      final startPos = topicIndex + 6; // длина "topic:"
      // Определяем конец - следующее ключевое слово или конец строки
      int? endPos;
      if (bodyIndex != -1 && bodyIndex > topicIndex) {
        endPos = bodyIndex;
      } else if (emotionIndex != -1 && emotionIndex > topicIndex) {
        endPos = emotionIndex;
      }
      
      if (endPos != null) {
        // Берем текст между startPos и endPos, ищем последнее двоеточие как разделитель
        final textBetween = response.substring(startPos, endPos);
        final lastColon = textBetween.lastIndexOf(':');
        if (lastColon != -1) {
          topic = textBetween.substring(0, lastColon).trim();
        }
      } else {
        // Нет следующего ключевого слова, ищем последнее двоеточие в оставшемся тексте
        final remainingText = response.substring(startPos);
        final lastColon = remainingText.lastIndexOf(':');
        if (lastColon != -1) {
          topic = remainingText.substring(0, lastColon).trim();
        }
      }
    }
    
    // Парсим body: берем текст между "body:" и "emotion:" или концом
    if (bodyIndex != -1) {
      final startPos = bodyIndex + 5; // длина "body:"
      int? endPos;
      if (emotionIndex != -1 && emotionIndex > bodyIndex) {
        endPos = emotionIndex;
      }
      
      if (endPos != null) {
        final textBetween = response.substring(startPos, endPos);
        final lastColon = textBetween.lastIndexOf(':');
        if (lastColon != -1) {
          body = textBetween.substring(0, lastColon).trim();
        }
      } else {
        // Нет emotion, ищем последнее двоеточие в оставшемся тексте
        final remainingText = response.substring(startPos);
        final lastColon = remainingText.lastIndexOf(':');
        if (lastColon != -1) {
          body = remainingText.substring(0, lastColon).trim();
        } else {
          body = remainingText.trim();
        }
      }
    }
    
    // Парсим emotion: берем текст после "emotion:" до следующего двоеточия или конца
    if (emotionIndex != -1) {
      // Используем оригинальный response для извлечения, но lowerResponse для поиска
      final startPos = emotionIndex + 7; // длина "emotion:"
      final remainingText = response.substring(startPos);
      
      print('DEBUG: emotion found at index $emotionIndex');
      print('DEBUG: remaining text after emotion:: "$remainingText"');
      
      // Ищем двоеточие после emotion (разделитель)
      final colonPos = remainingText.indexOf(':');
      
      String emotionStr;
      if (colonPos != -1) {
        // Есть двоеточие - берем текст до него
        emotionStr = remainingText.substring(0, colonPos).trim().toUpperCase();
        print('DEBUG: Found colon at position $colonPos, emotion string: "$emotionStr"');
      } else {
        // Нет двоеточия - берем весь оставшийся текст (убираем пробелы и переносы строк)
        emotionStr = remainingText.trim().toUpperCase();
        // Убираем возможные переносы строк и лишние символы
        emotionStr = emotionStr.replaceAll(RegExp(r'[\n\r]+'), '');
        emotionStr = emotionStr.split(RegExp(r'[\s:]+')).first; // Берем первое слово/значение
        print('DEBUG: No colon found, extracted emotion string: "$emotionStr"');
      }
      
      // Убираем все лишние символы, оставляем только буквы
      emotionStr = emotionStr.replaceAll(RegExp(r'[^A-Z]'), '');
      print('DEBUG: Final cleaned emotion string: "$emotionStr"');
      
      switch (emotionStr) {
        case 'GREEN':
          emotion = Emotion.green;
          print('DEBUG: ✓ Set emotion to GREEN');
          break;
        case 'BLUE':
          emotion = Emotion.blue;
          print('DEBUG: ✓ Set emotion to BLUE');
          break;
        case 'RED':
          emotion = Emotion.red;
          print('DEBUG: ✓ Set emotion to RED');
          break;
        default:
          print('DEBUG: ✗ Unknown emotion value: "$emotionStr" (length: ${emotionStr.length})');
          // Попробуем найти emotion в тексте другим способом
          final greenMatch = lowerResponse.contains('green');
          final blueMatch = lowerResponse.contains('blue');
          final redMatch = lowerResponse.contains('red');
          print('DEBUG: Fallback check - green: $greenMatch, blue: $blueMatch, red: $redMatch');
          if (greenMatch && !blueMatch && !redMatch) {
            emotion = Emotion.green;
            print('DEBUG: Fallback: Set emotion to GREEN');
          } else if (blueMatch && !greenMatch && !redMatch) {
            emotion = Emotion.blue;
            print('DEBUG: Fallback: Set emotion to BLUE');
          } else if (redMatch && !greenMatch && !blueMatch) {
            emotion = Emotion.red;
            print('DEBUG: Fallback: Set emotion to RED');
          }
      }
    } else {
      print('DEBUG: ✗ emotion: not found in response');
      print('DEBUG: Response preview: ${response.substring(0, response.length > 200 ? 200 : response.length)}...');
    }

    return {
      'topic': topic,
      'body': body ?? response, // Если body не найден, используем весь ответ
      'emotion': emotion,
      'originalText': response,
    };
  }

  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<ChatState> emit,
  ) async {
    // Получаем текущие сообщения и тему
    final currentMessages = state is ChatLoaded
        ? (state as ChatLoaded).messages
        : state is ChatLoading
            ? (state as ChatLoading).messages
            : state is ChatError
                ? (state as ChatError).messages
                : <Message>[];
    
    final currentTopic = state is ChatLoaded
        ? (state as ChatLoaded).currentTopic
        : state is ChatLoading
            ? (state as ChatLoading).currentTopic
            : null;

    // Добавляем сообщение пользователя
    final userMessage = Message(
      text: event.message,
      isUser: true,
    );
    final updatedMessages = [...currentMessages, userMessage];

    // Получаем текущие настройки
    final currentTemperature = state.temperature;
    final currentSystemPrompt = state.systemPrompt;
    
    // Получаем текущие настройки провайдера и модели
    final currentProvider = state.provider;
    final currentModel = state.model;
    final currentAvailableModels = state.availableModels;
    
    // Переходим в состояние загрузки
    emit(ChatLoading(
      updatedMessages,
      currentTopic: currentTopic,
      temperature: currentTemperature,
      systemPrompt: currentSystemPrompt,
      provider: currentProvider,
      model: currentModel,
      availableModels: currentAvailableModels,
    ));

    try {
      // Получаем текущие настройки температуры и системного промпта
      final currentTemperature = state.temperature;
      final currentSystemPrompt = state.systemPrompt;
      final currentProvider = state.provider;
      final currentModel = state.model;
      final currentModelForApi = state.model.isNotEmpty ? state.model : null;
      
      // Отправляем запрос к API
      final response = await _apiService.sendMessage(
        updatedMessages,
        temperature: currentTemperature,
        systemPrompt: currentSystemPrompt.isNotEmpty ? currentSystemPrompt : null,
        provider: currentProvider,
        model: currentModelForApi,
      );

      // Парсим ответ
      final parsed = _parseResponse(response);
      final topic = parsed['topic'] as String?;
      String body = parsed['body'] as String;
      final emotion = parsed['emotion'] as Emotion?;
      
      // Убираем "QUESTION:" из начала текста, если оно есть
      body = body.replaceFirst(RegExp(r'^QUESTION:\s*', caseSensitive: false), '').trim();
      
      // Если body не распарсился (новый формат без topic:body:emotion:), используем весь ответ
      if (body.isEmpty || body == response) {
        body = response;
        // Убираем "QUESTION:" из начала, если есть
        body = body.replaceFirst(RegExp(r'^QUESTION:\s*', caseSensitive: false), '').trim();
      }

      // Отладочный вывод (можно убрать в production)
      print('=== PARSING DEBUG ===');
      print('Original response: $response');
      print('Parsed topic: $topic');
      print('Parsed body length: ${body.length}');
      print('Parsed emotion: $emotion');
      print('Emotion type: ${emotion.runtimeType}');
      print('Emotion is null: ${emotion == null}');
      if (emotion != null) {
        print('Emotion value: ${emotion.toString()}');
      }
      print('===================');

      // Добавляем ответ от ИИ
      final aiMessage = Message(
        text: response,
        isUser: false,
        topic: topic,
        body: body,
        emotion: emotion,
        temperature: currentTemperature,
      );
      
      print('=== MESSAGE CREATION DEBUG ===');
      print('Created message with emotion: ${aiMessage.emotion}');
      print('Message emotion is null: ${aiMessage.emotion == null}');
      print('Message emotion type: ${aiMessage.emotion.runtimeType}');
      print('Message has topic: ${aiMessage.topic != null}');
      print('Message has body: ${aiMessage.body != null}');
      print('==============================');
      
      final finalMessages = [...updatedMessages, aiMessage];

      // Переходим в состояние загружено с темой
      emit(ChatLoaded(
        finalMessages,
        currentTopic: topic,
        temperature: currentTemperature,
        systemPrompt: currentSystemPrompt,
        provider: currentProvider,
        model: currentModel,
        availableModels: currentAvailableModels,
      ));
    } catch (e) {
      // Переходим в состояние ошибки
      String errorMessage = e.toString();
      
      // Убираем префикс "Exception: " если есть
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11);
      }
      
      if (errorMessage.contains('Превышен дневной лимит') || 
          errorMessage.contains('Daily limit exceeded')) {
        // Ошибка лимита - оставляем сообщение как есть
        errorMessage = errorMessage;
      } else if (errorMessage.contains('Failed host lookup') || 
          errorMessage.contains('Connection refused')) {
        errorMessage = 'Не удалось подключиться к серверу. Убедитесь, что бэкенд запущен на порту 3000.';
      } else if (errorMessage.contains('timeout')) {
        errorMessage = 'Превышено время ожидания ответа от сервера.';
      } else if (errorMessage.contains('500') || errorMessage.contains('Server configuration')) {
        errorMessage = 'Ошибка сервера. Проверьте настройку API ключа в .env файле.';
      }
      emit(ChatError(
        updatedMessages,
        errorMessage,
        temperature: currentTemperature,
        systemPrompt: currentSystemPrompt,
        provider: currentProvider,
        model: currentModel,
        availableModels: currentAvailableModels,
      ));
    }
  }

  void _onClearChat(
    ClearChat event,
    Emitter<ChatState> emit,
  ) {
    emit(ChatInitial(
      temperature: state.temperature,
      systemPrompt: state.systemPrompt,
      provider: state.provider,
      model: state.model,
      availableModels: state.availableModels,
    ));
  }

  void _onUpdateTemperature(
    UpdateTemperature event,
    Emitter<ChatState> emit,
  ) async {
    print('ChatBloc: Обновление температуры на ${event.temperature}');
    // Сохраняем настройку
    final saved = await SettingsService.saveTemperature(event.temperature);
    print('ChatBloc: Температура сохранена: $saved');
    
    if (state is ChatLoaded) {
      final currentState = state as ChatLoaded;
      emit(ChatLoaded(
        currentState.messages,
        currentTopic: currentState.currentTopic,
        temperature: event.temperature,
        systemPrompt: currentState.systemPrompt,
        provider: currentState.provider,
        model: currentState.model,
        availableModels: currentState.availableModels,
      ));
    } else if (state is ChatLoading) {
      final currentState = state as ChatLoading;
      emit(ChatLoading(
        currentState.messages,
        currentTopic: currentState.currentTopic,
        temperature: event.temperature,
        systemPrompt: currentState.systemPrompt,
        provider: currentState.provider,
        model: currentState.model,
        availableModels: currentState.availableModels,
      ));
    } else if (state is ChatError) {
      final currentState = state as ChatError;
      emit(ChatError(
        currentState.messages,
        currentState.error,
        temperature: event.temperature,
        systemPrompt: currentState.systemPrompt,
        provider: currentState.provider,
        model: currentState.model,
        availableModels: currentState.availableModels,
      ));
    } else {
      emit(ChatInitial(
        temperature: event.temperature,
        systemPrompt: state.systemPrompt,
        provider: state.provider,
        model: state.model,
        availableModels: state.availableModels,
      ));
    }
  }

  void _onUpdateSystemPrompt(
    UpdateSystemPrompt event,
    Emitter<ChatState> emit,
  ) async {
    print('ChatBloc: Обновление системного промпта (длина: ${event.systemPrompt.length})');
    // Сохраняем настройку
    final saved = await SettingsService.saveSystemPrompt(event.systemPrompt);
    print('ChatBloc: Системный промпт сохранен: $saved');
    
    if (state is ChatLoaded) {
      final currentState = state as ChatLoaded;
      emit(ChatLoaded(
        currentState.messages,
        currentTopic: currentState.currentTopic,
        temperature: currentState.temperature,
        systemPrompt: event.systemPrompt,
        provider: currentState.provider,
        model: currentState.model,
        availableModels: currentState.availableModels,
      ));
    } else if (state is ChatLoading) {
      final currentState = state as ChatLoading;
      emit(ChatLoading(
        currentState.messages,
        currentTopic: currentState.currentTopic,
        temperature: currentState.temperature,
        systemPrompt: event.systemPrompt,
        provider: currentState.provider,
        model: currentState.model,
        availableModels: currentState.availableModels,
      ));
    } else if (state is ChatError) {
      final currentState = state as ChatError;
      emit(ChatError(
        currentState.messages,
        currentState.error,
        temperature: currentState.temperature,
        systemPrompt: event.systemPrompt,
        provider: currentState.provider,
        model: currentState.model,
        availableModels: currentState.availableModels,
      ));
    } else {
      emit(ChatInitial(
        temperature: state.temperature,
        systemPrompt: event.systemPrompt,
        provider: state.provider,
        model: state.model,
        availableModels: state.availableModels,
      ));
    }
  }

  void _onLoadSettings(
    LoadSettings event,
    Emitter<ChatState> emit,
  ) async {
    final settings = await SettingsService.loadAllSettings();
    final temperature = settings['temperature'] as double;
    final systemPrompt = settings['systemPrompt'] as String;
    final provider = settings['provider'] as String? ?? 'deepseek';
    final model = settings['model'] as String? ?? '';
    
    if (state is ChatLoaded) {
      final currentState = state as ChatLoaded;
      emit(ChatLoaded(
        currentState.messages,
        currentTopic: currentState.currentTopic,
        temperature: temperature,
        systemPrompt: systemPrompt,
        provider: provider,
        model: model,
        availableModels: currentState.availableModels,
      ));
    } else if (state is ChatLoading) {
      final currentState = state as ChatLoading;
      emit(ChatLoading(
        currentState.messages,
        currentTopic: currentState.currentTopic,
        temperature: temperature,
        systemPrompt: systemPrompt,
        provider: provider,
        model: model,
        availableModels: currentState.availableModels,
      ));
    } else if (state is ChatError) {
      final currentState = state as ChatError;
      emit(ChatError(
        currentState.messages,
        currentState.error,
        temperature: temperature,
        systemPrompt: systemPrompt,
        provider: provider,
        model: model,
        availableModels: currentState.availableModels,
      ));
    } else {
      emit(ChatInitial(
        temperature: temperature,
        systemPrompt: systemPrompt,
        provider: provider,
        model: model,
        availableModels: state.availableModels,
      ));
    }
  }

  void _onUpdateProvider(
    UpdateProvider event,
    Emitter<ChatState> emit,
  ) async {
    print('ChatBloc: Обновление провайдера на ${event.provider}');
    // Сохраняем настройку
    final saved = await SettingsService.saveProvider(event.provider);
    print('ChatBloc: Провайдер сохранен: $saved');
    
    if (state is ChatLoaded) {
      final currentState = state as ChatLoaded;
      emit(ChatLoaded(
        currentState.messages,
        currentTopic: currentState.currentTopic,
        temperature: currentState.temperature,
        systemPrompt: currentState.systemPrompt,
        provider: event.provider,
        model: currentState.model,
        availableModels: currentState.availableModels,
      ));
    } else if (state is ChatLoading) {
      final currentState = state as ChatLoading;
      emit(ChatLoading(
        currentState.messages,
        currentTopic: currentState.currentTopic,
        temperature: currentState.temperature,
        systemPrompt: currentState.systemPrompt,
        provider: event.provider,
        model: currentState.model,
        availableModels: currentState.availableModels,
      ));
    } else if (state is ChatError) {
      final currentState = state as ChatError;
      emit(ChatError(
        currentState.messages,
        currentState.error,
        temperature: currentState.temperature,
        systemPrompt: currentState.systemPrompt,
        provider: event.provider,
        model: currentState.model,
        availableModels: currentState.availableModels,
      ));
    } else {
      emit(ChatInitial(
        temperature: state.temperature,
        systemPrompt: state.systemPrompt,
        provider: event.provider,
        model: state.model,
        availableModels: state.availableModels,
      ));
    }
  }

  void _onUpdateModel(
    UpdateModel event,
    Emitter<ChatState> emit,
  ) async {
    print('ChatBloc: Обновление модели на ${event.model}');
    // Сохраняем настройку
    final saved = await SettingsService.saveModel(event.model);
    print('ChatBloc: Модель сохранена: $saved');
    
    if (state is ChatLoaded) {
      final currentState = state as ChatLoaded;
      emit(ChatLoaded(
        currentState.messages,
        currentTopic: currentState.currentTopic,
        temperature: currentState.temperature,
        systemPrompt: currentState.systemPrompt,
        provider: currentState.provider,
        model: event.model,
        availableModels: currentState.availableModels,
      ));
    } else if (state is ChatLoading) {
      final currentState = state as ChatLoading;
      emit(ChatLoading(
        currentState.messages,
        currentTopic: currentState.currentTopic,
        temperature: currentState.temperature,
        systemPrompt: currentState.systemPrompt,
        provider: currentState.provider,
        model: event.model,
        availableModels: currentState.availableModels,
      ));
    } else if (state is ChatError) {
      final currentState = state as ChatError;
      emit(ChatError(
        currentState.messages,
        currentState.error,
        temperature: currentState.temperature,
        systemPrompt: currentState.systemPrompt,
        provider: currentState.provider,
        model: event.model,
        availableModels: currentState.availableModels,
      ));
    } else {
      emit(ChatInitial(
        temperature: state.temperature,
        systemPrompt: state.systemPrompt,
        provider: state.provider,
        model: event.model,
        availableModels: state.availableModels,
      ));
    }
  }

  void _onLoadModels(
    LoadModels event,
    Emitter<ChatState> emit,
  ) async {
    try {
      print('ChatBloc: Загрузка списка моделей...');
      final modelsData = await _apiService.getAvailableModels();
      print('ChatBloc: Список моделей загружен');
      
      if (state is ChatLoaded) {
        final currentState = state as ChatLoaded;
        emit(ChatLoaded(
          currentState.messages,
          currentTopic: currentState.currentTopic,
          temperature: currentState.temperature,
          systemPrompt: currentState.systemPrompt,
          provider: currentState.provider,
          model: currentState.model,
          availableModels: modelsData,
        ));
      } else if (state is ChatLoading) {
        final currentState = state as ChatLoading;
        emit(ChatLoading(
          currentState.messages,
          currentTopic: currentState.currentTopic,
          temperature: currentState.temperature,
          systemPrompt: currentState.systemPrompt,
          provider: currentState.provider,
          model: currentState.model,
          availableModels: modelsData,
        ));
      } else if (state is ChatError) {
        final currentState = state as ChatError;
        emit(ChatError(
          currentState.messages,
          currentState.error,
          temperature: currentState.temperature,
          systemPrompt: currentState.systemPrompt,
          provider: currentState.provider,
          model: currentState.model,
          availableModels: modelsData,
        ));
      } else {
        emit(ChatInitial(
          temperature: state.temperature,
          systemPrompt: state.systemPrompt,
          provider: state.provider,
          model: state.model,
          availableModels: modelsData,
        ));
      }
    } catch (e) {
      print('ChatBloc: Ошибка при загрузке списка моделей: $e');
      // Не меняем состояние при ошибке загрузки моделей
    }
  }

  void _onDeleteMessage(
    DeleteMessage event,
    Emitter<ChatState> emit,
  ) {
    // Получаем текущие сообщения
    List<Message> currentMessages = [];
    String? currentTopic;
    
    if (state is ChatLoaded) {
      final currentState = state as ChatLoaded;
      currentMessages = currentState.messages;
      currentTopic = currentState.currentTopic;
    } else if (state is ChatLoading) {
      final currentState = state as ChatLoading;
      currentMessages = currentState.messages;
      currentTopic = currentState.currentTopic;
    } else if (state is ChatError) {
      final currentState = state as ChatError;
      currentMessages = currentState.messages;
      currentTopic = null;
    }
    
    // Проверяем, что индекс валидный
    if (event.messageIndex >= 0 && event.messageIndex < currentMessages.length) {
      // Удаляем сообщение
      final updatedMessages = List<Message>.from(currentMessages);
      updatedMessages.removeAt(event.messageIndex);
      
      // Обновляем состояние
      if (state is ChatLoaded) {
        emit(ChatLoaded(
          updatedMessages,
          currentTopic: currentTopic,
          temperature: state.temperature,
          systemPrompt: state.systemPrompt,
          provider: state.provider,
          model: state.model,
          availableModels: state.availableModels,
        ));
      } else if (state is ChatLoading) {
        emit(ChatLoading(
          updatedMessages,
          currentTopic: currentTopic,
          temperature: state.temperature,
          systemPrompt: state.systemPrompt,
          provider: state.provider,
          model: state.model,
          availableModels: state.availableModels,
        ));
      } else if (state is ChatError) {
        emit(ChatError(
          updatedMessages,
          (state as ChatError).error,
          temperature: state.temperature,
          systemPrompt: state.systemPrompt,
          provider: state.provider,
          model: state.model,
          availableModels: state.availableModels,
        ));
      } else {
        emit(ChatInitial(
          temperature: state.temperature,
          systemPrompt: state.systemPrompt,
          provider: state.provider,
          model: state.model,
          availableModels: state.availableModels,
        ));
      }
    }
  }

  // Получить текущую тему из состояния
  String? getCurrentTopic() {
    if (state is ChatLoaded) {
      return (state as ChatLoaded).currentTopic;
    } else if (state is ChatLoading) {
      return (state as ChatLoading).currentTopic;
    }
    return null;
  }
}
