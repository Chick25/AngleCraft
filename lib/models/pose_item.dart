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

  const PoseItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.style,
    this.customLandmarks,
  });

  bool get isCustom => customLandmarks != null;

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category.name,
    'style': style.name,
    'customLandmarks': customLandmarks?.map(
      (name, point) => MapEntry(name, [point.dx, point.dy]),
    ),
  };

  factory PoseItem.fromMap(Map<dynamic, dynamic> map) {
    final rawLandmarks = map['customLandmarks'] as Map<dynamic, dynamic>?;
    final landmarks = rawLandmarks?.map((name, rawPoint) {
      final point = rawPoint as List<dynamic>;
      return MapEntry(
        name as String,
        Offset((point[0] as num).toDouble(), (point[1] as num).toDouble()),
      );
    });

    return PoseItem(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      category: PoseCategory.values.byName(map['category'] as String),
      style: PoseStyle.values.byName(map['style'] as String),
      customLandmarks: landmarks,
    );
  }
}
