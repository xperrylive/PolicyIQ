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

import '../state/simulation_state.dart';
import '../models/contracts.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  final Function(int)? onNavigate;
  
  const DashboardScreen({super.key, this.onNavigate});

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

    // Debug: Print simulation parameters
    if (state.status == SimulationStatus.simulating) {
      debugPrint('[DASHBOARD] Simulating - ticks: ${state.ticks.length}/${state.simulationTicks}');
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        children: [
          // Progress indicator for active simulation
          if (state.status == SimulationStatus.simulating)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Processing Month ${state.ticks.length} of ${state.simulationTicks}',
                        style: const TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${((state.ticks.length / state.simulationTicks) * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: state.ticks.length / state.simulationTicks,
                    backgroundColor: AppTheme.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
                    minHeight: 3,
                  ),
                ],
              ),
            ),
          Row(
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
                _LiveStabilityScore(score: latestStability),
              const SizedBox(width: 12),
              if (state.status == SimulationStatus.completed) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to Macro Analytics page (index 3)
                    onNavigate?.call(3);
                  },
                  icon: const Icon(Icons.analytics, size: 16),
                  label: const Text('GENERATE FINAL REPORT',
                      style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(width: 12),
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
              ],
              if (state.status == SimulationStatus.simulating)
                Row(
                  children: [
                    const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.accentCyan)),
                    const SizedBox(width: 8),
                      Text(
                        'SIMULATING ${state.ticks.length}/${state.simulationTicks}',
                        style: const TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentCyan),
                      ),
                  ],
                ),
              if (state.status == SimulationStatus.idle ||
                  state.status == SimulationStatus.validating ||
                  state.status == SimulationStatus.readyToReview)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentAmber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppTheme.accentAmber.withValues(alpha: 0.3)),
                  ),
                  child: const Text('LAUNCH FROM CONTROL PANEL',
                      style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 9,
                          color: AppTheme.accentAmber,
                          fontWeight: FontWeight.w600)),
                ),
            ],
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
          // Skeleton loader when simulating starts
          if (state.status == SimulationStatus.simulating && state.ticks.isEmpty)
            _SkeletonLoader()
          else ...[
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
          ],
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
                : _AnimatedAgentFeed(ticks: state.ticks),
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

class _AnimatedAgentFeed extends StatefulWidget {
  final List<TickSummary> ticks;

  const _AnimatedAgentFeed({required this.ticks});

  @override
  State<_AnimatedAgentFeed> createState() => _AnimatedAgentFeedState();
}

class _AnimatedAgentFeedState extends State<_AnimatedAgentFeed>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  int _lastTickCount = 0;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _lastTickCount = widget.ticks.length;
  }

  @override
  void didUpdateWidget(_AnimatedAgentFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ticks.length > _lastTickCount) {
      _slideController.reset();
      _slideController.forward();
      _lastTickCount = widget.ticks.length;
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.ticks.length,
      reverse: true,
      itemBuilder: (context, index) {
        final tick = widget.ticks[widget.ticks.length - 1 - index];
        final isLatest = index == 0;
        
        Widget card = _AgentTickCard(tick: tick);
        
        if (isLatest && widget.ticks.length > 1) {
          card = SlideTransition(
            position: _slideAnimation,
            child: card,
          );
        }
        
        return card;
      },
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
              _SentimentBadge(sentiment: tick.averageSentiment),
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

class _SentimentBadge extends StatelessWidget {
  final double sentiment;

  const _SentimentBadge({required this.sentiment});

  Color get _color {
    if (sentiment >= 0.3) return AppTheme.accentGreen;
    if (sentiment >= -0.3) return AppTheme.accentAmber;
    return AppTheme.accentRed;
  }

  String get _label {
    if (sentiment >= 0.3) return 'POSITIVE';
    if (sentiment >= -0.3) return 'NEUTRAL';
    return 'NEGATIVE';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '${sentiment.toStringAsFixed(2)} $_label',
        style: TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: _color,
        ),
      ),
    );
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
                  // Live Stability Score Widget
                  if (state.rewardStabilityHistory.isNotEmpty)
                    _LiveStabilityScoreWidget(
                      score: state.rewardStabilityHistory.last,
                      isUnrest: isInUnrest,
                    ),
                  const SizedBox(height: 16),
                  if (state.savedScenarios.isNotEmpty)
                    _ScenarioComparisonBar(state: state),
                  const SizedBox(height: 16),
                  if (state.rewardStabilityHistory.isNotEmpty)
                    _DynamicStressTestChart(
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

class _LiveStabilityScoreWidget extends StatefulWidget {
  final double score;
  final bool isUnrest;

  const _LiveStabilityScoreWidget({
    required this.score,
    required this.isUnrest,
  });

  @override
  State<_LiveStabilityScoreWidget> createState() => _LiveStabilityScoreWidgetState();
}

class _LiveStabilityScoreWidgetState extends State<_LiveStabilityScoreWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;
  double _previousScore = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _previousScore = widget.score;
    
    if (widget.isUnrest) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_LiveStabilityScoreWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.score != _previousScore) {
      if (widget.score < 40 && _previousScore >= 40) {
        // Trigger shake when entering unrest
        _shakeController.forward().then((_) => _shakeController.reset());
      }
      
      if (widget.isUnrest && !oldWidget.isUnrest) {
        _pulseController.repeat(reverse: true);
      } else if (!widget.isUnrest && oldWidget.isUnrest) {
        _pulseController.stop();
        _pulseController.reset();
      }
      
      _previousScore = widget.score;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Color get _color {
    if (widget.score >= 70) return AppTheme.accentGreen;
    if (widget.score >= 40) return AppTheme.accentAmber;
    return AppTheme.accentRed;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _shakeAnimation]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value * (widget.isUnrest ? 1 : 0), 0),
          child: Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _color.withValues(alpha: 0.4), width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    'LIVE STABILITY SCORE',
                    style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _color,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.score.toStringAsFixed(0),
                    style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: _color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.score >= 70 ? 'STABLE' : widget.score >= 40 ? 'MODERATE' : 'UNREST',
                    style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
                const SizedBox(height: 8),
                const Text(
                    'Real-time policy-driven knob values with smooth transitions',
                    style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 9,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic)),
                const SizedBox(height: 16),
                _AnimatedKnobSliders(knobOverrides: state.knobOverrides),
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
}

