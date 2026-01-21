import 'package:equatable/equatable.dart';
import '../models/message.dart';

abstract class ChatState extends Equatable {
  final double temperature;
  final String systemPrompt;
  final String provider;
  final String model;
  final Map<String, dynamic>? availableModels;

  const ChatState({
    this.temperature = 0.7,
    this.systemPrompt = '',
    this.provider = 'deepseek',
    this.model = '',
    this.availableModels,
  });

  @override
  List<Object?> get props => [temperature, systemPrompt, provider, model, availableModels];
}

class ChatInitial extends ChatState {
  const ChatInitial({
    super.temperature,
    super.systemPrompt,
    super.provider,
    super.model,
    super.availableModels,
  });
}

class ChatLoading extends ChatState {
  final List<Message> messages;
  final String? currentTopic;

  const ChatLoading(
    this.messages, {
    this.currentTopic,
    super.temperature,
    super.systemPrompt,
    super.provider,
    super.model,
    super.availableModels,
  });

  @override
  List<Object?> get props => [messages, currentTopic, temperature, systemPrompt, provider, model, availableModels];
}

class ChatLoaded extends ChatState {
  final List<Message> messages;
  final String? currentTopic;

  const ChatLoaded(
    this.messages, {
    this.currentTopic,
    super.temperature,
    super.systemPrompt,
    super.provider,
    super.model,
    super.availableModels,
  });

  @override
  List<Object?> get props => [messages, currentTopic, temperature, systemPrompt, provider, model, availableModels];
}

class ChatError extends ChatState {
  final List<Message> messages;
  final String error;

  const ChatError(
    this.messages,
    this.error, {
    super.temperature,
    super.systemPrompt,
    super.provider,
    super.model,
    super.availableModels,
  });

  @override
  List<Object?> get props => [messages, error, temperature, systemPrompt, provider, model, availableModels];
}
