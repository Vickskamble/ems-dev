import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/notification_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_input.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/app_states.dart';
import '../../data/models/meter_model.dart';
import '../../data/repositories/energy_repository.dart';
import '../../data/repositories/meter_repository.dart';
import '../bloc/energy_bloc.dart';
import '../bloc/energy_event.dart';
import '../bloc/energy_state.dart';

class ReadingEntryPage extends StatefulWidget {
  const ReadingEntryPage({super.key});

  @override
  State<ReadingEntryPage> createState() => ReadingEntryPageState();
}

class ReadingEntryPageState extends State<ReadingEntryPage> {
  final _formKey = GlobalKey<FormState>();

  List<MeterModel> _meters = [];
  bool _metersLoading = true;
  bool _metersError = false;
  bool _fetchingPrevious = false;
  bool _lastSubmitWasManual = false;

  String _selectedMeter = '';
  DateTime _loggedAt = DateTime.now();
  final _currentKwhCtrl = TextEditingController();
  final _currentKvahCtrl = TextEditingController();
  final _rkvarhLagCtrl = TextEditingController();
  final _rkvarhLeadCtrl = TextEditingController();
  final _mdRecordedCtrl = TextEditingController();
  final _mdT1Ctrl = TextEditingController();
  final _mdT2Ctrl = TextEditingController();
  final _mdT3Ctrl = TextEditingController();
  final _mdT4Ctrl = TextEditingController();
  final _exportKwhCtrl = TextEditingController();
  final _exportKvahCtrl = TextEditingController();
  final _generationKwhCtrl = TextEditingController();
  final _turbineKwhCtrl = TextEditingController();
  final _turbineExportKwhCtrl = TextEditingController();

  /// Previous cumulative readings fetched from the DB for the selected
  /// date/meter — read-only, never editable by the client.
  double _prevCumulativeKwh = 0;
  double _prevCumulativeKvah = 0;
  bool _prevFetchFailed = false;

