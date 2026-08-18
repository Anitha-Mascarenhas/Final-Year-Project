class ChildProfile {
  final String name;
  final String parentNames;
  final String accountType;
  final String gender; // 'boy' or 'girl'
  final int ageYears;
  final int ageMonths;
  final String avatarUrl;
  final String status;
  final String statusDescription;

  ChildProfile({
    required this.name,
    required this.parentNames,
    required this.accountType,
    required this.gender,
    required this.ageYears,
    required this.ageMonths,
    required this.avatarUrl,
    required this.status,
    required this.statusDescription,
  });

  ChildProfile copyWith({
    String? name,
    String? parentNames,
    String? accountType,
    String? gender,
    int? ageYears,
    int? ageMonths,
    String? avatarUrl,
    String? status,
    String? statusDescription,
  }) {
    return ChildProfile(
      name: name ?? this.name,
      parentNames: parentNames ?? this.parentNames,
      accountType: accountType ?? this.accountType,
      gender: gender ?? this.gender,
      ageYears: ageYears ?? this.ageYears,
      ageMonths: ageMonths ?? this.ageMonths,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      statusDescription: statusDescription ?? this.statusDescription,
    );
  }
}
