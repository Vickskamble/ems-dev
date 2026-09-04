import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../../data/repositories/industry_repository.dart';
import 'industry_profile_page.dart';
import 'main_navigation_hub.dart';

/// Hard gate shown after sign-in. Loads the user's industry profile; if it
/// doesn't exist yet the user is forced to complete it before any other UI.
/// While loading (or if the check fails) the hub is shown so billing still
/// works — the profile can be completed from Settings when reachable.
class IndustryGate extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  final bool isDark;

  const IndustryGate({super.key, this.onToggleTheme, this.isDark = false});

  @override
  State<IndustryGate> createState() => _IndustryGateState();
}

class _IndustryGateState extends State<IndustryGate> {
  final _repo = IndustryRepository();
  bool _loading = true;
  bool _hasProfile = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final profile = userId == null ? null : await _repo.getProfile(userId);
      if (profile != null) {
        AppConfig.applyIndustryProfile(
          energySources: profile.energySources,
          mdMode: profile.mdMode,
          companyName: profile.industryName,
          tariffCategory: profile.tariffCategory,
          tariffVersion: profile.tariffVersion,
          contractDemandKva: profile.contractDemandKva,
        );
        setState(() => _hasProfile = true);
      }
    } catch (_) {
      // Fall through — treat as missing profile so the user can complete it.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSaved() {
    setState(() => _hasProfile = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_hasProfile) {
      return IndustryProfilePage(
        onSaved: _onSaved,
      );
    }
    return MainNavigationHub(
      onToggleTheme: widget.onToggleTheme,
      isDark: widget.isDark,
    );
  }
}