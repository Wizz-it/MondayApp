class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    this.description = '',
  });

  final String id;
  String title;
  DateTime start;
  String description;
}
