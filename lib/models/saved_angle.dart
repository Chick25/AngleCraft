class GhostTransform {
  final double offsetX;
  final double offsetY;
  final double scale;
  final double rotation;

  const GhostTransform({
    this.offsetX = 0,
    this.offsetY = 0,
    this.scale = 1,
    this.rotation = 0,
  });

  Map<String, dynamic> toMap() => {
    'offsetX': offsetX,
    'offsetY': offsetY,
    'scale': scale,
    'rotation': rotation,
  };

  factory GhostTransform.fromMap(Map<dynamic, dynamic>? map) {
    return GhostTransform(
      offsetX: (map?['offsetX'] as num?)?.toDouble() ?? 0,
      offsetY: (map?['offsetY'] as num?)?.toDouble() ?? 0,
      scale: (map?['scale'] as num?)?.toDouble() ?? 1,
      rotation: (map?['rotation'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SavedAngle {
  final String id;
  final String name;
  final DateTime createdAt;
  final String photoPath;
  final String? ghostImagePath;
  final String? poseId;
  final String gridType;
  final bool isGridVisible;
  final double gridOpacity;
  final double ghostOpacity;
  final GhostTransform ghostTransform;
  final bool isFavorite;

  const SavedAngle({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.photoPath,
    this.ghostImagePath,
    this.poseId,
    this.gridType = 'thirds',
    this.isGridVisible = true,
    this.gridOpacity = 0.72,
    this.ghostOpacity = 0.4,
    this.ghostTransform = const GhostTransform(),
    this.isFavorite = false,
  });

  SavedAngle copyWith({
    String? name,
    bool? isFavorite,
    String? photoPath,
    String? ghostImagePath,
  }) {
    return SavedAngle(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      photoPath: photoPath ?? this.photoPath,
      ghostImagePath: ghostImagePath ?? this.ghostImagePath,
      poseId: poseId,
      gridType: gridType,
      isGridVisible: isGridVisible,
      gridOpacity: gridOpacity,
      ghostOpacity: ghostOpacity,
      ghostTransform: ghostTransform,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'photoPath': photoPath,
    'ghostImagePath': ghostImagePath,
    'poseId': poseId,
    'gridType': gridType,
    'isGridVisible': isGridVisible,
    'gridOpacity': gridOpacity,
    'ghostOpacity': ghostOpacity,
    'ghostTransform': ghostTransform.toMap(),
    'isFavorite': isFavorite,
  };

  factory SavedAngle.fromMap(Map<dynamic, dynamic> map) {
    return SavedAngle(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Góc chụp',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      photoPath: map['photoPath'] as String? ?? '',
      ghostImagePath: map['ghostImagePath'] as String?,
      poseId: map['poseId'] as String?,
      gridType: map['gridType'] as String? ?? 'thirds',
      isGridVisible: map['isGridVisible'] as bool? ?? true,
      gridOpacity: (map['gridOpacity'] as num?)?.toDouble() ?? 0.72,
      ghostOpacity: (map['ghostOpacity'] as num?)?.toDouble() ?? 0.4,
      ghostTransform: GhostTransform.fromMap(
        map['ghostTransform'] as Map<dynamic, dynamic>?,
      ),
      isFavorite: map['isFavorite'] as bool? ?? false,
    );
  }
}