class _AnimatedKnobSliders extends StatefulWidget {
  final KnobOverrides knobOverrides;

  const _AnimatedKnobSliders({required this.knobOverrides});

  @override
  State<_AnimatedKnobSliders> createState() => _AnimatedKnobSlidersState();
}

class _AnimatedKnobSlidersState extends State<_AnimatedKnobSliders>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  List<double> _previousValues = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _updatePreviousValues();
  }

  void _initializeAnimations() {
    _controllers = List.generate(8, (index) => 
      AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      )
    );
    
    _animations = _controllers.map((controller) =>
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
      )
    ).toList();
  }

  void _updatePreviousValues() {
    _previousValues = [
      widget.knobOverrides.disposableIncomeDelta ?? 0.0,
      widget.knobOverrides.operationalExpenseIndex ?? 0.0,
      widget.knobOverrides.capitalAccessPressure ?? 0.0,
      widget.knobOverrides.systemicFriction ?? 0.0,
      widget.knobOverrides.socialEquityWeight ?? 0.0,
      widget.knobOverrides.systemicTrustBaseline ?? 0.0,
      widget.knobOverrides.futureMobilityIndex ?? 0.0,
      widget.knobOverrides.ecologicalPressure ?? 0.0,
    ];
  }

  @override
  void didUpdateWidget(_AnimatedKnobSliders oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final newValues = [
      widget.knobOverrides.disposableIncomeDelta ?? 0.0,
      widget.knobOverrides.operationalExpenseIndex ?? 0.0,
      widget.knobOverrides.capitalAccessPressure ?? 0.0,
      widget.knobOverrides.systemicFriction ?? 0.0,
      widget.knobOverrides.socialEquityWeight ?? 0.0,
      widget.knobOverrides.systemicTrustBaseline ?? 0.0,
      widget.knobOverrides.futureMobilityIndex ?? 0.0,
      widget.knobOverrides.ecologicalPressure ?? 0.0,
    ];

    for (int i = 0; i < newValues.length; i++) {
      if (newValues[i] != _previousValues[i]) {
        _controllers[i].reset();
        _controllers[i].forward();
      }
    }
    
    _updatePreviousValues();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final knobs = [
      ('Disposable Income Δ', widget.knobOverrides.disposableIncomeDelta ?? 0.0, AppTheme.accentGreen, 0),
      ('Operational Expense Index', widget.knobOverrides.operationalExpenseIndex ?? 0.0, AppTheme.accentRed, 1),
      ('Capital Access Pressure', widget.knobOverrides.capitalAccessPressure ?? 0.0, AppTheme.accentAmber, 2),
      ('Systemic Friction', widget.knobOverrides.systemicFriction ?? 0.0, AppTheme.accentRed, 3),
      ('Social Equity Weight', widget.knobOverrides.socialEquityWeight ?? 0.0, AppTheme.accentCyan, 4),
      ('Systemic Trust Baseline', widget.knobOverrides.systemicTrustBaseline ?? 0.0, AppTheme.accentGreen, 5),
      ('Future Mobility Index', widget.knobOverrides.futureMobilityIndex ?? 0.0, AppTheme.accentCyan, 6),
      ('Ecological Pressure', widget.knobOverrides.ecologicalPressure ?? 0.0, AppTheme.accentAmber, 7),
    ];

    return Column(
      children: knobs.map((knob) {
        final name = knob.$1;
        final value = knob.$2;
        final color = knob.$3;
        final index = knob.$4;
        
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween<double>(begin: _previousValues[index], end: value),
              curve: Curves.easeOutCubic,
              builder: (context, animatedValue, child) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
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
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(name,
                                style: const TextStyle(
                                    fontFamily: 'SpaceMono',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary)),
                          ),
                          Text(
                            '${(animatedValue * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                                fontFamily: 'SpaceMono',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Animated slider visualization
                      Stack(
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: ((animatedValue + 1.0) / 2.0).clamp(0.0, 1.0),
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      }).toList(),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _LiveStabilityScore extends StatelessWidget {
  final double score;

  const _LiveStabilityScore({required this.score});

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

class _SkeletonLoader extends StatefulWidget {
  @override
  State<_SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<_SkeletonLoader>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              // Column 1: Agents skeleton
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShimmerBox(height: 40, width: double.infinity),
                    const SizedBox(height: 16),
                    ...List.generate(3, (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildShimmerBox(height: 80, width: double.infinity),
                    )),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Column 2: Math skeleton
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShimmerBox(height: 40, width: double.infinity),
                    const SizedBox(height: 16),
                    _buildShimmerBox(height: 120, width: double.infinity),
                    const SizedBox(height: 16),
                    _buildShimmerBox(height: 150, width: double.infinity),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Column 3: Macro skeleton
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShimmerBox(height: 40, width: double.infinity),
                    const SizedBox(height: 16),
                    ...List.generate(4, (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildShimmerBox(height: 60, width: double.infinity),
                    )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmerBox({required double height, required double width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: [
            (_shimmerAnimation.value - 1).clamp(0.0, 1.0),
            _shimmerAnimation.value.clamp(0.0, 1.0),
            (_shimmerAnimation.value + 1).clamp(0.0, 1.0),
          ],
          colors: [
            AppTheme.border,
            AppTheme.border.withValues(alpha: 0.5),
            AppTheme.border,
          ],
        ),
      ),
    );
  }
}

class _DynamicStressTestChart extends StatefulWidget {
  final List<double> history;
  final SavedScenario? comparisonScenario;

  const _DynamicStressTestChart({
    required this.history,
    this.comparisonScenario,
  });

  @override
  State<_DynamicStressTestChart> createState() => _DynamicStressTestChartState();
}

class _DynamicStressTestChartState extends State<_DynamicStressTestChart>
    with TickerProviderStateMixin {
  late AnimationController _updateController;
  late Animation<double> _updateAnimation;
  List<double> _previousHistory = [];

  @override
  void initState() {
    super.initState();
    _updateController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _updateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _updateController, curve: Curves.easeOutCubic),
    );
    _previousHistory = List.from(widget.history);
  }

  @override
  void didUpdateWidget(_DynamicStressTestChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.history.length > _previousHistory.length) {
      _updateController.reset();
      _updateController.forward();
      _previousHistory = List.from(widget.history);
    }
  }

  @override
  void dispose() {
    _updateController.dispose();
    super.dispose();
  }

  bool get _isInFailure => widget.history.isNotEmpty && widget.history.last < 40;

  @override
  Widget build(BuildContext context) {
    final borderColor = _isInFailure ? AppTheme.accentRed : AppTheme.accentCyan;

    return AnimatedBuilder(
      animation: _updateAnimation,
      builder: (context, child) {
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
                  if (widget.comparisonScenario != null) ...[
                    _LegendDot(color: AppTheme.accentCyan, label: 'Current'),
                    const SizedBox(width: 10),
                    _LegendDot(
                        color: AppTheme.accentAmber,
                        label: widget.comparisonScenario!.label),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: CustomPaint(
                  painter: _StabilityLinePainter(
                    history: widget.history,
                    comparisonHistory: widget.comparisonScenario?.stabilityHistory,
                    animationProgress: _updateAnimation.value,
                  ),
                  size: Size.infinite,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ...List.generate(
                    widget.history.length,
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
      },
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
  final double animationProgress;

  const _StabilityLinePainter({
    required this.history,
    this.comparisonHistory,
    this.animationProgress = 1.0,
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
