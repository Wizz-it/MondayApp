import 'tile_tint.dart';

class Project {
  Project({
    required this.id,
    required this.name,
    this.description = '',
    this.tint = TileTint.sage,
  });

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        tint: TileTint.values.asNameMap()[json['tint']] ?? TileTint.sage,
      );

  final String id;
  String name;
  String description;
  TileTint tint;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'tint': tint.name,
      };
}
