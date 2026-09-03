import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/industry_profile_entity.dart';
import '../datasources/remote/industry_profile_remote_datasource.dart';
import '../models/industry_profile_model.dart';

class IndustryRepository {
  final IndustryProfileRemoteDatasource _remote = IndustryProfileRemoteDatasource();

  Future<IndustryProfileEntity?> getProfile(String userId) async {
    final model = await _remote.getProfile(userId);
    return model?.toEntity();
  }

  Future<IndustryProfileEntity> saveProfile(IndustryProfileEntity profile) async {
    final model = IndustryProfileModel.fromEntity(profile);
    final saved = await _remote.upsertProfile(model);
    return saved.toEntity();
  }

  Future<void> deleteProfile(String userId) async {
    await _remote.deleteProfile(userId);
  }

  Stream<IndustryProfileEntity?> watchProfile(String userId) {
    final client = Supabase.instance.client;
    return client
        .from('industry_profiles')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((list) => list.isEmpty ? null : IndustryProfileModel.fromMap(list.first).toEntity());
  }
}