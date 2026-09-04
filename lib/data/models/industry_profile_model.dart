import 'package:uuid/uuid.dart';
import '../../domain/entities/industry_profile_entity.dart';

class IndustryProfileModel {
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

  const IndustryProfileModel({
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

  factory IndustryProfileModel.fromMap(Map<String, Object?> map) {
    return IndustryProfileModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      industryName: map['industry_name'] as String,
      tariffCategory: map['tariff_category'] as String,
      tariffVersion: map['tariff_version'] as String,
      voltageLevel: map['voltage_level'] as String,
      contractDemandKva: (map['contract_demand_kva'] as num).toDouble(),
      energySources: map['energy_sources'] as String,
      mdMode: map['md_mode'] as String,
      consumerNumber: map['consumer_number'] as String?,
      division: map['division'] as String?,
      circle: map['circle'] as String?,
      serviceType: map['service_type'] as String? ?? 'HT',
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
    );
  }

  Map<String, Object?> toMap() => {
    // Empty/placeholder id: let the DB generate one (id uuid default gen_random_uuid()).
    // A stored id (edit mode) is preserved so upsert on 'user_id' keeps it.
    if (id.isNotEmpty) 'id': id,
    'user_id': userId,
    'industry_name': industryName,
    'tariff_category': tariffCategory,
    'tariff_version': tariffVersion,
    'voltage_level': voltageLevel,
    'contract_demand_kva': contractDemandKva,
    'energy_sources': energySources,
    'md_mode': mdMode,
    if (consumerNumber != null) 'consumer_number': consumerNumber,
    if (division != null) 'division': division,
    if (circle != null) 'circle': circle,
    'service_type': serviceType,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory IndustryProfileModel.create({
    String? id,
    required String userId,
    required String industryName,
    required String tariffCategory,
    required String tariffVersion,
    required String voltageLevel,
    required double contractDemandKva,
    required String energySources,
    required String mdMode,
    String? consumerNumber,
    String? division,
    String? circle,
    String serviceType = 'HT',
  }) {
    final now = DateTime.now();
    return IndustryProfileModel(
      id: id ?? const Uuid().v4(),
      userId: userId,
      industryName: industryName,
      tariffCategory: tariffCategory,
      tariffVersion: tariffVersion,
      voltageLevel: voltageLevel,
      contractDemandKva: contractDemandKva,
      energySources: energySources,
      mdMode: mdMode,
      consumerNumber: consumerNumber,
      division: division,
      circle: circle,
      serviceType: serviceType,
      createdAt: now,
      updatedAt: now,
    );
  }

  IndustryProfileModel copyWith({
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
    return IndustryProfileModel(
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

  IndustryProfileEntity toEntity() => IndustryProfileEntity(
    id: id,
    userId: userId,
    industryName: industryName,
    tariffCategory: tariffCategory,
    tariffVersion: tariffVersion,
    voltageLevel: voltageLevel,
    contractDemandKva: contractDemandKva,
    energySources: energySources,
    mdMode: mdMode,
    consumerNumber: consumerNumber,
    division: division,
    circle: circle,
    serviceType: serviceType,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  factory IndustryProfileModel.fromEntity(IndustryProfileEntity entity) => IndustryProfileModel(
    id: entity.id,
    userId: entity.userId,
    industryName: entity.industryName,
    tariffCategory: entity.tariffCategory,
    tariffVersion: entity.tariffVersion,
    voltageLevel: entity.voltageLevel,
    contractDemandKva: entity.contractDemandKva,
    energySources: entity.energySources,
    mdMode: entity.mdMode,
    consumerNumber: entity.consumerNumber,
    division: entity.division,
    circle: entity.circle,
    serviceType: entity.serviceType,
    createdAt: entity.createdAt,
    updatedAt: entity.updatedAt,
  );

  bool get hasSolar => energySources == 'solar' || energySources == 'solar+turbine';
  bool get hasTurbine => energySources == 'turbine' || energySources == 'solar+turbine';
  bool get isMultiMd => mdMode == 'multi';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndustryProfileModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'IndustryProfileModel(id: $id, userId: $userId, name: $industryName, '
      'category: $tariffCategory, energySources: $energySources, mdMode: $mdMode)';
}