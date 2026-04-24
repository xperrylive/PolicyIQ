// dashboard_screen.dart — PolicyIQ MARL Dashboard (State-Driven Refactor)
//
// 3-Column Layout:
// - Column 1: The Agents (50-agent population feed with actions + rewards)
// - Column 2: The Math (Reward Stability Score line chart, triggers SOCIAL UNREST if < 40)
// - Column 3: The Macro (8 Knobs shifting in real-time via Recession Spiral)
//
// A/B Comparison: Ghost line overlay for saved scenarios

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/simulation_state.dart';
import '../models/contracts.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _runSimulation(BuildContext context) async {
    final state = context.read<SimulationState>();
    final client = context.read<ApiClient>();
    
    if (state.policyText.isEmpty) return;
    if (state.status != SimulationStatus.readyToReview && 
        state.status != SimulationStatus.completed) return;
    
    state.setSimulating();

    final request = SimulateRequest(
      policyText: state.policyText,
      simulationTicks: state.simulationTicks,
      agentCount: state.agentCount,
      knobOverrides: state.knobOverrides,
    );

    try {
      await for (final event in client.simulateStream(request)) {
        switch (event.type) {
          case 'tick':
            state.addTick(TickSummary.fromJson(event.data));
          case 'complete':
            state.setSimulationComplete(SimulateResponse.fromJson(event.data));
          case 'error':
            state.setSimulationFailed(
                event.data['detail']?.toString() ?? 'Unknown error');
        }
      }
    } catch (e) {
      state.setSimulationFailed(e.toString());
    }
  }

  void _showSaveScenarioDialog(BuildContext context) {
    final state = context.read<SimulationState>();
    final controller = TextEditingController(
      text: 'Scenario ${state.savedScenarios.length + 1}',
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Save Scenario',
            style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 14,
                color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(
              fontFamily: 'SpaceMono', fontSize: 12, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. Failed Policy / Refined Policy',
            hintStyle: const TextStyle(
                fontFamily: 'SpaceMono', fontSize: 11, color: AppTheme.textMuted),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppTheme.accentCyan),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 11,
                    color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () {
              final label = controller.text.trim();
              if (label.isNotEmpty) {
                state.saveCurrentScenario(label);
              }
              Navigator.pop(ctx);
            },
            child: const Text('SAVE',
                style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SimulationState>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _buildHeader(context, state),
          Expanded(
            child: state.status == SimulationStatus.idle ||
                    state.status == SimulationStatus.validating
                ? _buildEmptyState(state)
                : _buildMainContent(context, state),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SimulationState state) {
    final latestStability = state.rewardStabilityHistory.isNotEmpty
        ? state.rewardStabilityHistory.last
        : null;

    final canRun = state.status == SimulationStatus.readyToReview ||
        state.status == SimulationStatus.completed;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.accentPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppTheme.accentPurple.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.people_alt,
                color: AppTheme.accentPurple, size: 18),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LIVE DASHBOARD',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              Text('MARL Agent Reward Monitor',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      color: AppTheme.textMuted)),
            ],
          ),
          const Spacer(),
          if (latestStability != null)
            _StabilityGaugeBadge(score: latestStability),
          const SizedBox(width: 12),
          if (state.status == SimulationStatus.completed) ...[
            OutlinedButton.icon(
              onPressed: () => _showSaveScenarioDialog(context),
              icon: const Icon(Icons.bookmark_add_outlined, size: 14),
              label: const Text('SAVE SCENARIO',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentCyan,
                side: const BorderSide(color: AppTheme.accentCyan),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (state.status == SimulationStatus.simulating)
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.accentCyan)),
          if (canRun)
            ElevatedButton.icon(
              onPressed: () => _runSimulation(context),
              icon: const Icon(Icons.play_arrow_rounded, size: 16),
              label: const Text('RUN SIMULATION',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentPurple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
            ),
          if (!canRun && state.status != SimulationStatus.simulating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accentAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: AppTheme.accentAmber.withValues(alpha: 0.3)),
              ),
              child: const Text('VALIDATE POLICY FIRST',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 9,
                      color: AppTheme.accentAmber,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(SimulationState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded,
              size: 64,
              color: AppTheme.accentPurple.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('No simulation data yet',
              style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 14,
                  color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          Text(
            state.status == SimulationStatus.readyToReview
                ? 'Click RUN SIMULATION to start the MARL loop'
                : 'Validate a policy in the Gatekeeper tab first',
            style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 11,
                color: AppTheme.textMuted),
          ),
          if (state.simulationError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: AppTheme.accentRed.withValues(alpha: 0.3)),
              ),
              child: Text(state.simulationError!,
                  style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      color: AppTheme.accentRed)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, SimulationState state) {
    return Row(
      children: [
        // Column 1: The Agents
        Expanded(
          flex: 2,
          child: _AgentColumn(state: state),
        ),
        // Column 2: The Math
        Expanded(
          flex: 2,
          child: _MathColumn(state: state),
        ),
        // Column 3: The Macro
        Expanded(
          flex: 2,
          child: _MacroColumn(state: state),
        ),
      ],
    );
  }
}

// ─── Column 1: The Agents ─────────────────────────────────────────────────────

class _AgentColumn extends StatelessWidget {
  final SimulationState state;

  const _AgentColumn({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        children: [
          _buildColumnHeader('THE AGENTS', Icons.people_alt, AppTheme.accentCyan),
          Expanded(
            child: state.ticks.isEmpty
                ? const Center(
                    child: Text('Waiting for simulation ticks...',
                        style: TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 11,
                            color: AppTheme.textMuted)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.ticks.length,
                    reverse: true,
                    itemBuilder: (context, index) {
                      final tick = state.ticks[state.ticks.length - 1 - index];
                      return _AgentTickCard(tick: tick);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeader(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 1)),
        ],
      ),
    );
  }
}

class _AgentTickCard extends StatelessWidget {
  final TickSummary tick;

  const _AgentTickCard({required this.tick});

  @override
  Widget build(BuildContext context) {
    const demos = ['B40', 'M40', 'T20'];
    final demoColors = {
      'B40': AppTheme.accentRed,
      'M40': AppTheme.accentAmber,
      'T20': AppTheme.accentGreen,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('TICK ${tick.tickId}',
                  style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentCyan)),
              const Spacer(),
              Text('avg: ${tick.averageSentiment.toStringAsFixed(3)}',
                  style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 9,
                      color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          ...demos.map((demo) {
            final color = demoColors[demo]!;
            final reward = tick.averageRewardScore[demo];
            final action = tick.demoActionSummary[demo] ?? '—';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(demo,
                        style: TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_humanizeAction(action),
                        style: const TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 9,
                            color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (reward != null)
                    Text(
                      reward >= 0
                          ? '+${reward.toStringAsFixed(2)}'
                          : reward.toStringAsFixed(2),
                      style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: reward >= 0
                              ? AppTheme.accentGreen
                              : AppTheme.accentRed),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _humanizeAction(String raw) {
    return raw
        .replaceAll("'", '')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
        .join(' ');
  }
}

// ─── Column 2: The Math ───────────────────────────────────────────────────────

class _MathColumn extends StatelessWidget {
  final SimulationState state;

  const _MathColumn({required this.state});

  @override
  Widget build(BuildContext context) {
    final isInUnrest = state.rewardStabilityHistory.isNotEmpty &&
        state.rewardStabilityHistory.last < 40;

    return Container(
      decoration: BoxDecoration(
        color: isInUnrest
            ? AppTheme.accentRed.withValues(alpha: 0.03)
            : AppTheme.background,
        border: const Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        children: [
          _buildColumnHeader('THE MATH', Icons.functions, AppTheme.accentAmber,
              isUnrest: isInUnrest),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (state.savedScenarios.isNotEmpty)
                    _ScenarioComparisonBar(state: state),
                  const SizedBox(height: 16),
                  if (state.rewardStabilityHistory.isNotEmpty)
                    _StressTestChart(
                      history: state.rewardStabilityHistory,
                      comparisonScenario: state.comparisonScenario,
                    ),
                  if (state.finalResult != null) ...[
                    const SizedBox(height: 20),
                    _MacroSummaryCard(result: state.finalResult!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeader(String label, IconData icon, Color color,
      {bool isUnrest = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnrest
            ? AppTheme.accentRed.withValues(alpha: 0.1)
            : color.withValues(alpha: 0.05),
        border: Border(
            bottom: BorderSide(
                color: isUnrest
                    ? AppTheme.accentRed.withValues(alpha: 0.4)
                    : color.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 16, color: isUnrest ? AppTheme.accentRed : color),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isUnrest ? AppTheme.accentRed : color,
                  letterSpacing: 1)),
          if (isUnrest) ...[
            const Spacer(),
            const Text('⚠ SOCIAL UNREST',
                style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentRed)),
          ],
        ],
      ),
    );
  }
}

// ─── Column 3: The Macro ──────────────────────────────────────────────────────

class _MacroColumn extends StatelessWidget {
  final SimulationState state;

  const _MacroColumn({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildColumnHeader('THE MACRO', Icons.trending_up, AppTheme.accentGreen),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('8 KNOBS - RECESSION SPIRAL LOGIC',
                    style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                        letterSpacing: 0.8)),
                const SizedBox(height: 12),
                const Text(
                    'Knob(t+1) = Knob(t) × (1 + macro_delta)',
                    style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 9,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic)),
                const SizedBox(height: 16),
                _buildKnobList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColumnHeader(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildKnobList() {
    final knobs = [
      ('Disposable Income Δ', AppTheme.accentGreen),
      ('Operational Expense Index', AppTheme.accentRed),
      ('Capital Access Pressure', AppTheme.accentAmber),
      ('Systemic Friction', AppTheme.accentRed),
      ('Social Equity Weight', AppTheme.accentCyan),
      ('Systemic Trust Baseline', AppTheme.accentGreen),
      ('Future Mobility Index', AppTheme.accentCyan),
      ('Ecological Resource Pressure', AppTheme.accentAmber),
    ];

    return Column(
      children: knobs.map((knob) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: knob.$2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(knob.$1,
                    style: const TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 10,
                        color: AppTheme.textPrimary)),
              ),
              Text('→',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      color: knob.$2)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _StabilityGaugeBadge extends StatelessWidget {
  final double score;

  const _StabilityGaugeBadge({required this.score});

  Color get _color {
    if (score >= 70) return AppTheme.accentGreen;
    if (score >= 40) return AppTheme.accentAmber;
    return AppTheme.accentRed;
  }

  String get _label {
    if (score >= 70) return 'STABLE';
    if (score >= 40) return 'MODERATE';
    return 'UNREST';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('STABILITY: ${score.toStringAsFixed(0)} — $_label',
              style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _color)),
        ],
      ),
    );
  }
}

class _ScenarioComparisonBar extends StatelessWidget {
  final SimulationState state;

  const _ScenarioComparisonBar({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentPurple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentPurple.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.compare_arrows_rounded,
                  size: 12, color: AppTheme.accentPurple),
              SizedBox(width: 6),
              Text('A/B COMPARISON',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentPurple)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              _ScenarioChip(
                label: 'None',
                isSelected: state.comparisonScenarioId == null,
                color: AppTheme.textMuted,
                onTap: () => state.setComparisonScenario(null),
              ),
              ...state.savedScenarios.map((s) => _ScenarioChip(
                    label: s.label,
                    isSelected: state.comparisonScenarioId == s.id,
                    color: AppTheme.accentAmber,
                    onTap: () => state.setComparisonScenario(s.id),
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScenarioChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ScenarioChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.6)
                  : AppTheme.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.normal,
                color: isSelected ? color : AppTheme.textMuted)),
      ),
    );
  }
}

// ─── Column 1: The Agents ─────────────────────────────────────────────────────


class _StressTestChart extends StatelessWidget {
  final List<double> history;
  final SavedScenario? comparisonScenario;

  const _StressTestChart({
    required this.history,
    this.comparisonScenario,
  });

  bool get _isInFailure => history.isNotEmpty && history.last < 40;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        _isInFailure ? AppTheme.accentRed : AppTheme.accentCyan;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isInFailure
            ? AppTheme.accentRed.withValues(alpha: 0.05)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  _isInFailure
                      ? Icons.warning_amber_rounded
                      : Icons.show_chart_rounded,
                  size: 14,
                  color: borderColor),
              const SizedBox(width: 8),
              Text('REWARD STABILITY vs TIME',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: borderColor,
                      letterSpacing: 0.8)),
              const Spacer(),
              if (comparisonScenario != null) ...[
                _LegendDot(color: AppTheme.accentCyan, label: 'Current'),
                const SizedBox(width: 10),
                _LegendDot(
                    color: AppTheme.accentAmber,
                    label: comparisonScenario!.label),
              ],
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _StabilityLinePainter(
                history: history,
                comparisonHistory: comparisonScenario?.stabilityHistory,
              ),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ...List.generate(
                history.length,
                (i) => Text('T${i + 1}',
                    style: const TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 9,
                        color: AppTheme.textMuted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontFamily: 'SpaceMono', fontSize: 9, color: color)),
      ],
    );
  }
}

