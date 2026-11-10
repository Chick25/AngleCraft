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

  const PoseItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.style,
  });
}