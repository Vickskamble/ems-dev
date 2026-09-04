import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../../core/config/tariff_presets.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/industry_repository.dart';
import '../../domain/entities/industry_profile_entity.dart';
import 'main_navigation_hub.dart';

class IndustryProfilePage extends StatefulWidget {
  /// When provided, the page calls this after a successful save instead of
  /// navigating itself (used by the [IndustryGate] hard gate).
  final VoidCallback? onSaved;

  /// When true, loads an existing profile into the form (edit mode) and pops
  /// the route on save instead of navigating to the main hub.
  final bool isEditMode;

  const IndustryProfilePage({super.key, this.onSaved, this.isEditMode = false});

  @override
  State<IndustryProfilePage> createState() => _IndustryProfilePageState();
}

class _IndustryProfilePageState extends State<IndustryProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _industryNameCtrl = TextEditingController();
  final _consumerNumberCtrl = TextEditingController();
  final _contractDemandCtrl = TextEditingController();

  final _repo = IndustryRepository();
  bool _saving = false;

  String _tariffCategory = 'ht_industrial';
  String _tariffVersion = 'fy2627';
  String _voltageLevel = '11kV';
  String _serviceType = 'HT';
  String _energySources = 'none';
  String _mdMode = 'single';

  @override
  void initState() {
    super.initState();
    _tariffVersion = 'fy2627';
    if (widget.isEditMode) _loadExisting();
  }

  Future<void> _loadExisting() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final profile = await _repo.getProfile(userId);
      if (profile == null || !mounted) return;
      setState(() {
        _industryNameCtrl.text = profile.industryName;
        _consumerNumberCtrl.text = profile.consumerNumber ?? '';
        _contractDemandCtrl.text =
            profile.contractDemandKva.toStringAsFixed(0);
        _tariffCategory = profile.tariffCategory;
        _tariffVersion = profile.tariffVersion;
        _voltageLevel = profile.voltageLevel;
        _serviceType = profile.serviceType;
        _energySources = profile.energySources;
        _mdMode = profile.mdMode;
      });
    } catch (_) {
      // Keep defaults — the user can fill and save.
    }
  }

  @override
  void dispose() {
    _industryNameCtrl.dispose();
    _consumerNumberCtrl.dispose();
    _contractDemandCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be signed in to save your profile.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final contractDemand = double.tryParse(_contractDemandCtrl.text.trim()) ?? 0;
    if (contractDemand <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid contract demand (kVA).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final profile = IndustryProfileEntity(
        id: '',
        userId: userId,
        industryName: _industryNameCtrl.text.trim(),
        tariffCategory: _tariffCategory,
        tariffVersion: _tariffVersion,
        voltageLevel: _voltageLevel,
        contractDemandKva: contractDemand,
        energySources: _energySources,
        mdMode: _mdMode,
        consumerNumber:
            _consumerNumberCtrl.text.trim().isEmpty
                ? null
                : _consumerNumberCtrl.text.trim(),
        serviceType: _serviceType,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _repo.saveProfile(profile);

      // Apply to app config (energy sources, MD mode, tariff preset).
      AppConfig.applyIndustryProfile(
        energySources: _energySources,
        mdMode: _mdMode,
        companyName: _industryNameCtrl.text.trim(),
        tariffCategory: _tariffCategory,
        tariffVersion: _tariffVersion,
        contractDemandKva: contractDemand,
      );

      if (mounted) {
        final onSaved = widget.onSaved;
        if (onSaved != null) {
          onSaved();
        } else if (widget.isEditMode) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainNavigationHub()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      appBar: AppBar(title: const Text('Industry Profile')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 20 : 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.factory_rounded,
                        size: 56, color: AppColors.primary),
                    const SizedBox(height: 12),
                    Text(
                      'Complete your industry profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This is required to set up your billing and energy '
                      'sources. You can update it later from settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.dim(context),
                      ),
                    ),
                    const SizedBox(height: 28),

                    TextFormField(
                      controller: _industryNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Industry / business name *',
                        hintText: 'e.g. ABC Textiles Pvt. Ltd.',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Industry name is required'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    _buildDropdown<String>(
                      label: 'Tariff category *',
                      icon: Icons.category_outlined,
                      value: _tariffCategory,
                      items: TariffCategory.values
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.label),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _tariffCategory = v!),
                    ),
                    const SizedBox(height: 16),

                    _buildDropdown<String>(
                      label: 'Tariff version *',
                      icon: Icons.calendar_month_outlined,
                      value: _tariffVersion,
                      items: TariffVersion.values
                          .map((v) => DropdownMenuItem(
                                value: v.id,
                                child: Text(v.label),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _tariffVersion = v!),
                    ),
                    const SizedBox(height: 16),

                    _buildDropdown<String>(
                      label: 'Voltage level *',
                      icon: Icons.electrical_services_outlined,
                      value: _voltageLevel,
                      items: const [
                        DropdownMenuItem(value: '11kV', child: Text('11 kV')),
                        DropdownMenuItem(value: '33kV', child: Text('33 kV')),
                        DropdownMenuItem(value: '132kV', child: Text('132 kV')),
                        DropdownMenuItem(value: 'LT', child: Text('LT (Low Tension)')),
                      ],
                      onChanged: (v) => setState(() => _voltageLevel = v!),
                    ),
                    const SizedBox(height: 16),

                    _buildDropdown<String>(
                      label: 'Service type',
                      icon: Icons.memory_outlined,
                      value: _serviceType,
                      items: const [
                        DropdownMenuItem(value: 'HT', child: Text('HT')),
                        DropdownMenuItem(value: 'LT', child: Text('LT')),
                      ],
                      onChanged: (v) => setState(() => _serviceType = v!),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _contractDemandCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Contract demand (kVA) *',
                        hintText: 'e.g. 100',
                        prefixIcon: Icon(Icons.speed_outlined),
                        suffixText: 'kVA',
                      ),
                      validator: (v) {
                        final val = double.tryParse(v?.trim() ?? '');
                        if (val == null || val <= 0) {
                          return 'Enter a valid contract demand';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _consumerNumberCtrl,
                      decoration: const InputDecoration(
                        labelText: 'MSEDCL consumer number (optional)',
                        hintText: 'e.g. 1002...',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Energy sources selection
                    Text(
                      'Energy sources',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildChoiceChips(
                      options: const [
                        ('none', 'None', Icons.power_settings_new_outlined),
                        ('solar', 'Solar', Icons.solar_power_outlined),
                        ('turbine', 'Turbine', Icons.air),
                        (
                          'solar+turbine',
                          'Solar + Turbine',
                          Icons.solar_power_outlined,
                        ),
                      ],
                      selected: _energySources,
                      onChanged: (v) => setState(() => _energySources = v),
                    ),
                    const SizedBox(height: 24),

                    // MD mode selection
                    Text(
                      'Maximum Demand (MD) mode',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Single records one MD per month. Multi records four '
                      'separate MDs (T1-T4) for time-of-day billing.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.dim(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildChoiceChips(
                      options: const [
                        (
                          'single',
                          'Single MD',
                          Icons.looks_one_outlined,
                        ),
                        ('multi', 'Multi MD (T1-T4)', Icons.bar_chart_outlined),
                      ],
                      selected: _mdMode,
                      onChanged: (v) => setState(() => _mdMode = v),
                    ),
                    const SizedBox(height: 32),

                    AppButtonLoading(
                      label: 'Save & Continue',
                      icon: Icons.check_rounded,
                      expanded: true,
                      loading: _saving,
                      onPressed: _saving ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildChoiceChips({
    required List<(String, String, IconData)> options,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options
          .map((o) => ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(o.$3, size: 18),
                    const SizedBox(width: 6),
                    Text(o.$2),
                  ],
                ),
                selected: selected == o.$1,
                onSelected: (_) => onChanged(o.$1),
              ))
          .toList(),
    );
  }
}

/// Small private helper for a labelled, loading-capable submit button so the
/// page doesn't depend on extra widget imports for the saving state.
class AppButtonLoading extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final bool expanded;
  final VoidCallback? onPressed;

  const AppButtonLoading({
    super.key,
    required this.label,
    this.icon,
    this.loading = false,
    this.expanded = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        minimumSize: expanded
            ? const Size(double.infinity, 48)
            : const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
          : (icon != null ? Icon(icon, size: 18) : const SizedBox.shrink()),
      label: Text(loading ? 'Saving...' : label),
    );
  }
}