  /// True when the user has typed values or changed the date — used by the
  /// navigation hub to warn before switching away and discarding the form.
  bool get isDirty =>
      _currentKwhCtrl.text.isNotEmpty ||
      _currentKvahCtrl.text.isNotEmpty ||
      _rkvarhLagCtrl.text.isNotEmpty ||
      _rkvarhLeadCtrl.text.isNotEmpty ||
      _mdRecordedCtrl.text.isNotEmpty ||
      _mdT1Ctrl.text.isNotEmpty ||
      _mdT2Ctrl.text.isNotEmpty ||
      _mdT3Ctrl.text.isNotEmpty ||
      _mdT4Ctrl.text.isNotEmpty ||
      _exportKwhCtrl.text.isNotEmpty ||
      _exportKvahCtrl.text.isNotEmpty ||
      _generationKwhCtrl.text.isNotEmpty ||
      _turbineKwhCtrl.text.isNotEmpty ||
      _turbineExportKwhCtrl.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadMeters();
    context.read<MeterRepository>().addListener(_loadMeters);
    // Live consumption (difference) preview as the user types.
    _currentKwhCtrl.addListener(_onValuesChanged);
    _currentKvahCtrl.addListener(_onValuesChanged);
    _mdT1Ctrl.addListener(_onValuesChanged);
    _mdT2Ctrl.addListener(_onValuesChanged);
    _mdT3Ctrl.addListener(_onValuesChanged);
    _mdT4Ctrl.addListener(_onValuesChanged);
  }

  void _onValuesChanged() {
    if (mounted) setState(() {});
  }

  double? get _diffKwh {
    final cur = AppInputFormatters.parseNumber(_currentKwhCtrl.text.trim());
    if (cur == null) return null;
    return cur - _prevCumulativeKwh;
  }

  double? get _diffKvah {
    final cur = AppInputFormatters.parseNumber(_currentKvahCtrl.text.trim());
    if (cur == null) return null;
    return cur - _prevCumulativeKvah;
  }

  /// Max of the T1-T4 MD values (multi-MD feature) — NULL when empty.
  double? get _multiMdMax {
    final values = [_mdT1Ctrl, _mdT2Ctrl, _mdT3Ctrl, _mdT4Ctrl]
        .map((c) => AppInputFormatters.parseNumber(c.text.trim()))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a > b ? a : b);
  }

  /// Parsed T1-T4 values, defaulting to 0 for blanks (multi-MD feature).
  List<double> get _multiMdValues => [
    _mdT1Ctrl,
    _mdT2Ctrl,
    _mdT3Ctrl,
    _mdT4Ctrl,
  ].map((c) => AppInputFormatters.parseNumber(c.text.trim()) ?? 0).toList();

  @override
  void dispose() {
    context.read<MeterRepository>().removeListener(_loadMeters);
    _currentKwhCtrl.dispose();
    _currentKvahCtrl.dispose();
    _rkvarhLagCtrl.dispose();
    _rkvarhLeadCtrl.dispose();
    _mdRecordedCtrl.dispose();
    _mdT1Ctrl.dispose();
    _mdT2Ctrl.dispose();
    _mdT3Ctrl.dispose();
    _mdT4Ctrl.dispose();
    _exportKwhCtrl.dispose();
    _exportKvahCtrl.dispose();
    _generationKwhCtrl.dispose();
    _turbineKwhCtrl.dispose();
    _turbineExportKwhCtrl.dispose();
    super.dispose();
  }

  double _selectedMeterContractKva() {
    for (final m in _meters) {
      if (m.name == _selectedMeter) return m.contractDemandKw;
    }
    return AppConfig.contractDemandKva;
  }

  String? get _selectedMeterSite {
    for (final m in _meters) {
      if (m.name == _selectedMeter) return m.site;
    }
    return null;
  }

  Future<void> _loadMeters() async {
    setState(() {
      _metersLoading = true;
      _metersError = false;
    });
    try {
      final repo = context.read<MeterRepository>();
      final meters = await repo.getAllMeters();
      if (!mounted) return;
      setState(() {
        _meters = meters;
        _metersLoading = false;
        if (meters.isNotEmpty) {
          _selectedMeter = meters.first.name;
          _fetchPreviousReading(_selectedMeter);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _metersLoading = false;
        _metersError = true;
      });
    }
  }

  Future<void> _fetchPreviousReading(String meterName) async {
    if (meterName.isEmpty) return;
    setState(() => _fetchingPrevious = true);
    try {
      final energyRepo = context.read<EnergyRepository>();
      // Previous = the meter's ACTUAL cumulative reading recorded BEFORE the
      // selected date — computed from the DB (stored reading, or running sum
      // for legacy rows). Never trusted from the form.
      final prev = await energyRepo.getPreviousCumulative(meterName, _loggedAt);
      if (mounted) {
        setState(() {
          _prevCumulativeKwh = prev.kwh;
          _prevCumulativeKvah = prev.kvah;
          _prevFetchFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _prevFetchFailed = true);
    } finally {
      if (mounted) setState(() => _fetchingPrevious = false);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _loggedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_loggedAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _loggedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
    // Date changed → the correct "previous" reading changes too.
    _fetchPreviousReading(_selectedMeter);
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _currentKwhCtrl.clear();
    _currentKvahCtrl.clear();
    _rkvarhLagCtrl.clear();
    _rkvarhLeadCtrl.clear();
    _mdRecordedCtrl.clear();
    _mdT1Ctrl.clear();
    _mdT2Ctrl.clear();
    _mdT3Ctrl.clear();
    _mdT4Ctrl.clear();
    _exportKwhCtrl.clear();
    _exportKvahCtrl.clear();
    _generationKwhCtrl.clear();
    _turbineKwhCtrl.clear();
    _turbineExportKwhCtrl.clear();
    setState(() {
      _loggedAt = DateTime.now();
      _prevCumulativeKwh = 0;
      _prevCumulativeKvah = 0;
      if (_meters.isNotEmpty) {
        _selectedMeter = _meters.first.name;
        _fetchPreviousReading(_selectedMeter);
      }
    });
  }

  String? _requiredNumberValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return AppInputFormatters.parseNumber(v.trim()) == null
        ? 'Enter a valid number'
        : null;
  }

  String? _optionalNumberValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return AppInputFormatters.parseNumber(v.trim()) == null
        ? 'Enter a valid number'
        : null;
  }

  bool _isSolarMeter(String name) {
    final n = name.trim().toLowerCase();
    return n.contains('solar');
  }

  bool _isTurbineMeter(String name) {
    final n = name.trim().toLowerCase();
    return n.contains('turbine') || n.contains('wind');
  }

  /// Classifies the selected meter so the form shows type-specific fields.
  _MeterType get _selectedMeterType {
    if (_isSolarMeter(_selectedMeter)) return _MeterType.solar;
    if (_isTurbineMeter(_selectedMeter)) return _MeterType.turbine;
    return _MeterType.grid;
  }

  bool get _isGridSelected => _selectedMeterType == _MeterType.grid;

  Widget _buildMeterTypeBanner() {
    final t = _selectedMeterType;
    final dim = AppColors.dim(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: t.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: t.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: t.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(t.icon, size: 20, color: t.color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: t == _MeterType.grid ? dim : t.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(t.subtitle, style: TextStyle(fontSize: 11, color: dim)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: t.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Text(
              t == _MeterType.grid ? 'IMPORT' : 'RENEWABLE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: t.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasSolarMeter => _meters.any((m) => _isSolarMeter(m.name));
  bool get _hasTurbineMeter => _meters.any((m) => _isTurbineMeter(m.name));

  bool get _showSolarEntry =>
      AppConfig.hasSolar && _hasSolarMeter && _isSolarMeter(_selectedMeter);

  bool get _showTurbineEntry =>
      AppConfig.hasTurbine &&
      _hasTurbineMeter &&
      _isTurbineMeter(_selectedMeter);

  bool get _noPreviousReading =>
      _prevCumulativeKwh <= 0 && _prevCumulativeKvah <= 0;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final bloc = context.read<EnergyBloc>();

    // No actual earlier reading on record (first entry, renamed meter or
    // legacy rows without stored readings) → this entry is saved as the new
    // baseline with 0 units. Alert the user and only save after they confirm.
    if (_noPreviousReading) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          title: const Text('No previous reading available'),
          content: const Text(
            'No earlier cumulative reading was found for this meter. '
            'This entry will be saved with 0 units (it becomes the baseline). '
            'Consumption will be calculated only when the next reading is '
            'recorded.\n\nDo you still want to save it?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    _lastSubmitWasManual = true;
    final exportKwh = AppInputFormatters.parseNumber(
      _exportKwhCtrl.text.trim(),
    );
    final exportKvah = AppInputFormatters.parseNumber(
      _exportKvahCtrl.text.trim(),
    );
    final generationKwh = AppInputFormatters.parseNumber(
      _generationKwhCtrl.text.trim(),
    );
    final turbineKwh = AppInputFormatters.parseNumber(
      _turbineKwhCtrl.text.trim(),
    );
    final turbineExportKwh = AppInputFormatters.parseNumber(
      _turbineExportKwhCtrl.text.trim(),
    );
    final useMultiMd = AppConfig.useMultiMd;
    // Multi-MD: mdRecorded = max of T1-T4; mdValues keeps the breakdown.
    final mdValues = useMultiMd ? _multiMdValues : null;
    final mdRecorded = useMultiMd
        ? _multiMdMax ?? 0
        : AppInputFormatters.parseNumber(_mdRecordedCtrl.text.trim()) ?? 0;
    bloc.add(
      SubmitManualReadingForm(
        meterName: _selectedMeter,
        currentKwh:
            AppInputFormatters.parseNumber(_currentKwhCtrl.text.trim()) ?? 0,
        previousKwh: _prevCumulativeKwh,
        currentKvah:
            AppInputFormatters.parseNumber(_currentKvahCtrl.text.trim()) ?? 0,
        previousKvah: _prevCumulativeKvah,
        rkvarhLag:
            AppInputFormatters.parseNumber(_rkvarhLagCtrl.text.trim()) ?? 0,
        rkvarhLead:
            AppInputFormatters.parseNumber(_rkvarhLeadCtrl.text.trim()) ?? 0,
        mdRecorded: mdRecorded,
        powerFactor: null,
        loggedAt: _loggedAt,
        exportKwh: exportKwh,
        exportKvah: exportKvah,
        generationKwh: generationKwh,
        turbineKwh: turbineKwh,
        turbineExportKwh: turbineExportKwh,
        mdValues: mdValues,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<EnergyBloc, EnergyState>(
      listener: (context, state) {
        switch (state) {
          case EnergySuccess(:final currentPowerFactor, :final maxDemandPeak):
            // Ignore states triggered by auto-refresh / other pages —
            // success feedback belongs only to a manual form submit.
            if (!_lastSubmitWasManual) break;
            _lastSubmitWasManual = false;
            AppSnackbar.success(context, 'Reading saved successfully');
            _clearForm();
            if (currentPowerFactor < 0.95) {
              NotificationService.instance.showPfAlert(
                currentPowerFactor,
                meterName: _selectedMeter,
                site: _selectedMeterSite,
              );
            }
            final meterContract = _selectedMeterContractKva();
            if (maxDemandPeak >= meterContract * 0.95) {
              NotificationService.instance.showMdAlert(
                maxDemandPeak,
                meterContract,
                meterName: _selectedMeter,
                site: _selectedMeterSite,
              );
            }
          case EnergyValidationError _:
            _lastSubmitWasManual = false;
            AppSnackbar.warning(context, state.message);
          case EnergyOperationFailure _:
            _lastSubmitWasManual = false;
            AppSnackbar.error(context, state.message);
          default:
            break;
        }
      },
      child: BlocBuilder<EnergyBloc, EnergyState>(
        builder: (context, state) {
          final isLoading = state is EnergyLoading;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              AppSectionHeader(
                title: 'Manual Reading Entry',
                subtitle: 'Record energy meter readings',
              ),
              if (_metersLoading)
                const AppSkeletonCard()
              else if (_metersError)
                AppErrorState(
                  message: 'Could not load meters',
                  onRetry: _loadMeters,
                )
              else if (_meters.isEmpty)
                const AppEmptyState(
                  icon: Icons.speed_rounded,
                  title: 'No meters configured',
                  subtitle: 'Add one in Meter Management first',
                )
              else
                Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Enter the numbers exactly as shown on the '
                                'meter display. The app calculates consumption '
                                'automatically from the previous reading.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Meter Selection',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: ValueKey(_selectedMeter),
                              initialValue: _selectedMeter,
                              decoration: const InputDecoration(
                                labelText: 'Meter Name',
                                prefixIcon: Icon(Icons.speed_rounded, size: 20),
                              ),
                              items: _meters
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m.name,
                                      child: Text(m.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedMeter = v);
                                  _fetchPreviousReading(v);
                                }
                              },
                            ),
                            if (_fetchingPrevious)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Fetching previous reading...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.dim(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildMeterTypeBanner(),
                      const SizedBox(height: AppSpacing.md),
                      if (AppConfig.hasSolar && !_hasSolarMeter)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.solar_power_outlined,
                                size: 18,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Solar enabled in profile — add a SOLAR meter in '
                                  'Meter Management first to record solar/export '
                                  'readings.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (AppConfig.hasTurbine && !_hasTurbineMeter)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.air, size: 18, color: Colors.orange),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Turbine enabled in profile — add a TURBINE meter '
                                  'in Meter Management first to record turbine '
                                  'generation readings.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      AppCard(
                        child: Row(
                          children: [
                            Icon(
                              Icons.event,
                              size: 20,
                              color: AppColors.dim(context),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reading Date & Time',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.dim(context),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat(
                                      'dd/MM/yyyy, hh:mm a',
                                    ).format(_loggedAt),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _pickDateTime,
                              icon: const Icon(
                                Icons.edit_calendar_outlined,
                                size: 18,
                              ),
                              label: const Text('Change'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_isGridSelected) ...[
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.bolt_rounded,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Energy Readings',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              AppTextField(
                                controller: _currentKwhCtrl,
                                label: 'Current kWh Reading',
                                hint: 'Meter display value',
                                prefixIcon: Icons.bolt,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [AppInputFormatters.numeric],
                                validator: _requiredNumberValidator,
                              ),
                              const SizedBox(height: 12),
                              AppTextField(
                                controller: _currentKvahCtrl,
                                label: 'Current kVAh Reading',
                                hint: 'Meter display value',
                                prefixIcon: Icons.electrical_services,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [AppInputFormatters.numeric],
                                validator: _requiredNumberValidator,
                              ),
                              if (_noPreviousReading) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.orange.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        size: 20,
                                        color: Colors.orange,
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'No previous reading found — this entry '
                                          'will be saved with 0 units. Consumption '
                                          'will be calculated when the next reading '
                                          'is recorded.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (_diffKwh != null ||
                                  _diffKvah != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.06,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.compare_arrows_rounded,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Consumption (Current − Previous)',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${(_diffKwh ?? 0).toStringAsFixed(2)} kWh · '
                                            '${(_diffKvah ?? 0).toStringAsFixed(2)} kVAh',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  (_diffKwh ?? 0) < 0 ||
                                                      (_diffKvah ?? 0) < 0
                                                  ? AppColors.danger
                                                  : AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.history,
                                            size: 14,
                                            color: AppColors.dim(context),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _prevFetchFailed
                                                  ? 'Couldn\'t fetch previous reading — check your connection. Consumption shown here may be inaccurate.'
                                                  : 'Previous (auto, from DB): '
                                                        '${_prevCumulativeKwh.toStringAsFixed(2)} kWh · '
                                                        '${_prevCumulativeKvah.toStringAsFixed(2)} kVAh',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: _prevFetchFailed
                                                    ? AppColors.warningText
                                                    : AppColors.dim(context),
                                                fontWeight: _prevFetchFailed
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.speed_rounded,
                                    size: 18,
                                    color: AppColors.kpiPower,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Power Quality',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: AppTextField(
                                      controller: _rkvarhLagCtrl,
                                      label: 'rkVARh (Lag)',
                                      prefixIcon: Icons.warning_outlined,
                                      keyboardType:
                                          TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      inputFormatters: [
                                        AppInputFormatters.numeric,
                                      ],
                                      validator: _optionalNumberValidator,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: AppTextField(
                                      controller: _rkvarhLeadCtrl,
                                      label: 'rkVARh (Lead)',
                                      prefixIcon: Icons.check_circle_outline,
                                      keyboardType:
                                          TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      inputFormatters: [
                                        AppInputFormatters.numeric,
                                      ],
                                      validator: _optionalNumberValidator,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (AppConfig.useMultiMd) ...[
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'MD Recorded (kVA) — enter all 4 phases',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (_multiMdMax != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          'Max: ${_multiMdMax!.toStringAsFixed(1)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppTextField(
                                        controller: _mdT1Ctrl,
                                        label: 'MD T1 (kVA)',
                                        hint: 'Phase 1',
                                        prefixIcon: Icons.trending_up,
                                        keyboardType:
                                            TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        inputFormatters: [
                                          AppInputFormatters.numeric,
                                        ],
                                        validator: _optionalNumberValidator,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: AppTextField(
                                        controller: _mdT2Ctrl,
                                        label: 'MD T2 (kVA)',
                                        hint: 'Phase 2',
                                        prefixIcon: Icons.trending_up,
                                        keyboardType:
                                            TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        inputFormatters: [
                                          AppInputFormatters.numeric,
                                        ],
                                        validator: _optionalNumberValidator,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppTextField(
                                        controller: _mdT3Ctrl,
                                        label: 'MD T3 (kVA)',
                                        hint: 'Phase 3',
                                        prefixIcon: Icons.trending_up,
                                        keyboardType:
                                            TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        inputFormatters: [
                                          AppInputFormatters.numeric,
                                        ],
                                        validator: _optionalNumberValidator,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: AppTextField(
                                        controller: _mdT4Ctrl,
                                        label: 'MD T4 (kVA)',
                                        hint: 'Phase 4',
                                        prefixIcon: Icons.trending_up,
                                        keyboardType:
                                            TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        inputFormatters: [
                                          AppInputFormatters.numeric,
                                        ],
                                        validator: _optionalNumberValidator,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else
                                AppTextField(
                                  controller: _mdRecordedCtrl,
                                  label: 'MD Recorded (kVA) — optional',
                                  hint: 'Leave blank if not available',
                                  prefixIcon: Icons.trending_up,
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: [AppInputFormatters.numeric],
                                  validator: _optionalNumberValidator,
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xxl),

                      // ── Solar / Net Metering (only for solar sources) ──
                      if (_showSolarEntry) ...[
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.solar_power_outlined,
                                    size: 18,
                                    color: Color(0xFF059669),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Solar / Net Metering',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'OPTIONAL',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'For consumers with solar panels. Export = units fed '
                                'back to grid. Generation = total panel output.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.color,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.orange.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Note: Record solar/export readings only on your '
                                  'dedicated SOLAR meter. Do not enter generation '
                                  'while a general (import) meter is selected.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: AppTextField(
                                      controller: _exportKwhCtrl,
                                      label: 'Export kWh',
                                      hint: 'Grid export reading',
                                      prefixIcon: Icons.solar_power_outlined,
                                      keyboardType:
                                          TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      inputFormatters: [
                                        AppInputFormatters.numeric,
                                      ],
                                      validator: _optionalNumberValidator,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: AppTextField(
                                      controller: _exportKvahCtrl,
                                      label: 'Export kVAh',
                                      hint: 'Optional',
                                      prefixIcon: Icons.solar_power_outlined,
                                      keyboardType:
                                          TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      inputFormatters: [
                                        AppInputFormatters.numeric,
                                      ],
                                      validator: _optionalNumberValidator,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              AppTextField(
                                controller: _generationKwhCtrl,
                                label: 'Total Generation kWh',
                                hint: 'Total solar panel output',
                                prefixIcon: Icons.bolt,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [AppInputFormatters.numeric],
                                validator: _optionalNumberValidator,
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ── Turbine generation (only for turbine sources) ──
                      if (_showTurbineEntry) ...[
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.air,
                                    size: 18,
                                    color: Color(0xFF0EA5E9),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Turbine Generation',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF0EA5E9,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusMd,
                                      ),
                                    ),
                                    child: const Text(
                                      'OPTIONAL',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF0EA5E9),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'For consumers with wind/small-hydro turbines. '
                                'Generation subtracts from import for net billing.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.color,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.orange.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Note: Record turbine generation only on your '
                                  'dedicated TURBINE meter. Do not enter it while '
                                  'a general (import) meter is selected.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              AppTextField(
                                controller: _turbineKwhCtrl,
                                label: 'Turbine Generation kWh',
                                hint: 'Total turbine output',
                                prefixIcon: Icons.air,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [AppInputFormatters.numeric],
                                validator: _optionalNumberValidator,
                              ),
                              const SizedBox(height: 12),
                              AppTextField(
                                controller: _turbineExportKwhCtrl,
                                label: 'Turbine Export kWh',
                                hint: 'Units fed back to grid',
                                prefixIcon: Icons.sync,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [AppInputFormatters.numeric],
                                validator: _optionalNumberValidator,
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.xxl),

                      AppButton(
                        label: 'Save Reading',
                        onPressed: isLoading ? null : _submit,
                        icon: Icons.save_rounded,
                        expanded: true,
                        loading: isLoading,
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Classifies a meter's purpose so the reading form adapts its inputs.
enum _MeterType {
  grid(
    'Grid Meter',
    'Import & consumption readings',
    Icons.grid_on_rounded,
    AppColors.primary,
  ),
  solar(
    'Solar Meter',
    'Solar generation & export to grid',
    Icons.solar_power_outlined,
    Color(0xFF059669),
  ),
  turbine(
    'Turbine Meter',
    'Turbine generation & export to grid',
    Icons.air,
    Color(0xFF0EA5E9),
  );

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MeterType(this.label, this.subtitle, this.icon, this.color);
}
