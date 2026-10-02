class Note {
  Note({required this.id, required this.title, this.body = ''});

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String? ?? '',
      );

  final String id;
  String title;
  String body;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'body': body};
}
