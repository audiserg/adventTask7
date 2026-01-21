import 'package:equatable/equatable.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class SendMessage extends ChatEvent {
  final String message;

  const SendMessage(this.message);

  @override
  List<Object?> get props => [message];
}

class ClearChat extends ChatEvent {
  const ClearChat();
}

class UpdateTemperature extends ChatEvent {
  final double temperature;

  const UpdateTemperature(this.temperature);

  @override
  List<Object?> get props => [temperature];
}

class UpdateSystemPrompt extends ChatEvent {
  final String systemPrompt;

  const UpdateSystemPrompt(this.systemPrompt);

  @override
  List<Object?> get props => [systemPrompt];
}

class LoadSettings extends ChatEvent {
  const LoadSettings();
}
