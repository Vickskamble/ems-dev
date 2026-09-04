import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_logger.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/energy_log_model.dart';
import '../../data/repositories/energy_repository.dart';
import '../../domain/entities/energy_log_entity.dart';
import '../bloc/energy_bloc.dart';
import '../bloc/energy_event.dart';

class ReadingHistoryPage extends StatefulWidget {
  const ReadingHistoryPage({super.key});

  @override
  State<ReadingHistoryPage> createState() => _ReadingHistoryPageState();
}

class _ReadingHistoryPageState extends State<ReadingHistoryPage> {
  List<EnergyLogEntity> _allLogs = [];
  String? _selectedMeter;
  int? _selectedYear;
  int? _selectedMonth;
  int? _selectedDay;
  int _visibleCount = 20;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  String? _loadError;

  Future<void> _loadLogs() async {
    try {
      final logs = await context.read<EnergyRepository>().getAllLogs();
      if (mounted) {
        final sorted = List<EnergyLogEntity>.from(logs)
          ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
        setState(() {
          _allLogs = sorted;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    }
  }

  List<int> get _availableYears {
    final years = <int>{DateTime.now().year};
    for (final l in _filteredByMeter) {
      years.add(l.loggedAt.year);
    }
    final list = years.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  List<EnergyLogEntity> get _filteredByMeter {
    if (_selectedMeter == null) return _allLogs;
    return _allLogs.where((l) => l.meterName == _selectedMeter).toList();
  }

  List<String> get _availableMeters {
    final meters = <String>{};
    for (final l in _allLogs) {
      meters.add(l.meterName);
    }
    return meters.toList()..sort();
  }

  List<EnergyLogEntity> get _filteredByYear {
    if (_selectedYear == null) return _filteredByMeter;
    return _filteredByMeter
        .where((l) => l.loggedAt.year == _selectedYear)
        .toList();
  }

  List<int> get _availableMonths {
    final months = <int>{};
    for (final l in _filteredByYear) {
      months.add(l.loggedAt.month);
    }
    return months.toList()..sort((a, b) => b.compareTo(a));
  }

  List<EnergyLogEntity> get _filteredByMonth {
    var logs = _filteredByYear;
    if (_selectedMonth != null) {
      logs = logs.where((l) => l.loggedAt.month == _selectedMonth).toList();
    }
    return logs;
  }

  List<int> get _availableDays {
    final days = <int>{};
    for (final l in _filteredByMonth) {
      days.add(l.loggedAt.day);
    }
    return days.toList()..sort((a, b) => b.compareTo(a));
  }

  List<EnergyLogEntity> get _filtered {
    var logs = _filteredByMonth;
    if (_selectedDay != null) {
      logs = logs.where((l) => l.loggedAt.day == _selectedDay).toList();
    }
    return logs;
  }

  String _fmtDate(DateTime dt) => DateFormat('dd MMM yyyy, HH:mm').format(dt);

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final visible = filtered.take(_visibleCount).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dim = isDark ? AppColors.textDarkSecondary : AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          _buildFilterRow(),
          const SizedBox(height: AppSpacing.lg),
          if (_loadError != null)
            AppCard(
              child: SizedBox(
                height: 140,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 34,
                        color: AppColors.danger,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load readings',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        errCheckText,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: dim),
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: _loadLogs,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_allLogs.isEmpty)
            AppCard(
              child: SizedBox(
                height: 180,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.history_rounded,
                          size: 28,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No readings found',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Readings you add will appear here',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: dim),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${filtered.length} reading${filtered.length == 1 ? '' : 's'}'
                    '${_selectedMeter != null || _selectedYear != null ? ' matched' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: dim,
                    ),
                  ),
                ),
                if (_selectedYear != null ||
                    _selectedMeter != null ||
                    _selectedMonth != null ||
                    _selectedDay != null)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _selectedMeter = null;
                      _selectedYear = null;
                      _selectedMonth = null;
                      _selectedDay = null;
                      _visibleCount = _pageSize;
                    }),
                    icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                    label: const Text('Clear filters'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final log in visible) _buildReadingCard(log),
            if (_visibleCount < filtered.length)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _visibleCount += _pageSize),
                    icon: const Icon(Icons.expand_more_rounded, size: 18),
                    label: Text(
                      'Show ${(filtered.length - _visibleCount).clamp(0, _pageSize)} more',
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String get errCheckText => 'Check your connection, then retry.';

  Widget _buildFilterRow() {
    final dim = AppColors.dim(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.filter_list_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: dim,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _dropdown<String>(
                label: 'Meter',
                value: _selectedMeter,
                items: _availableMeters,
                labelBuilder: (v) => v,
                onChanged: (v) => setState(() {
                  _selectedMeter = v;
                  _selectedYear = null;
                  _selectedMonth = null;
                  _selectedDay = null;
                  _visibleCount = _pageSize;
                }),
              ),
              _dropdown<int>(
                label: 'Year',
                value: _selectedYear,
                items: _availableYears,
                labelBuilder: (v) => '$v',
                onChanged: (v) => setState(() {
                  _selectedYear = v;
                  _selectedMonth = null;
                  _selectedDay = null;
                  _visibleCount = _pageSize;
                }),
              ),
              _dropdown<int>(
                label: 'Month',
                value: _selectedMonth,
                items: _availableMonths,
                labelBuilder: (v) =>
                    DateFormat('MMMM').format(DateTime(2024, v)),
                onChanged: (v) => setState(() {
                  _selectedMonth = v;
                  _selectedDay = null;
                  _visibleCount = _pageSize;
                }),
              ),
              _dropdown<int>(
                label: 'Day',
                value: _selectedDay,
                items: _availableDays,
                labelBuilder: (v) => '$v',
                onChanged: (v) => setState(() {
                  _selectedDay = v;
                  _visibleCount = _pageSize;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: [
          DropdownMenuItem<T>(
            value: null,
            child: Text('All', style: TextStyle(fontSize: 13)),
          ),
          for (final item in items)
            DropdownMenuItem<T>(
              value: item,
              child: Text(labelBuilder(item), style: TextStyle(fontSize: 13)),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildReadingCard(EnergyLogEntity log) {
    final mf = log.multiplyingFactor;
    final actualMd = log.mdRecorded * mf;
    final actualKwh = log.kwh * mf;
    final actualKvah = log.kvah * mf;
    final pf = log.kvah > 0 ? (log.kwh / log.kvah).clamp(0.0, 1.0) : 0.0;
    final dim = AppColors.dim(context);

    final issues = <_Issue>[];
    if (log.kwh > 0 && log.kvah > 0 && log.kwh > log.kvah) {
      issues.add(
        _Issue(
          'Invalid (kWh > kVAh)',
          AppColors.danger,
          AppColors.danger.withValues(alpha: 0.1),
        ),
      );
    }
    if (log.kwh > 0 && log.kvah > 0 && pf < 0.9) {
      issues.add(
        _Issue(
          'Low PF (${pf.toStringAsFixed(3)} \u2014 penalty risk)',
          AppColors.danger,
          AppColors.danger.withValues(alpha: 0.1),
        ),
      );
    } else if (log.kwh > 0 && log.kvah > 0 && pf < 0.95) {
      issues.add(
        _Issue(
          'PF Watch (${pf.toStringAsFixed(3)})',
          AppColors.warning,
          AppColors.warning.withValues(alpha: 0.06),
        ),
      );
    }
    if (log.kvah > 0 && log.kwh == 0 && log.powerFactor == 0) {
      issues.add(
        _Issue(
          'No PF data',
          AppColors.textSecondary,
          AppColors.surface2Light.withValues(alpha: 0.5),
        ),
      );
    }

    final hasRenewable =
        log.exportKwh != null ||
        log.generationKwh != null ||
        log.turbineKwh != null ||
        log.turbineExportKwh != null;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          onTap: () => _showEditDialog(log),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: hasRenewable ? AppColors.success : AppColors.primary,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(AppSpacing.radiusXl),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCardHeader(log, hasRenewable),
                        const SizedBox(height: AppSpacing.md),
                        _buildStatsGrid(
                          log,
                          actualKwh,
                          actualKvah,
                          actualMd,
                          pf,
                        ),
                        if (hasRenewable) ...[
                          const SizedBox(height: AppSpacing.md),
                          _buildRenewableRow(log),
                        ],
                        if (issues.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final issue in issues) _issueBadge(issue),
                            ],
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Icon(
                              Icons.touch_app_outlined,
                              size: 12,
                              color: dim,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tap to edit details',
                              style: TextStyle(fontSize: 11, color: dim),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => _confirmDelete(log),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.dangerText,
                              ),
                              tooltip: 'Delete reading',
                              visualDensity: VisualDensity.compact,
                              iconSize: 18,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(EnergyLogEntity log, bool hasRenewable) {
    final dim = AppColors.dim(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (hasRenewable ? AppColors.success : AppColors.primary)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Icon(
            hasRenewable ? Icons.eco_outlined : Icons.electric_bolt_rounded,
            size: 18,
            color: hasRenewable ? AppColors.success : AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _fmtDate(log.loggedAt),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                log.meterName,
                style: TextStyle(
                  fontSize: 11,
                  color: dim,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _typePill(log),
      ],
    );
  }

  Widget _typePill(EnergyLogEntity log) {
    final isSolar = log.generationKwh != null || log.exportKwh != null;
    final isTurbine = log.turbineKwh != null || log.turbineExportKwh != null;
    if (isSolar && isTurbine) {
      return _pill(
        'Solar + Turbine',
        AppColors.warningText,
        AppColors.warning.withValues(alpha: 0.08),
      );
    }
    if (isSolar) {
      return _pill(
        'Solar',
        AppColors.successText,
        AppColors.success.withValues(alpha: 0.08),
      );
    }
    if (isTurbine) {
      return _pill(
        'Turbine',
        const Color(0xFF0EA5E9),
        const Color(0xFF0EA5E9).withValues(alpha: 0.08),
      );
    }
    return _pill(
      'Grid',
      AppColors.primaryLight,
      AppColors.primary.withValues(alpha: 0.08),
    );
  }

  Widget _pill(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _issueBadge(_Issue issue) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: issue.bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            issue.color == AppColors.danger
                ? Icons.error_outline
                : issue.color == AppColors.warning
                ? Icons.warning_amber_rounded
                : Icons.info_outline,
            size: 13,
            color: AppColors.statusText(issue.color, isDark),
          ),
          const SizedBox(width: 4),
          Text(
            issue.text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.statusText(issue.color, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(
    EnergyLogEntity log,
    double actualKwh,
    double actualKvah,
    double actualMd,
    double pf,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stats = <({String label, String value, Color color})>[
      (
        label: 'Energy',
        value: '${actualKwh.toStringAsFixed(1)} kWh',
        color: AppColors.kpiEnergy,
      ),
      (
        label: 'Reactive',
        value: '${actualKvah.toStringAsFixed(1)} kVAh',
        color: AppColors.kpiPower,
      ),
      (
        label: 'Max Demand',
        value: '${actualMd.toStringAsFixed(1)} kVA',
        color: AppColors.kpiDemand,
      ),
      (
        label: 'Power Factor',
        value: pf.toStringAsFixed(3),
        color: pf >= 0.95
            ? AppColors.success
            : pf < 0.9
            ? AppColors.danger
            : AppColors.warning,
      ),
    ];
    if (log.mdValues != null && log.mdValues!.length >= 4) {
      stats.add((
        label: 'MD Slots (kVA)',
        value:
            'T1 ${log.mdValues![0].toStringAsFixed(0)} Â· '
            'T2 ${log.mdValues![1].toStringAsFixed(0)} Â· '
            'T3 ${log.mdValues![2].toStringAsFixed(0)} Â· '
            'T4 ${log.mdValues![3].toStringAsFixed(0)}',
        color: AppColors.textSecondary,
      ));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 460 ? 4 : 2;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final s in stats)
              SizedBox(
                width:
                    (constraints.maxWidth - (crossCount - 1) * AppSpacing.md) /
                    crossCount,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dim(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.statusText(s.color, isDark),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color:
                          (isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight)
                              .withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRenewableRow(EnergyLogEntity log) {
    final entries = <Widget>[];
    if (log.generationKwh != null || log.exportKwh != null) {
      entries.add(
        _renewableItem(
          Icons.solar_power_outlined,
          'Solar',
          'gen ${log.generationKwh?.toStringAsFixed(1) ?? 'â€”'} Â· '
              'exp ${log.exportKwh?.toStringAsFixed(1) ?? 'â€”'}',
          AppColors.success,
        ),
      );
    }
    if (log.turbineKwh != null || log.turbineExportKwh != null) {
      entries.add(
        _renewableItem(
          Icons.air,
          'Turbine',
          'gen ${log.turbineKwh?.toStringAsFixed(1) ?? 'â€”'} Â· '
              'exp ${log.turbineExportKwh?.toStringAsFixed(1) ?? 'â€”'}',
          const Color(0xFF0EA5E9),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surface2Dark
            : AppColors.surface2Light.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: entries,
      ),
    );
  }

  Widget _renewableItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$label Â· ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.statusText(color, isDark),
          ),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 11, color: AppColors.dim(context)),
        ),
      ],
    );
  }

  void _confirmDelete(EnergyLogEntity log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reading'),
        content: Text(
          'Delete ${log.meterName} reading from ${_fmtDate(log.loggedAt)}?\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<EnergyRepository>().deleteReading(log.id);
                if (mounted) {
                  context.read<EnergyBloc>().add(
                    const LoadInitialDashboardData(),
                  );
                  _loadLogs();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reading deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                AppLogger.e('Delete failed', e);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Delete failed: $e'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(EnergyLogEntity log) async {
    final kwhCtrl = TextEditingController(text: log.kwh.toStringAsFixed(2));
    final kvahCtrl = TextEditingController(text: log.kvah.toStringAsFixed(2));
    final rkvarhLagCtrl = TextEditingController(
      text: log.rkvarhLag.toStringAsFixed(2),
    );
    final rkvarhLeadCtrl = TextEditingController(
      text: log.rkvarhLead.toStringAsFixed(2),
    );
    final mdCtrl = TextEditingController(
      text: log.mdRecorded.toStringAsFixed(2),
    );
    final mdT1Ctrl = TextEditingController(
      text: log.mdValues != null && log.mdValues!.length >= 4
          ? log.mdValues![0].toStringAsFixed(2)
          : '',
    );
    final mdT2Ctrl = TextEditingController(
      text: log.mdValues != null && log.mdValues!.length >= 4
          ? log.mdValues![1].toStringAsFixed(2)
          : '',
    );
    final mdT3Ctrl = TextEditingController(
      text: log.mdValues != null && log.mdValues!.length >= 4
          ? log.mdValues![2].toStringAsFixed(2)
          : '',
    );
    final mdT4Ctrl = TextEditingController(
      text: log.mdValues != null && log.mdValues!.length >= 4
          ? log.mdValues![3].toStringAsFixed(2)
          : '',
    );
    final formKey = GlobalKey<FormState>();
    final exportKwhCtrl = TextEditingController(
      text: log.exportKwh == null ? '' : log.exportKwh!.toStringAsFixed(2),
    );
    final exportKvahCtrl = TextEditingController(
      text: log.exportKvah == null ? '' : log.exportKvah!.toStringAsFixed(2),
    );
    final generationKwhCtrl = TextEditingController(
      text: log.generationKwh == null
          ? ''
          : log.generationKwh!.toStringAsFixed(2),
    );
    final turbineKwhCtrl = TextEditingController(
      text: log.turbineKwh == null ? '' : log.turbineKwh!.toStringAsFixed(2),
    );
    final turbineExportKwhCtrl = TextEditingController(
      text: log.turbineExportKwh == null
          ? ''
          : log.turbineExportKwh!.toStringAsFixed(2),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          var date = log.loggedAt;
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.sm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                          ),
                          child: const Icon(
                            Icons.edit_note_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Edit Reading',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${log.meterName} Â· ${DateFormat('dd MMM yyyy').format(log.loggedAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.dim(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextFormField(
                                controller: kwhCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Consumed kWh',
                                  prefixIcon: Icon(Icons.bolt_outlined),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  final val = double.tryParse(v ?? '');
                                  if (val == null || val <= 0) {
                                    return 'Enter a positive value';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: kvahCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Consumed kVAh',
                                  prefixIcon: Icon(Icons.speed_outlined),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  final val = double.tryParse(v ?? '');
                                  if (val == null || val <= 0) {
                                    return 'Enter a positive value';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              if (AppConfig.useMultiMd &&
                                  log.mdValues != null) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: mdT1Ctrl,
                                        decoration: const InputDecoration(
                                          labelText: 'MD T1 (kVA)',
                                          prefixIcon: Icon(Icons.trending_up),
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return null;
                                          }
                                          return double.tryParse(v.trim()) ==
                                                  null
                                              ? 'Enter a valid number'
                                              : null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: mdT2Ctrl,
                                        decoration: const InputDecoration(
                                          labelText: 'MD T2 (kVA)',
                                          prefixIcon: Icon(Icons.trending_up),
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return null;
                                          }
                                          return double.tryParse(v.trim()) ==
                                                  null
                                              ? 'Enter a valid number'
                                              : null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: mdT3Ctrl,
                                        decoration: const InputDecoration(
                                          labelText: 'MD T3 (kVA)',
                                          prefixIcon: Icon(Icons.trending_up),
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return null;
                                          }
                                          return double.tryParse(v.trim()) ==
                                                  null
                                              ? 'Enter a valid number'
                                              : null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: mdT4Ctrl,
                                        decoration: const InputDecoration(
                                          labelText: 'MD T4 (kVA)',
                                          prefixIcon: Icon(Icons.trending_up),
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return null;
                                          }
                                          return double.tryParse(v.trim()) ==
                                                  null
                                              ? 'Enter a valid number'
                                              : null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ] else
                                TextFormField(
                                  controller: mdCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'MD Recorded (kVA)',
                                    prefixIcon: Icon(Icons.trending_up),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    final val = double.tryParse(v ?? '');
                                    if (val == null || val <= 0) {
                                      return 'Enter a positive value';
                                    }
                                    return null;
                                  },
                                ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: rkvarhLagCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'rkVARh (Lag)',
                                        prefixIcon: Icon(
                                          Icons.warning_outlined,
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return null;
                                        }
                                        return double.tryParse(v.trim()) == null
                                            ? 'Enter a valid number'
                                            : null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: rkvarhLeadCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'rkVARh (Lead)',
                                        prefixIcon: Icon(
                                          Icons.check_circle_outline,
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return null;
                                        }
                                        return double.tryParse(v.trim()) == null
                                            ? 'Enter a valid number'
                                            : null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (AppConfig.hasSolar &&
                                  (log.meterName.trim().toLowerCase().contains(
                                        'solar',
                                      ) ||
                                      log.exportKwh != null ||
                                      log.generationKwh != null)) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: exportKwhCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Export kWh',
                                          prefixIcon: Icon(
                                            Icons.solar_power_outlined,
                                          ),
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return null;
                                          }
                                          return double.tryParse(v.trim()) ==
                                                  null
                                              ? 'Enter a valid number'
                                              : null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: exportKvahCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Export kVAh',
                                          prefixIcon: Icon(
                                            Icons.solar_power_outlined,
                                          ),
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return null;
                                          }
                                          return double.tryParse(v.trim()) ==
                                                  null
                                              ? 'Enter a valid number'
                                              : null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: generationKwhCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Solar Generation kWh',
                                    prefixIcon: Icon(Icons.bolt_outlined),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return null;
                                    }
                                    return double.tryParse(v.trim()) == null
                                        ? 'Enter a valid number'
                                        : null;
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (AppConfig.hasTurbine &&
                                  (log.meterName.trim().toLowerCase().contains(
                                        'turbine',
                                      ) ||
                                      log.meterName
                                          .trim()
                                          .toLowerCase()
                                          .contains('wind') ||
                                      log.turbineKwh != null ||
                                      log.turbineExportKwh != null)) ...[
                                TextFormField(
                                  controller: turbineKwhCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Turbine Generation kWh',
                                    prefixIcon: Icon(Icons.air),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return null;
                                    }
                                    return double.tryParse(v.trim()) == null
                                        ? 'Enter a valid number'
                                        : null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: turbineExportKwhCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Turbine Export kWh',
                                    prefixIcon: Icon(Icons.sync),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return null;
                                    }
                                    return double.tryParse(v.trim()) == null
                                        ? 'Enter a valid number'
                                        : null;
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.event_outlined,
                                  size: 20,
                                ),
                                title: Text(
                                  DateFormat('dd MMM yyyy, HH:mm').format(date),
                                  style: const TextStyle(fontSize: 13),
                                ),
                                trailing: const Icon(
                                  Icons.edit_calendar_outlined,
                                  size: 18,
                                ),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: dialogCtx,
                                    initialDate: date,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked == null) return;
                                  if (!dialogCtx.mounted) return;
                                  final time = await showTimePicker(
                                    context: dialogCtx,
                                    initialTime: TimeOfDay.fromDateTime(date),
                                  );
                                  if (time == null || !dialogCtx.mounted) {
                                    return;
                                  }
                                  setDialogState(() {
                                    date = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                      time.hour,
                                      time.minute,
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final isMultiMd =
                                AppConfig.useMultiMd && log.mdValues != null;
                            List<double>? mdValues;
                            double mdRecorded;
                            if (isMultiMd) {
                              mdValues = [
                                double.tryParse(mdT1Ctrl.text.trim()) ?? 0,
                                double.tryParse(mdT2Ctrl.text.trim()) ?? 0,
                                double.tryParse(mdT3Ctrl.text.trim()) ?? 0,
                                double.tryParse(mdT4Ctrl.text.trim()) ?? 0,
                              ];
                              mdRecorded = mdValues.reduce(
                                (a, b) => a > b ? a : b,
                              );
                            } else {
                              mdRecorded = double.parse(mdCtrl.text.trim());
                            }
                            final showSolarEdit =
                                AppConfig.hasSolar &&
                                (log.meterName.trim().toLowerCase().contains(
                                      'solar',
                                    ) ||
                                    log.exportKwh != null ||
                                    log.generationKwh != null);
                            final showTurbineEdit =
                                AppConfig.hasTurbine &&
                                (log.meterName.trim().toLowerCase().contains(
                                      'turbine',
                                    ) ||
                                    log.meterName.trim().toLowerCase().contains(
                                      'wind',
                                    ) ||
                                    log.turbineKwh != null ||
                                    log.turbineExportKwh != null);
                            final updatedModel = EnergyLogModel.create(
                              id: log.id,
                              meterName: log.meterName,
                              kwh: double.parse(kwhCtrl.text.trim()),
                              kvah: double.parse(kvahCtrl.text.trim()),
                              currentKwh: log.currentKwh,
                              currentKvah: log.currentKvah,
                              rkvarhLag:
                                  double.tryParse(rkvarhLagCtrl.text.trim()) ??
                                  0,
                              rkvarhLead:
                                  double.tryParse(rkvarhLeadCtrl.text.trim()) ??
                                  0,
                              mdRecorded: mdRecorded,
                              loggedAt: date,
                              contractDemand: log.contractDemand,
                              userId: log.userId,
                              isSynced: log.isSynced,
                              multiplyingFactor: log.multiplyingFactor,
                              mdValues: mdValues ?? log.mdValues,
                              exportKwh: showSolarEdit
                                  ? double.tryParse(exportKwhCtrl.text.trim())
                                  : log.exportKwh,
                              exportKvah: showSolarEdit
                                  ? double.tryParse(exportKvahCtrl.text.trim())
                                  : log.exportKvah,
                              generationKwh: showSolarEdit
                                  ? double.tryParse(
                                      generationKwhCtrl.text.trim(),
                                    )
                                  : log.generationKwh,
                              turbineKwh: showTurbineEdit
                                  ? double.tryParse(turbineKwhCtrl.text.trim())
                                  : log.turbineKwh,
                              turbineExportKwh: showTurbineEdit
                                  ? double.tryParse(
                                      turbineExportKwhCtrl.text.trim(),
                                    )
                                  : log.turbineExportKwh,
                            );
                            Navigator.pop(dialogCtx);
                            try {
                              await context
                                  .read<EnergyRepository>()
                                  .updateReading(updatedModel);
                              if (mounted) {
                                context.read<EnergyBloc>().add(
                                  const LoadInitialDashboardData(),
                                );
                                _loadLogs();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Reading updated'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              AppLogger.e('Update failed', e);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Update failed: $e'),
                                    backgroundColor: Colors.red.shade700,
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Issue {
  final String text;
  final Color color;
  final Color bg;
  const _Issue(this.text, this.color, this.bg);
}
