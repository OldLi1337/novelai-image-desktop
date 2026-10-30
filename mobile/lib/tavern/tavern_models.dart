import 'dart:math';

String tavernNow() => DateTime.now().toUtc().toIso8601String();

String tavernId([String prefix = 'tavern']) {
  final now = DateTime.now().microsecondsSinceEpoch;
  final random = Random.secure().nextInt(1 << 32).toRadixString(16);
  return '$prefix-$now-$random';
}

String _string(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

int _integer(Object? value, int fallback, int minimum, int maximum) {
  final parsed = value is num ? value.round() : int.tryParse('$value');
  return (parsed ?? fallback).clamp(minimum, maximum);
}

double _number(Object? value, double fallback, double minimum, double maximum) {
  final parsed = value is num ? value.toDouble() : double.tryParse('$value');
  return (parsed ?? fallback).clamp(minimum, maximum).toDouble();
}

List<String> _strings(Object? value) => value is List
    ? value
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList()
    : <String>[];

class TavernSamplerPreset {
  String id;
  String name;
  String systemPrompt;
  String jailbreakPrompt;
  double temperature;
  double topP;
  double frequencyPenalty;
  double presencePenalty;
  int? maxOutputTokens;
  List<String> stop;
  String? source;
  String? sourceName;
  String? sourceHash;
  String createdAt;
  String updatedAt;

  TavernSamplerPreset({
    String? id,
    this.name = '沉浸叙事',
    this.systemPrompt =
        'You are {{char}}. Stay in character, write vivid dialogue and actions, and never describe yourself as an AI or assistant.',
    this.jailbreakPrompt =
        'Continue the scene naturally. Respect established characterization, world facts, and the user\'s latest intent.',
    this.temperature = .9,
    this.topP = .95,
    this.frequencyPenalty = 0,
    this.presencePenalty = 0,
    this.maxOutputTokens,
    List<String>? stop,
    this.source = 'langbai',
    this.sourceName,
    this.sourceHash,
    String? createdAt,
    String? updatedAt,
  })  : id = id ?? tavernId('sampler'),
        stop = stop ?? [],
        createdAt = createdAt ?? tavernNow(),
        updatedAt = updatedAt ?? tavernNow();

  factory TavernSamplerPreset.fromJson(Map<String, dynamic> json) =>
      TavernSamplerPreset(
        id: _string(json['id'], tavernId('sampler')),
        name: _string(json['name'], '沉浸叙事'),
        systemPrompt: _string(
            json['systemPrompt'], 'You are {{char}}. Stay in character.'),
        jailbreakPrompt: _string(json['jailbreakPrompt']),
        temperature: _number(json['temperature'], .9, 0, 2),
        topP: _number(json['topP'], .95, 0, 1),
        frequencyPenalty: _number(json['frequencyPenalty'], 0, -2, 2),
        presencePenalty: _number(json['presencePenalty'], 0, -2, 2),
        maxOutputTokens: json['maxOutputTokens'] is num
            ? _integer(json['maxOutputTokens'], 4096, 128, 131072)
            : null,
        stop: _strings(json['stop']),
        source: const {'builtin', 'sillytavern-json', 'langbai'}
                .contains(json['source']?.toString())
            ? json['source'].toString()
            : null,
        sourceName: json['sourceName']?.toString(),
        sourceHash: json['sourceHash']?.toString(),
        createdAt: _string(json['createdAt'], tavernNow()),
        updatedAt: _string(json['updatedAt'], tavernNow()),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'systemPrompt': systemPrompt,
        'jailbreakPrompt': jailbreakPrompt,
        'temperature': temperature,
        'topP': topP,
        'frequencyPenalty': frequencyPenalty,
        'presencePenalty': presencePenalty,
        if (maxOutputTokens != null) 'maxOutputTokens': maxOutputTokens,
        'stop': stop,
        if (source != null) 'source': source,
        if (sourceName != null) 'sourceName': sourceName,
        if (sourceHash != null) 'sourceHash': sourceHash,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}
