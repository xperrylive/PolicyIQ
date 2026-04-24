// dashboard.dart — PolicyIQ MARL Dashboard
//
// Displays:
//   - Digital Malaysian Feed: per-demographic agent_actions + avg_reward_score
//   - Stability Gauge: color-coded by reward_stability_score (0–100)
//   - Stress Test Line Chart: reward_stability vs time, turns red below 40
//   - Scenario Comparison: overlay Scenario A vs B stability charts

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../models/contracts.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _runSimulation(BuildContext context) async {
    final state = context.read<SimulationState>();
    final client = context.read<ApiClient>();
    if (state.policyText.isEmpty) return;
    state.setSimulating(true);

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
            state.setFinalResult(SimulateResponse.fromJson(event.data));
          case 'error':
            state.setSimulationError(
                event.data['detail']?.toString() ?? 'Unknown error');
        }
      }
    } catch (e) {
      state.setSimulationError(e.toString());
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
            child: state.ticks.isEmpty && !state.isSimulating
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
              Text('DIGITAL MALAYSIAN FEED',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              Text('MARL Agent Reward Dashboard',
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
          // ── Save Scenario button (shown when simulation is complete) ────────
          if (state.finalResult != null && !state.isSimulating) ...[
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
          if (state.isSimulating)
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.accentCyan)),
          if (!state.isSimulating && state.isPolicyApproved)
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
          if (!state.isPolicyApproved && !state.isSimulating)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            state.isPolicyApproved
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Scenario Comparison Selector ────────────────────────────────
          if (state.savedScenarios.isNotEmpty) ...[
            _ScenarioComparisonBar(state: state),
            const SizedBox(height: 16),
          ],
          // ── Stress Test Line Chart (with optional overlay) ──────────────
          if (state.rewardStabilityHistory.isNotEmpty) ...[
            _StressTestChart(
              history: state.rewardStabilityHistory,
              comparisonScenario: state.comparisonScenario,
            ),
            const SizedBox(height: 20),
          ],
          // ── Digital Malaysian Feed (latest tick) ────────────────────────
          if (state.ticks.isNotEmpty) ...[
            _DigitalMalaysianFeed(ticks: state.ticks),
            const SizedBox(height: 20),
          ],
          // ── Macro summary ───────────────────────────────────────────────
          if (state.finalResult != null) ...[
            _MacroSummaryCard(result: state.finalResult!),
            const SizedBox(height: 20),
          ],
          // ── AI Recommendation ───────────────────────────────────────────
          if (state.finalResult?.aiPolicyRecommendation.isNotEmpty == true)
            _RecommendationCard(
                text: state.finalResult!.aiPolicyRecommendation),
        ],
      ),
    );
  }
}

// ─── Scenario Comparison Bar ──────────────────────────────────────────────────

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
      child: Row(
        children: [
          const Icon(Icons.compare_arrows_rounded,
              size: 14, color: AppTheme.accentPurple),
          const SizedBox(width: 8),
          const Text('COMPARE WITH:',
              style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentPurple)),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // "None" chip
                  _ScenarioChip(
                    label: 'None',
                    isSelected: state.comparisonScenarioId == null,
                    color: AppTheme.textMuted,
                    onTap: () => state.setComparisonScenario(null),
                  ),
                  const SizedBox(width: 6),
                  ...state.savedScenarios.map((s) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _ScenarioChip(
                          label: s.label,
                          isSelected: state.comparisonScenarioId == s.id,
                          color: AppTheme.accentCyan,
                          onTap: () => state.setComparisonScenario(s.id),
                        ),
                      )),
                ],
              ),
            ),
          ),
          // Refine & Re-run button (shown when a scenario is selected)
          if (state.comparisonScenario != null) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () =>
                  state.refineFromScenario(state.comparisonScenario!),
              icon: const Icon(Icons.edit_note_rounded, size: 14),
              label: const Text('REFINE & RE-RUN',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentAmber,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

// ─── Stability Gauge Badge ────────────────────────────────────────────────────

class _StabilityGaugeBadge extends StatelessWidget {
  final double score; // 0–100

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
          Text(
            'STABILITY: ${score.toStringAsFixed(0)} — $_label',
            style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _color),
          ),
        ],
      ),
    );
  }
}

// ─── Digital Malaysian Feed ───────────────────────────────────────────────────

class _DigitalMalaysianFeed extends StatelessWidget {
  final List<TickSummary> ticks;

  const _DigitalMalaysianFeed({required this.ticks});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
            icon: Icons.people_alt_outlined,
            label: 'DEMOGRAPHIC REWARD FEED',
            color: AppTheme.accentCyan),
        const SizedBox(height: 12),
        // Show all ticks, most recent first
        ...ticks.reversed.map((tick) => _TickFeedCard(tick: tick)),
      ],
    );
  }
}

