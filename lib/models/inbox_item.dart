class InboxItem {
  InboxItem({
    required this.id,
    required this.text,
    required this.capturedAt,
  });

  factory InboxItem.fromJson(Map<String, dynamic> json) => InboxItem(
        id: json['id'] as String,
        text: json['text'] as String,
        capturedAt: DateTime.parse(json['capturedAt'] as String),
      );

  final String id;
  String text;
  final DateTime capturedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'capturedAt': capturedAt.toIso8601String(),
      };
}