class _StabilityLinePainter extends CustomPainter {
  final List<double> history;
  final List<double>? comparisonHistory;

  const _StabilityLinePainter({
    required this.history,
    this.comparisonHistory,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final isFailure = history.last < 40;
    final lineColor = isFailure ? AppTheme.accentRed : AppTheme.accentCyan;

    // Draw threshold line at 40
    final thresholdY = size.height - (40 / 100) * size.height;
    final threshPaint = Paint()
      ..color = AppTheme.accentRed.withValues(alpha: 0.4)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
        Offset(0, thresholdY), Offset(size.width, thresholdY), threshPaint);

    // Draw comparison overlay (ghost line) first
    if (comparisonHistory != null && comparisonHistory!.isNotEmpty) {
      _drawLine(
        canvas: canvas,
        size: size,
        data: comparisonHistory!,
        color: AppTheme.accentAmber,
        dashed: true,
        drawFill: false,
        drawLabels: false,
      );
    }

    // Draw current run
    _drawLine(
      canvas: canvas,
      size: size,
      data: history,
      color: lineColor,
      dashed: false,
      drawFill: true,
      drawLabels: true,
    );
  }

  void _drawLine({
    required Canvas canvas,
    required Size size,
    required List<double> data,
    required Color color,
    required bool dashed,
    required bool drawFill,
    required bool drawLabels,
  }) {
    final n = data.length;
    final xStep = n > 1 ? size.width / (n - 1) : size.width;

    if (drawFill) {
      final fillPath = Path();
      fillPath.moveTo(0, size.height);
      for (int i = 0; i < n; i++) {
        final x = i * xStep;
        final y = size.height - (data[i] / 100) * size.height;
        fillPath.lineTo(x, y);
      }
      fillPath.lineTo((n - 1) * xStep, size.height);
      fillPath.close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..color = color.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill,
      );
    }

