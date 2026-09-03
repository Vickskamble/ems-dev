class IndustryProfileEntity {
  final String id;
  final String userId;
  final String industryName;
  final String tariffCategory;
  final String tariffVersion;
  final String voltageLevel;
  final double contractDemandKva;
  final String energySources;
  final String mdMode;
  final String? consumerNumber;
  final String? division;
  final String? circle;
  final String serviceType;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IndustryProfileEntity({
    required this.id,
    required this.userId,
    required this.industryName,
    required this.tariffCategory,
    required this.tariffVersion,
    required this.voltageLevel,
    required this.contractDemandKva,
    required this.energySources,
    required this.mdMode,
    this.consumerNumber,
    this.division,
    this.circle,
    required this.serviceType,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasSolar => energySources == 'solar' || energySources == 'solar+turbine';
  bool get hasTurbine => energySources == 'turbine' || energySources == 'solar+turbine';
  bool get isMultiMd => mdMode == 'multi';

  IndustryProfileEntity copyWith({
    String? id,
    String? userId,
    String? industryName,
    String? tariffCategory,
    String? tariffVersion,
    String? voltageLevel,
    double? contractDemandKva,
    String? energySources,
    String? mdMode,
    String? consumerNumber,
    String? division,
    String? circle,
    String? serviceType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IndustryProfileEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      industryName: industryName ?? this.industryName,
      tariffCategory: tariffCategory ?? this.tariffCategory,
      tariffVersion: tariffVersion ?? this.tariffVersion,
      voltageLevel: voltageLevel ?? this.voltageLevel,
      contractDemandKva: contractDemandKva ?? this.contractDemandKva,
      energySources: energySources ?? this.energySources,
      mdMode: mdMode ?? this.mdMode,
      consumerNumber: consumerNumber ?? this.consumerNumber,
      division: division ?? this.division,
      circle: circle ?? this.circle,
      serviceType: serviceType ?? this.serviceType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndustryProfileEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'IndustryProfileEntity(id: $id, userId: $userId, name: $industryName, '
      'category: $tariffCategory, energySources: $energySources, mdMode: $mdMode)';
}