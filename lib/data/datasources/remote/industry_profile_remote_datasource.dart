import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/industry_profile_model.dart';

class IndustryProfileRemoteDatasource {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _table = 'industry_profiles';

  Future<IndustryProfileModel?> getProfile(String userId) async {
    final res = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (res == null) return null;
    return IndustryProfileModel.fromMap(res);
  }

  Future<IndustryProfileModel> upsertProfile(IndustryProfileModel profile) async {
    final res = await _client
        .from(_table)
        .upsert(profile.toMap(), onConflict: 'user_id')
        .select()
        .single();
    return IndustryProfileModel.fromMap(res);
  }

  Future<void> deleteProfile(String userId) async {
    await _client.from(_table).delete().eq('user_id', userId);
  }
}