class _TickFeedCard extends StatelessWidget {
  final TickSummary tick;

  const _TickFeedCard({required this.tick});

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
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
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentCyan)),
              const SizedBox(width: 12),
              Text(
                  'avg sentiment: ${tick.averageSentiment.toStringAsFixed(3)}',
                  style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      color: AppTheme.textMuted)),
              const Spacer(),
              _StabilityGaugeBadge(score: tick.rewardStabilityScore),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: demos.map((demo) {
              final color = demoColors[demo]!;
              final reward = tick.averageRewardScore[demo];
              final action = tick.demoActionSummary[demo] ?? '—';
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                      right: demo != 'T20' ? 8 : 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(demo,
                                style: TextStyle(
                                    fontFamily: 'SpaceMono',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: color)),
                          ),
                          const Spacer(),
                          if (reward != null)
                            Text(
                              reward >= 0
                                  ? '+${reward.toStringAsFixed(3)}'
                                  : reward.toStringAsFixed(3),
                              style: TextStyle(
                                  fontFamily: 'SpaceMono',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: reward >= 0
                                      ? AppTheme.accentGreen
                                      : AppTheme.accentRed),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _humanizeAction(action),
                        style: const TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 9,
                            color: AppTheme.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      if (reward != null)
                        _RewardBar(reward: reward, color: color),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Converts snake_case action to human-readable label.
  String _humanizeAction(String raw) {
    // e.g. "60% of B40 agents are 'cutting_expenses'" → "60% Cutting Expenses"
    return raw
        .replaceAll("'", '')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty
            ? '${w[0].toUpperCase()}${w.substring(1)}'
            : w)
        .join(' ');
  }
}

class _RewardBar extends StatelessWidget {
  final double reward; // typically -1.0 to 1.0
  final Color color;

  const _RewardBar({required this.reward, required this.color});

  @override
  Widget build(BuildContext context) {
    // Map reward [-1, 1] → fill fraction [0, 1]
    final fill = ((reward + 1.0) / 2.0).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('REWARD',
            style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 8,
                color: AppTheme.textMuted)),
        const SizedBox(height: 3),
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.border,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fill,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Stress Test Line Chart ───────────────────────────────────────────────────

class _StressTestChart extends StatelessWidget {
  final List<double> history; // reward_stability_score per tick (current run)
  final SavedScenario? comparisonScenario; // optional overlay

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
              _SectionHeader(
                icon: _isInFailure
                    ? Icons.warning_amber_rounded
                    : Icons.show_chart_rounded,
                label: 'REWARD STABILITY vs TIME',
                color: borderColor,
              ),
              const Spacer(),
              // Comparison legend
              if (comparisonScenario != null) ...[
                _LegendDot(
                    color: AppTheme.accentCyan, label: 'Current'),
                const SizedBox(width: 10),
                _LegendDot(
                    color: AppTheme.accentAmber,
                    label: comparisonScenario!.label),
                const SizedBox(width: 10),
              ],
              if (_isInFailure)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppTheme.accentRed.withValues(alpha: 0.5)),
                  ),
                  child: const Text('⚠ POLICY FAILURE / SOCIAL UNREST',
                      style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentRed)),
                ),
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
                fontFamily: 'SpaceMono',
                fontSize: 9,
                color: color)),
      ],
    );
  }
}

class _StabilityLinePainter extends CustomPainter {
  final List<double> history;
  final List<double>? comparisonHistory; // optional overlay (Scenario B)

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

    // Draw "40" label
    final tp = TextPainter(
      text: TextSpan(
        text: '40',
        style: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 8,
            color: AppTheme.accentRed.withValues(alpha: 0.6)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(2, thresholdY - 10));

    // ── Draw comparison overlay (Scenario B) first so it sits behind ─────────
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

    // ── Draw current run (Scenario A / active) ────────────────────────────────
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

// ─── Macro Summary Card ───────────────────────────────────────────────────────

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
          const _SectionHeader(
              icon: Icons.analytics_outlined,
              label: 'MACRO SUMMARY',
              color: AppTheme.accentGreen),
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
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Anomalies',
                  value: '${result.anomalies.length}',
                  color: result.anomalies.isEmpty
                      ? AppTheme.accentGreen
                      : AppTheme.accentAmber,
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

// ─── AI Recommendation Card ───────────────────────────────────────────────────

class _RecommendationCard extends StatelessWidget {
  final String text;

  const _RecommendationCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentPurple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppTheme.accentPurple.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
              icon: Icons.auto_awesome,
              label: 'AI POLICY RECOMMENDATION',
              color: AppTheme.accentPurple),
          const SizedBox(height: 10),
          Text(text,
              style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  height: 1.6)),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionHeader(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.8)),
      ],
    );
  }
}
