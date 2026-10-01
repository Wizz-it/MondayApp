import 'tile_tint.dart';

class Project {
  Project({
    required this.id,
    required this.name,
    this.description = '',
    this.tint = TileTint.sage,
  });

  final String id;
  String name;
  String description;
  TileTint tint;
}
