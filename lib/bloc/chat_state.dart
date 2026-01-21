import 'package:equatable/equatable.dart';
import '../models/message.dart';

abstract class ChatState extends Equatable {
  final double temperature;
  final String systemPrompt;

  const ChatState({
    this.temperature = 0.7,
    this.systemPrompt = '',
  });

  @override
  List<Object?> get props => [temperature, systemPrompt];
}

class ChatInitial extends ChatState {
  const ChatInitial({
    super.temperature,
    super.systemPrompt,
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
  });

  @override
  List<Object?> get props => [messages, currentTopic, temperature, systemPrompt];
}

class ChatLoaded extends ChatState {
  final List<Message> messages;
  final String? currentTopic;

  const ChatLoaded(
    this.messages, {
    this.currentTopic,
    super.temperature,
    super.systemPrompt,
  });

  @override
  List<Object?> get props => [messages, currentTopic, temperature, systemPrompt];
}

class ChatError extends ChatState {
  final List<Message> messages;
  final String error;

  const ChatError(
    this.messages,
    this.error, {
    super.temperature,
    super.systemPrompt,
  });

  @override
  List<Object?> get props => [messages, error, temperature, systemPrompt];
}
