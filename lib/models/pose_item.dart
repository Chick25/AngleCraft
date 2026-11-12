import 'dart:ui';

enum PoseCategory { individualMale, individualFemale, couple, group, travel }

enum PoseStyle {
  standing,
  handOnHip,
  sitting,
  couple,
  family,
  group,
  walking,
  travel,
}

extension PoseCategoryLabel on PoseCategory {
  String get label => switch (this) {
    PoseCategory.individualMale => 'Cá nhân · Nam',
    PoseCategory.individualFemale => 'Cá nhân · Nữ',
    PoseCategory.couple => 'Chụp đôi',
    PoseCategory.group => 'Nhóm / Gia đình',
    PoseCategory.travel => 'Du lịch / Dạo phố',
  };
}

class PoseItem {
  final String id;
  final String title;
  final String description;
  final PoseCategory category;
  final PoseStyle style;
  final Map<String, Offset>? customLandmarks;
  final bool landmarksAreViewerRelative;

  const PoseItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.style,
    this.customLandmarks,
    this.landmarksAreViewerRelative = false,
  });

  bool get isCustom => customLandmarks != null;

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category.name,
    'style': style.name,
    'landmarksAreViewerRelative': landmarksAreViewerRelative,
    'customLandmarks': customLandmarks?.map(
      (name, point) => MapEntry(name, [point.dx, point.dy]),
    ),
  };

  factory PoseItem.fromMap(Map<dynamic, dynamic> map) {
    final id = map['id'] as String;
    final rawLandmarks = map['customLandmarks'] as Map<dynamic, dynamic>?;
    final landmarks = rawLandmarks?.map((name, rawPoint) {
      final point = rawPoint as List<dynamic>;
      return MapEntry(
        name as String,
        Offset((point[0] as num).toDouble(), (point[1] as num).toDouble()),
      );
    });

    return PoseItem(
      id: id,
      title: map['title'] as String,
      description: map['description'] as String,
      category: PoseCategory.values.byName(map['category'] as String),
      style: PoseStyle.values.byName(map['style'] as String),
      customLandmarks: landmarks,
      landmarksAreViewerRelative:
          map['landmarksAreViewerRelative'] as bool? ??
          id.startsWith('custom-'),
    );
  }
}
