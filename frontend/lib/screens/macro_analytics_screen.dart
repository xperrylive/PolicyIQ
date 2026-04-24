import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/simulation_state.dart';
import '../models/contracts.dart';

class MacroAnalyticsScreen extends StatefulWidget {
  const MacroAnalyticsScreen({super.key});

  @override
  State<MacroAnalyticsScreen> createState() => _MacroAnalyticsScreenState();
}

class _MacroAnalyticsScreenState extends State<MacroAnalyticsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SimulationState>();
    
    // Show empty state if no simulation has been completed
    if (state.status != SimulationStatus.completed || state.finalResult == null) {
      return _buildEmptyState();
    }

    final result = state.finalResult!;
    final finalTick = state.ticks.isNotEmpty ? state.ticks.last : null;
    final finalStabilityScore = state.rewardStabilityHistory.isNotEmpty 
        ? state.rewardStabilityHistory.last 
        : 50.0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _buildHeader(result),
          _buildTabBar(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildExecutiveSummaryTab(result, finalTick, finalStabilityScore),
                  _buildDetailedAnalysisTab(result, finalTick, state),
                  _buildTimelineAnalysisTab(state),
                  _buildRecommendationsTab(result, state),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: AppTheme.accentGreen.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No completed simulation data',
              style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Complete a simulation to view the final executive briefing',
              style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(SimulateResponse result) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.accentGreen.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.analytics,
                    color: AppTheme.accentGreen, size: 18),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MACRO ANALYTICS',
                      style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  Text('Final Executive Briefing',
                      style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 10,
                          color: AppTheme.textMuted)),
                ],
              ),
              const Spacer(),
              _buildStatBubble('${result.timeline.length} Months', AppTheme.accentCyan),
              const SizedBox(width: 12),
              _buildStatBubble('${result.anomalies.length} Anomalies', AppTheme.accentRed),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.simulationMetadata.policy,
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.accentCyan.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        labelColor: AppTheme.accentCyan,
        unselectedLabelColor: AppTheme.textMuted,
        labelStyle: const TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 11,
          fontWeight: FontWeight.normal,
        ),
        tabs: const [
          Tab(text: 'EXECUTIVE SUMMARY'),
          Tab(text: 'DETAILED ANALYSIS'),
          Tab(text: 'TIMELINE'),
          Tab(text: 'RECOMMENDATIONS'),
        ],
      ),
    );
  }

  Widget _buildStatBubble(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 10,
          color: color,
          letterSpacing: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildVerdictCard(double stabilityScore) {
    final isStabilized = stabilityScore > 70;
    final isCritical = stabilityScore < 40;
    
    Color verdictColor;
    String verdictText;
    IconData verdictIcon;
    
    if (isStabilized) {
      verdictColor = AppTheme.accentGreen;
      verdictText = 'STABILIZED';
      verdictIcon = Icons.check_circle;
    } else if (isCritical) {
      verdictColor = AppTheme.accentRed;
      verdictText = 'CRITICAL FAILURE';
      verdictIcon = Icons.error;
    } else {
      verdictColor = AppTheme.accentAmber;
      verdictText = 'MODERATE RISK';
      verdictIcon = Icons.warning;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: verdictColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: verdictColor.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(verdictIcon, color: verdictColor, size: 24),
              const SizedBox(width: 12),
              Text(
                'FINAL STABILITY VERDICT',
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: verdictColor,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            stabilityScore.toStringAsFixed(0),
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: verdictColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            verdictText,
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: verdictColor,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIExecutiveVerdict(SimulateResponse result) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(Icons.psychology, size: 16, color: AppTheme.accentPurple),
              SizedBox(width: 8),
              Text(
                'AI EXECUTIVE VERDICT',
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentPurple,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            result.aiPolicyRecommendation,
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 12,
              color: AppTheme.textPrimary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardTile(String demographic, double score, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            demographic,
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            score >= 0 ? '+${score.toStringAsFixed(2)}' : score.toStringAsFixed(2),
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: score >= 0 ? AppTheme.accentGreen : AppTheme.accentRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKnobDeltaGrid(KnobOverrides knobOverrides) {
    final knobs = [
      ('Disposable Income Δ', knobOverrides.disposableIncomeDelta ?? 0.0, AppTheme.accentGreen),
      ('Operational Expense', knobOverrides.operationalExpenseIndex ?? 0.0, AppTheme.accentRed),
      ('Capital Access', knobOverrides.capitalAccessPressure ?? 0.0, AppTheme.accentAmber),
      ('Systemic Friction', knobOverrides.systemicFriction ?? 0.0, AppTheme.accentRed),
      ('Social Equity', knobOverrides.socialEquityWeight ?? 0.0, AppTheme.accentCyan),
      ('Trust Baseline', knobOverrides.systemicTrustBaseline ?? 0.0, AppTheme.accentGreen),
      ('Mobility Index', knobOverrides.futureMobilityIndex ?? 0.0, AppTheme.accentCyan),
      ('Ecological Pressure', knobOverrides.ecologicalPressure ?? 0.0, AppTheme.accentAmber),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.8,
      ),
      itemCount: knobs.length,
      itemBuilder: (context, index) {
        final knob = knobs[index];
        final name = knob.$1;
        final value = knob.$2;
        
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 8,
                  color: AppTheme.textMuted,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${(value * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: value >= 0 ? AppTheme.accentGreen : AppTheme.accentRed,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVoiceOfThePeopleDigest(TickSummary? finalTick) {
    if (finalTick == null || finalTick.agentActions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: Text(
            'No agent data available',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 11,
              color: AppTheme.textMuted,
            ),
          ),
        ),
      );
    }

    // Find the 3 agents with the lowest reward scores
    final sortedAgents = List<AgentDecision>.from(finalTick.agentActions)
      ..sort((a, b) => a.rewardScore.compareTo(b.rewardScore));
    
    final criticalAgents = sortedAgents.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(Icons.record_voice_over, size: 16, color: AppTheme.accentRed),
              SizedBox(width: 8),
              Text(
                'CRITICAL SENTIMENT FEED',
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentRed,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Voices from the 3 most distressed citizens',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 10,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          ...criticalAgents.map((agent) => _buildCriticalAgentCard(agent)),
        ],
      ),
    );
  }

    // Tab content methods
  Widget _buildExecutiveSummaryTab(SimulateResponse result, TickSummary? finalTick, double finalStabilityScore) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVerdictCard(finalStabilityScore),
          const SizedBox(height: 24),
          _buildAIExecutiveVerdict(result),
          const SizedBox(height: 24),
          _buildKeyMetricsSummary(result, finalTick),
          const SizedBox(height: 24),
          _buildCompactNetImpactGrid(finalTick, context.read<SimulationState>().knobOverrides),
        ],
      ),
    );
  }

  Widget _buildDetailedAnalysisTab(SimulateResponse result, TickSummary? finalTick, SimulationState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDemographicBreakdown(finalTick),
          const SizedBox(height: 24),
          _buildAnomalyAnalysis(result.anomalies),
          const SizedBox(height: 24),
          _buildStabilityAnalysis(state.rewardStabilityHistory),
          const SizedBox(height: 24),
          _buildVoiceOfThePeopleDigest(finalTick),
        ],
      ),
    );
  }

  Widget _buildTimelineAnalysisTab(SimulationState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStabilityChart(state.rewardStabilityHistory),
          const SizedBox(height: 24),
          _buildTickByTickAnalysis(state.ticks),
          const SizedBox(height: 24),
          _buildTrendAnalysis(state.ticks),
        ],
      ),
    );
  }

  Widget _buildRecommendationsTab(SimulateResponse result, SimulationState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPolicyRecommendations(result),
          const SizedBox(height: 24),
          _buildRiskAssessment(result, state),
          const SizedBox(height: 24),
          _buildImplementationGuidance(result),
        ],
      ),
    );
  }

  // New detailed widgets
  Widget _buildKeyMetricsSummary(SimulateResponse result, TickSummary? finalTick) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(Icons.dashboard, size: 16, color: AppTheme.accentCyan),
              SizedBox(width: 8),
              Text(
                'KEY METRICS SUMMARY',
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentCyan,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Sentiment Shift',
                  '${(result.macroSummary.overallSentimentShift * 100).toStringAsFixed(1)}%',
                  result.macroSummary.overallSentimentShift >= 0 ? AppTheme.accentGreen : AppTheme.accentRed,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Inequality Delta',
                  '${(result.macroSummary.inequalityDelta * 100).toStringAsFixed(1)}%',
                  result.macroSummary.inequalityDelta <= 0 ? AppTheme.accentGreen : AppTheme.accentRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Anomalies',
                  '${result.anomalies.length}',
                  result.anomalies.length <= 2 ? AppTheme.accentGreen : AppTheme.accentRed,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Simulation Duration',
                  '${result.timeline.length} months',
                  AppTheme.accentCyan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactNetImpactGrid(TickSummary? finalTick, KnobOverrides knobOverrides) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(Icons.grid_view, size: 16, color: AppTheme.accentCyan),
              SizedBox(width: 8),
              Text(
                'NET IMPACT GRID',
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentCyan,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Social Rewards Section
          const Text(
            'SOCIAL REWARDS (Final Average Scores)',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildRewardTile('B40', finalTick?.averageRewardScore['B40'] ?? 0.0, AppTheme.accentRed)),
              const SizedBox(width: 12),
              Expanded(child: _buildRewardTile('M40', finalTick?.averageRewardScore['M40'] ?? 0.0, AppTheme.accentAmber)),
              const SizedBox(width: 12),
              Expanded(child: _buildRewardTile('T20', finalTick?.averageRewardScore['T20'] ?? 0.0, AppTheme.accentGreen)),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Macro Deltas Section
          const Text(
            'MACRO DELTAS (Policy Impact on 8 Knobs)',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          _buildKnobDeltaGrid(knobOverrides),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 10,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Placeholder methods for other tabs (you can implement these later)
  Widget _buildDemographicBreakdown(TickSummary? finalTick) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Text('Demographic breakdown coming soon...'),
    );
  }

  Widget _buildAnomalyAnalysis(List<Anomaly> anomalies) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text('Found ${anomalies.length} anomalies to analyze...'),
    );
  }

  Widget _buildStabilityAnalysis(List<double> history) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text('Stability analysis for ${history.length} data points...'),
    );
  }

  Widget _buildStabilityChart(List<double> history) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Text('Stability chart coming soon...'),
    );
  }

  Widget _buildTickByTickAnalysis(List<TickSummary> ticks) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text('Tick-by-tick analysis for ${ticks.length} ticks...'),
    );
  }

  Widget _buildTrendAnalysis(List<TickSummary> ticks) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Text('Trend analysis coming soon...'),
    );
  }

  Widget _buildPolicyRecommendations(SimulateResponse result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI POLICY RECOMMENDATIONS',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.accentPurple,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            result.aiPolicyRecommendation,
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 12,
              color: AppTheme.textPrimary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskAssessment(SimulateResponse result, SimulationState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Text('Risk assessment coming soon...'),
    );
  }

  Widget _buildImplementationGuidance(SimulateResponse result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Text('Implementation guidance coming soon...'),
    );
  }



  Widget _buildCriticalAgentCard(AgentDecision agent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentRed.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  agent.agentId,
                  style: const TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentRed,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                agent.demographic.isNotEmpty ? agent.demographic : 'Unknown',
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 10,
                  color: AppTheme.textMuted,
                ),
              ),
              const Spacer(),
              Text(
                'Reward: ${agent.rewardScore.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            agent.internalMonologue.isNotEmpty 
                ? agent.internalMonologue 
                : 'No monologue available',
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 11,
              color: AppTheme.textPrimary,
              height: 1.4,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String label;
  final Color? color;

  const SectionLabel(this.label, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'SpaceMono',
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color ?? AppTheme.textPrimary,
        letterSpacing: 1.2,
      ),
    );
  }
}