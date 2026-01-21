import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/chat_bloc.dart';
import 'bloc/chat_state.dart';
import 'bloc/chat_event.dart';
import 'models/message.dart';
import 'widgets/chat_message.dart';
import 'widgets/chat_input.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Лучший диалог с LLM',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: BlocProvider(
        create: (context) => ChatBloc(),
        child: const ChatScreen(),
      ),
    );
  }
}

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<ChatBloc, ChatState>(
          builder: (context, state) {
            String title = 'Лучший диалог с LLM';
            if (state is ChatLoaded && state.currentTopic != null) {
              title = state.currentTopic!;
            } else if (state is ChatLoading && state.currentTopic != null) {
              title = state.currentTopic!;
            }
            return Text(title);
          },
        ),
        centerTitle: true,
        actions: [
          // Иконка настройки температуры
          BlocBuilder<ChatBloc, ChatState>(
            builder: (context, state) {
              return IconButton(
                icon: const Icon(Icons.thermostat),
                tooltip: 'Настройка температуры',
                onPressed: () => _showTemperatureDialog(context, state.temperature),
              );
            },
          ),
          // Иконка настройки системного промпта
          BlocBuilder<ChatBloc, ChatState>(
            builder: (context, state) {
              return IconButton(
                icon: const Icon(Icons.settings_applications),
                tooltip: 'Настройка системного промпта',
                onPressed: () => _showSystemPromptDialog(context, state.systemPrompt),
              );
            },
          ),
          BlocBuilder<ChatBloc, ChatState>(
            builder: (context, state) {
              final hasMessages = state is ChatLoaded ||
                  state is ChatLoading ||
                  (state is ChatError && state.messages.isNotEmpty);

              if (!hasMessages) {
                return const SizedBox.shrink();
              }

              return IconButton(
                icon: const Icon(Icons.clear_all),
                tooltip: 'Очистить чат',
                onPressed: () {
                  context.read<ChatBloc>().add(const ClearChat());
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                if (state is ChatInitial) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Начните разговор с ИИ',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                        ),
                      ],
                    ),
                  );
                }

                List<Message> messages = [];
                if (state is ChatLoading) {
                  messages = state.messages;
                } else if (state is ChatLoaded) {
                  messages = state.messages;
                } else if (state is ChatError) {
                  messages = state.messages;
                }

                if (messages.isEmpty) {
                  return const Center(child: Text('Нет сообщений'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length + (state is ChatLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < messages.length) {
                      return ChatMessageWidget(message: messages[index]);
                    } else {
                      // Показываем индикатор загрузки
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
          BlocBuilder<ChatBloc, ChatState>(
            builder: (context, state) {
              if (state is ChatError) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const ChatInputWidget(),
        ],
      ),
    );
  }

  static void _showTemperatureDialog(BuildContext context, double currentTemperature) {
    final controller = TextEditingController(text: currentTemperature.toString());
    // Получаем ChatBloc из правильного контекста до создания диалога
    final chatBloc = context.read<ChatBloc>();
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Настройка температуры'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Температура (0.0 - 2.0)',
                  hintText: '0.7',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              const Text(
                'Температура контролирует случайность ответов:\n'
                '• 0.0 - более детерминированные ответы\n'
                '• 0.7 - баланс (рекомендуется)\n'
                '• 2.0 - более креативные ответы',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () async {
                final value = double.tryParse(controller.text);
                if (value != null && value >= 0.0 && value <= 2.0) {
                  chatBloc.add(UpdateTemperature(value));
                  Navigator.of(dialogContext).pop();
                  // Показываем подтверждение - используем оригинальный контекст
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Температура сохранена: ${value.toStringAsFixed(1)}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Введите значение от 0.0 до 2.0'),
                    ),
                  );
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  static void _showSystemPromptDialog(BuildContext context, String currentSystemPrompt) {
    final controller = TextEditingController(text: currentSystemPrompt);
    // Получаем ChatBloc из правильного контекста до создания диалога
    final chatBloc = context.read<ChatBloc>();
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Настройка системного промпта'),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Системный промпт',
                hintText: 'Оставьте пустым для использования по умолчанию',
                alignLabelWithHint: true,
              ),
              maxLines: 10,
              minLines: 5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                chatBloc.add(UpdateSystemPrompt(controller.text));
                Navigator.of(dialogContext).pop();
                // Показываем подтверждение - используем оригинальный контекст
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(controller.text.isEmpty 
                        ? 'Системный промпт сброшен (будет использован по умолчанию)'
                        : 'Системный промпт сохранен'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }
}
