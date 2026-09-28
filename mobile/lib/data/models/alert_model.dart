/// Marine weather alert record for offline emergency display.
class AlertModel {
  final String id;
  final String alertLevel;
  final String messageSinhala;
  final String messageTamil;
  final String messageEnglish;
  final String triggerCause;
  final String createdAt;

  AlertModel({
    required this.id,
    required this.alertLevel,
    required this.messageSinhala,
    required this.messageTamil,
    required this.messageEnglish,
    required this.triggerCause,
    required this.createdAt,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id']?.toString() ?? '',
      alertLevel: json['alert_level']?.toString() ?? 'warning',
      messageSinhala: json['message_sinhala']?.toString() ?? '',
      messageTamil: json['message_tamil']?.toString() ?? '',
      messageEnglish: json['message_english']?.toString() ?? '',
      triggerCause: json['trigger_cause']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  factory AlertModel.fromDbMap(Map<String, dynamic> map) {
    return AlertModel(
      id: map['id'] as String,
      alertLevel: map['alert_level'] as String,
      messageSinhala: map['message_sinhala'] as String,
      messageTamil: map['message_tamil'] as String,
      messageEnglish: map['message_english'] as String,
      triggerCause: map['trigger_cause'] as String,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'alert_level': alertLevel,
      'message_sinhala': messageSinhala,
      'message_tamil': messageTamil,
      'message_english': messageEnglish,
      'trigger_cause': triggerCause,
      'created_at': createdAt,
    };
  }

  String getLocalizedMessage(String lang) {
    if (lang == 'si') return messageSinhala.isNotEmpty ? messageSinhala : messageEnglish;
    if (lang == 'ta') return messageTamil.isNotEmpty ? messageTamil : messageEnglish;
    return messageEnglish;
  }
}