    // Build line path
    final linePath = Path();
    for (int i = 0; i < n; i++) {
      final x = i * xStep;
      final y = size.height - (data[i] / 100) * size.height;
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = dashed ? 1.5 : 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (dashed) {
      // Draw dashed line manually
      final pathMetrics = linePath.computeMetrics();
      for (final metric in pathMetrics) {
        double distance = 0;
        const dashLen = 6.0;
        const gapLen = 4.0;
        bool drawing = true;
        while (distance < metric.length) {
          final next = math.min(
              distance + (drawing ? dashLen : gapLen), metric.length);
          if (drawing) {
            canvas.drawPath(
              metric.extractPath(distance, next),
              linePaint,
            );
          }
          distance = next;
          drawing = !drawing;
        }
      }
    } else {
      canvas.drawPath(linePath, linePaint);
    }

    // Draw dots + labels
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (int i = 0; i < n; i++) {
      final x = i * xStep;
      final y = size.height - (data[i] / 100) * size.height;
      canvas.drawCircle(Offset(x, y), dashed ? 3 : 4, dotPaint);
      if (drawLabels) {
        final label = TextPainter(
          text: TextSpan(
            text: data[i].toStringAsFixed(0),
            style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: color),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, Offset(x - label.width / 2, math.max(0, y - 16)));
      }
    }
  }

  @override
  bool shouldRepaint(_StabilityLinePainter old) =>
      old.history != history || old.comparisonHistory != comparisonHistory;
}

class _MacroSummaryCard extends StatelessWidget {
  final SimulateResponse result;

  const _MacroSummaryCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final shift = result.macroSummary.overallSentimentShift;
    final ineq = result.macroSummary.inequalityDelta;

    return Container(
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
              Icon(Icons.analytics_outlined,
                  size: 12, color: AppTheme.accentGreen),
              SizedBox(width: 8),
              Text('MACRO SUMMARY',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentGreen,
                      letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Sentiment Shift',
                  value: shift >= 0
                      ? '+${shift.toStringAsFixed(3)}'
                      : shift.toStringAsFixed(3),
                  color: shift >= 0
                      ? AppTheme.accentGreen
                      : AppTheme.accentRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Inequality Δ',
                  value: ineq >= 0
                      ? '+${ineq.toStringAsFixed(3)}'
                      : ineq.toStringAsFixed(3),
                  color: ineq <= 0
                      ? AppTheme.accentGreen
                      : AppTheme.accentRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 9,
                  color: AppTheme.textMuted)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}
