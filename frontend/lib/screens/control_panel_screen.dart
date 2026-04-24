import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/system_models.dart';
import '../models/contracts.dart';
import '../state/simulation_state.dart';
import '../services/api_client.dart';

class ControlPanelScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigate;

  const ControlPanelScreen({super.key, this.onNavigate});

  @override
  State<ControlPanelScreen> createState() => _ControlPanelScreenState();
}

class _ControlPanelScreenState extends State<ControlPanelScreen>
    with TickerProviderStateMixin {
  late List<UniversalKnob> _knobs;
  bool _overrideActive = false;

  // Simulation parameters — linked to SimulationState
  int _simTicks = 4;
  int _agentCount = 5;

  // Presets for the 8 Universal Knobs
  final List<Map<String, dynamic>> _presets = [
    {
      'name': 'EQUILIBRIUM',
      'description': 'Balanced baseline state',
      'color': AppTheme.accentGreen,
      'values': <UniversalKnobType, double>{
        UniversalKnobType.disposableIncomeDelta: 0.0,
        UniversalKnobType.operationalExpenseIndex: 0.0,
        UniversalKnobType.capitalAccessPressure: 0.0,
        UniversalKnobType.systemicFriction: 0.0,
        UniversalKnobType.socialEquityWeight: 0.0,
        UniversalKnobType.systemicTrustBaseline: 0.0,
        UniversalKnobType.futureMobilityIndex: 0.0,
        UniversalKnobType.ecologicalResourcePressure: 0.0,
      },
    },
    {
      'name': 'ECONOMIC STRESS',
      'description': 'High financial pressure',
      'color': AppTheme.accentRed,
      'values': <UniversalKnobType, double>{
        UniversalKnobType.disposableIncomeDelta: -0.8,
        UniversalKnobType.operationalExpenseIndex: 0.7,
        UniversalKnobType.capitalAccessPressure: 0.6,
        UniversalKnobType.systemicFriction: 0.3,
        UniversalKnobType.socialEquityWeight: -0.4,
        UniversalKnobType.systemicTrustBaseline: -0.2,
        UniversalKnobType.futureMobilityIndex: -0.3,
        UniversalKnobType.ecologicalResourcePressure: 0.2,
      },
    },
    {
      'name': 'SOCIAL COHESION',
      'description': 'High trust and equity',
      'color': AppTheme.accentCyan,
      'values': <UniversalKnobType, double>{
        UniversalKnobType.disposableIncomeDelta: 0.3,
        UniversalKnobType.operationalExpenseIndex: -0.2,
        UniversalKnobType.capitalAccessPressure: -0.1,
        UniversalKnobType.systemicFriction: -0.6,
        UniversalKnobType.socialEquityWeight: 0.8,
        UniversalKnobType.systemicTrustBaseline: 0.7,
        UniversalKnobType.futureMobilityIndex: 0.6,
        UniversalKnobType.ecologicalResourcePressure: 0.1,
      },
    },
  ];

  @override
  void initState() {
    super.initState();
    _knobs = _initializeUniversalKnobs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync knobs with blueprint values when entering this screen
    _syncKnobsWithBlueprint();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Sync knob values with the current SimulationState knobOverrides
  void _syncKnobsWithBlueprint() {
    final simState = context.read<SimulationState>();
    final overrides = simState.knobOverrides;
    
    print('[CONTROL_PANEL] Syncing knobs with overrides: $overrides');
    
    setState(() {
      _knobs[0].value = overrides.disposableIncomeDelta ?? 0.0;
      _knobs[1].value = overrides.operationalExpenseIndex ?? 0.0;
      _knobs[2].value = overrides.capitalAccessPressure ?? 0.0;
      _knobs[3].value = overrides.systemicFriction ?? 0.0;
      _knobs[4].value = overrides.socialEquityWeight ?? 0.0;
      _knobs[5].value = overrides.systemicTrustBaseline ?? 0.0;
      _knobs[6].value = overrides.futureMobilityIndex ?? 0.0;
      _knobs[7].value = overrides.ecologicalPressure ?? 0.0;
      
      print('[CONTROL_PANEL] Knob values after sync: ${_knobs.map((k) => '${k.label}: ${k.value}').join(', ')}');
      
      // Don't auto-enable override mode - keep knobs read-only by default
      // _overrideActive remains false unless user clicks Advanced Mode
    });
  }

  List<UniversalKnob> _initializeUniversalKnobs() {
    return [
      UniversalKnob(
        type: UniversalKnobType.disposableIncomeDelta,
        label: 'Disposable Income',
        description: 'Direct cash flow changes for citizens',
        value: 0.0,
        accentColor: const Color(0xFF00BCD4),
      ),
      UniversalKnob(
        type: UniversalKnobType.operationalExpenseIndex,
        label: 'Operational Expenses',
        description: 'Cost of living, inflation, subsidy cuts',
        value: 0.0,
        accentColor: const Color(0xFF4CAF50),
      ),
      UniversalKnob(
        type: UniversalKnobType.capitalAccessPressure,
        label: 'Capital Access',
        description: 'Debt, borrowing stress, OPR changes',
        value: 0.0,
        accentColor: const Color(0xFFFF9800),
      ),
      UniversalKnob(
        type: UniversalKnobType.systemicFriction,
        label: 'Systemic Friction',
        description: 'Time poverty, administrative red tape',
        value: 0.0,
        accentColor: const Color(0xFFF44336),
      ),
      UniversalKnob(
        type: UniversalKnobType.socialEquityWeight,
        label: 'Social Equity',
        description: 'Perception of fairness, Gini impact',
        value: 0.0,
        accentColor: const Color(0xFF9C27B0),
      ),
      UniversalKnob(
        type: UniversalKnobType.systemicTrustBaseline,
        label: 'Systemic Trust',
        description: 'Social contract strength',
        value: 0.0,
        accentColor: const Color(0xFF2196F3),
      ),
      UniversalKnob(
        type: UniversalKnobType.futureMobilityIndex,
        label: 'Future Mobility',
        description: 'Upskilling, class mobility opportunities',
        value: 0.0,
        accentColor: const Color(0xFF009688),
      ),
      UniversalKnob(
        type: UniversalKnobType.ecologicalResourcePressure,
        label: 'Ecological Pressure',
        description: 'Sustainability metrics',
        value: 0.0,
        accentColor: const Color(0xFF795548),
      ),
    ];
  }

  void _applyPreset(Map<String, dynamic> preset) {
    final values = preset['values'] as Map<UniversalKnobType, double>;
    setState(() {
      for (int i = 0; i < _knobs.length; i++) {
        _knobs[i].value = values[_knobs[i].type] ?? 0.0;
      }
      _overrideActive = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final simState = context.watch<SimulationState>();
    final blueprint = simState.environmentBlueprint;
    
    print('[CONTROL_PANEL] Build called - Status: ${simState.status}');
    print('[CONTROL_PANEL] Blueprint: ${blueprint != null ? 'exists with ${blueprint.dynamicSublayers.length} sublayers' : 'null'}');
    print('[CONTROL_PANEL] KnobOverrides: ${simState.knobOverrides}');
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _buildTopBar(),
          // Sublayer Gallery - Full Width
          if (blueprint != null)
            _buildSublayerGallery(blueprint)
          else
            Container(
              padding: const EdgeInsets.all(20),
              child: const Text(
                'No AI blueprint available. Please validate a policy first.',
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 11,
                  color: AppTheme.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          Expanded(
            child: _buildMainContent(simState),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.accentAmber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.tune, color: AppTheme.accentAmber, size: 16),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('CONTROL PANEL',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              Text('Review AI Physics & Launch Simulation',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 9,
                      color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSublayerGallery(EnvironmentBlueprint blueprint) {
    print('[CONTROL_PANEL] Building sublayer gallery with ${blueprint.dynamicSublayers.length} sublayers');
    for (final sublayer in blueprint.dynamicSublayers) {
      print('[CONTROL_PANEL] Sublayer: ${sublayer.name} -> ${sublayer.parentKnob} (${sublayer.policyValue - sublayer.baselineValue})');
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.accentCyan.withValues(alpha: 0.05),
        border: const Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.layers, size: 12, color: AppTheme.accentCyan),
              const SizedBox(width: 6),
              const Text('AI ENVIRONMENT BLUEPRINT',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentCyan,
                      letterSpacing: 0.8)),
              const SizedBox(width: 6),
              const Text('(Auto-applied to knobs)',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 8,
                      color: AppTheme.textMuted,
                      fontStyle: FontStyle.italic)),
              const Spacer(),
              Text('${blueprint.dynamicSublayers.length} sublayers',
                  style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 8,
                      color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          blueprint.dynamicSublayers.isEmpty
              ? Container(
                  height: 70,
                  alignment: Alignment.center,
                  child: const Text(
                    'No sublayers generated by AI. Check policy validation.',
                    style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      color: AppTheme.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : SizedBox(
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: blueprint.dynamicSublayers.length,
                    itemBuilder: (context, index) {
                      final sublayer = blueprint.dynamicSublayers[index];
                      return _buildSublayerCard(sublayer);
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSublayerCard(BlueprintSublayer sublayer) {
    final impactColor = sublayer.impactType == 'income'
        ? AppTheme.accentGreen
        : sublayer.impactType == 'expense'
            ? AppTheme.accentRed
            : AppTheme.accentAmber;

    final delta = sublayer.policyValue - sublayer.baselineValue;
    final deltaStr = '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)}';

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: impactColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: impactColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(sublayer.name,
                    style: const TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(deltaStr,
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: impactColor)),
              Text(sublayer.unit,
                  style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 8,
                      color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(SimulationState simState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 8 Universal Knobs - Compact Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune, size: 14, color: AppTheme.accentAmber),
                  SizedBox(width: 8),
                  Text('8 UNIVERSAL KNOBS',
                      style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: 0.8)),
                  SizedBox(width: 8),
                  Text('(AI-configured)',
                      style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 9,
                          color: AppTheme.textMuted,
                          fontStyle: FontStyle.italic)),
                ],
              ),
              GestureDetector(
                onTap: () => setState(() => _overrideActive = !_overrideActive),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _overrideActive 
                        ? AppTheme.accentAmber.withValues(alpha: 0.1)
                        : AppTheme.border.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _overrideActive 
                          ? AppTheme.accentAmber.withValues(alpha: 0.5)
                          : AppTheme.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _overrideActive ? Icons.edit : Icons.lock,
                        size: 12,
                        color: _overrideActive ? AppTheme.accentAmber : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _overrideActive ? 'ADVANCED MODE' : 'ADVANCED',
                        style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 9,
                          color: _overrideActive ? AppTheme.accentAmber : AppTheme.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCompactKnobGrid(),
          const SizedBox(height: 24),
          
          // Simulation Parameters & Launch
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Simulation Parameters
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.settings, size: 12, color: AppTheme.accentCyan),
                          SizedBox(width: 6),
                          Text('SIMULATION PARAMETERS',
                              style: TextStyle(
                                  fontFamily: 'SpaceMono',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: 0.8)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSimSlider(
                        label: 'Ticks (Months)',
                        value: _simTicks.toDouble(),
                        min: 1,
                        max: 12,
                        divisions: 11,
                        color: AppTheme.accentCyan,
                        displayValue: '$_simTicks',
                        onChanged: (v) {
                          setState(() => _simTicks = v.round());
                          simState.simulationTicks = v.round();
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildSimSlider(
                        label: 'Agent Count',
                        value: _agentCount.toDouble(),
                        min: 1,
                        max: 50,
                        divisions: 49,
                        color: AppTheme.accentAmber,
                        displayValue: '$_agentCount',
                        onChanged: (v) {
                          setState(() => _agentCount = v.round());
                          simState.agentCount = v.round();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Right: Quick Presets (Compact)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.flash_on, size: 12, color: AppTheme.accentGreen),
                          SizedBox(width: 6),
                          Text('QUICK PRESETS',
                              style: TextStyle(
                                  fontFamily: 'SpaceMono',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: 0.8)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._presets.map((preset) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: GestureDetector(
                          onTap: () => _applyPreset(preset),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: (preset['color'] as Color).withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: (preset['color'] as Color).withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: preset['color'] as Color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    preset['name'] as String,
                                    style: TextStyle(
                                      fontFamily: 'SpaceMono',
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: preset['color'] as Color,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.arrow_forward, size: 10, color: AppTheme.textMuted),
                              ],
                            ),
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Launch Button - Full Width
          _buildLaunchButton(simState),
          
          if (simState.simulationError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.3)),
              ),
              child: Text(
                simState.simulationError!,
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 10,
                  color: AppTheme.accentRed,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactKnobGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 2.2, // Increased from 3.5 to fix overflow
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _knobs.length,
      itemBuilder: (context, i) {
        final knob = _knobs[i];
        return _buildCompactKnobCard(knob);
      },
    );
  }

  Widget _buildCompactKnobCard(UniversalKnob knob) {
    final isAdvancedMode = _overrideActive;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: knob.accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: knob.accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  knob.label,
                  style: const TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(knob.value * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 10,
                  color: knob.accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!isAdvancedMode)
                const Icon(Icons.lock, size: 10, color: AppTheme.textMuted),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: knob.accentColor,
              inactiveTrackColor: knob.accentColor.withValues(alpha: 0.2),
              thumbColor: knob.accentColor,
              overlayColor: knob.accentColor.withValues(alpha: 0.1),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              trackHeight: 3,
            ),
            child: Slider(
              value: knob.value,
              min: -1.0,
              max: 1.0,
              onChanged: isAdvancedMode ? (value) {
                setState(() => knob.value = value);
              } : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Color color,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                displayValue,
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.2),
            thumbColor: color,
            overlayColor: color.withOpacity(0.1),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            trackHeight: 2,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildLaunchButton(SimulationState simState) {
    final canLaunch = simState.status == SimulationStatus.readyToReview;
    final isSimulating = simState.status == SimulationStatus.simulating;
    
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: canLaunch ? () => _launchSimulation(simState) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: canLaunch
                ? LinearGradient(
                    colors: [
                      AppTheme.accentPurple,
                      AppTheme.accentPurple.withValues(alpha: 0.8),
                    ],
                  )
                : null,
            color: canLaunch ? null : AppTheme.border.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: canLaunch
                  ? AppTheme.accentPurple.withValues(alpha: 0.8)
                  : AppTheme.border,
              width: 2,
            ),
            boxShadow: canLaunch
                ? [
                    BoxShadow(
                      color: AppTheme.accentPurple.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: isSimulating
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'LAUNCHING ${simState.ticks.length}/$_simTicks',
                        style: const TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.rocket_launch,
                        size: 18,
                        color: canLaunch ? Colors.white : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        canLaunch
                            ? 'LAUNCH SIMULATION'
                            : simState.isPolicyApproved
                                ? 'READY TO LAUNCH'
                                : 'VALIDATE POLICY FIRST',
                        style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 12,
                          color: canLaunch ? Colors.white : AppTheme.textMuted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _launchSimulation(SimulationState simState) {
    // Start the simulation
    _startSimulation(simState);
    
    // Navigate to Dashboard (index 1)
    widget.onNavigate?.call(1);
  }

  void _startSimulation(SimulationState simState) {
    final apiClient = context.read<ApiClient>();

    // Build knob overrides from current knob state
    final overrides = KnobOverrides(
      disposableIncomeDelta: _knobs
          .firstWhere((k) => k.type == UniversalKnobType.disposableIncomeDelta)
          .value,
      operationalExpenseIndex: _knobs
          .firstWhere((k) => k.type == UniversalKnobType.operationalExpenseIndex)
          .value,
      capitalAccessPressure: _knobs
          .firstWhere((k) => k.type == UniversalKnobType.capitalAccessPressure)
          .value,
      systemicFriction: _knobs
          .firstWhere((k) => k.type == UniversalKnobType.systemicFriction)
          .value,
      socialEquityWeight: _knobs
          .firstWhere((k) => k.type == UniversalKnobType.socialEquityWeight)
          .value,
      systemicTrustBaseline: _knobs
          .firstWhere((k) => k.type == UniversalKnobType.systemicTrustBaseline)
          .value,
      futureMobilityIndex: _knobs
          .firstWhere((k) => k.type == UniversalKnobType.futureMobilityIndex)
          .value,
      ecologicalPressure: _knobs
          .firstWhere((k) => k.type == UniversalKnobType.ecologicalResourcePressure)
          .value,
    );

    final request = SimulateRequest(
      policyText: simState.policyText,
      simulationTicks: _simTicks,
      agentCount: _agentCount,
      knobOverrides: _overrideActive ? overrides : const KnobOverrides(),
    );

    simState.setSimulating();

    apiClient.simulateStream(request).listen(
      (event) {
        if (event.type == 'tick') {
          try {
            simState.addTick(TickSummary.fromJson(event.data));
          } catch (e) {
            debugPrint('Tick parse error: $e');
          }
        } else if (event.type == 'complete') {
          try {
            simState.setSimulationComplete(SimulateResponse.fromJson(event.data));
          } catch (e) {
            debugPrint('Complete parse error: $e');
          }
        } else if (event.type == 'error') {
          simState.setSimulationFailed(
            event.data['detail'] as String? ?? 'Unknown error',
          );
        }
      },
      onError: (Object e) {
        simState.setSimulationFailed(e.toString());
      },
    );
  }
}
