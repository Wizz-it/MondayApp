class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    this.description = '',
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        start: DateTime.parse(json['start'] as String),
        description: json['description'] as String? ?? '',
      );

  final String id;
  String title;
  DateTime start;
  String description;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start': start.toIso8601String(),
        'description': description,
      };
}
