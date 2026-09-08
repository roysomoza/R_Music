class FolderModel {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<String> trackPaths;

  FolderModel({
    required this.id,
    required this.name,
    required this.createdAt,
    List<String>? trackPaths,
  }) : trackPaths = trackPaths ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'trackPaths': trackPaths,
      };

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    return FolderModel(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      trackPaths: (json['trackPaths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  FolderModel copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    List<String>? trackPaths,
  }) {
    return FolderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      trackPaths: trackPaths ?? List.from(this.trackPaths),
    );
  }
}
