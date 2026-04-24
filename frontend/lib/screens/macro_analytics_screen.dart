import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/simulation_state.dart';
import '../models/contracts.dart';

// Extension for List.takeLast
extension ListExtension<T> on List<T> {
  List<T> takeLast(int count) {
    if (count >= length) return this;
    return sublist(length - count);
  }
}

// Custom painter for stability chart
class StabilityChartPainter extends CustomPainter {
  final List<double> data;
  
  StabilityChartPainter(this.data);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    final paint = Paint()
      ..color = AppTheme.accentCyan
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final fillPaint = Paint()
      ..color = AppTheme.accentCyan.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    
    final path = Path();
    final fillPath = Path();
    
    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;
    
    if (range == 0) return;
    
    // Create path points
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minValue) / range) * size.height;
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    
    // Complete fill path
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    
    // Draw fill and line
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
    
    // Draw data points
    final pointPaint = Paint()
      ..color = AppTheme.accentCyan
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minValue) / range) * size.height;
      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

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
          // Compact 4-column grid for better space utilization
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildCompactMetricCard(
                'Sentiment',
                '${(result.macroSummary.overallSentimentShift * 100).toStringAsFixed(1)}%',
                result.macroSummary.overallSentimentShift >= 0 ? AppTheme.accentGreen : AppTheme.accentRed,
                Icons.sentiment_satisfied,
              ),
              _buildCompactMetricCard(
                'Inequality',
                '${(result.macroSummary.inequalityDelta * 100).toStringAsFixed(1)}%',
                result.macroSummary.inequalityDelta <= 0 ? AppTheme.accentGreen : AppTheme.accentRed,
                Icons.balance,
              ),
              _buildCompactMetricCard(
                'Anomalies',
                '${result.anomalies.length}',
                result.anomalies.length <= 2 ? AppTheme.accentGreen : AppTheme.accentRed,
                Icons.warning,
              ),
              _buildCompactMetricCard(
                'Duration',
                '${result.timeline.length}mo',
                AppTheme.accentCyan,
                Icons.schedule,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Additional metrics row
          Row(
            children: [
              Expanded(
                child: _buildCompactMetricCard(
                  'Avg Agent Score',
                  finalTick != null ? '${_calculateOverallAverage(finalTick.averageRewardScore).toStringAsFixed(2)}' : 'N/A',
                  finalTick != null && _calculateOverallAverage(finalTick.averageRewardScore) >= 0 
                      ? AppTheme.accentGreen : AppTheme.accentRed,
                  Icons.people,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactMetricCard(
                  'Policy Impact',
                  _getPolicyImpactLevel(result.macroSummary.overallSentimentShift),
                  _getPolicyImpactColor(result.macroSummary.overallSentimentShift),
                  Icons.policy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactMetricCard(
                  'Risk Level',
                  _getRiskLevel(result.anomalies.length),
                  _getRiskColor(result.anomalies.length),
                  Icons.security,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactMetricCard(
                  'Stability',
                  finalTick != null ? '${_getStabilityTrend(finalTick)}' : 'N/A',
                  AppTheme.accentCyan,
                  Icons.trending_up,
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


  Widget _buildCompactMetricCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 9,
              color: AppTheme.textMuted,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper methods for metric calculations
  double _calculateOverallAverage(Map<String, double> rewardScores) {
    if (rewardScores.isEmpty) return 0.0;
    return rewardScores.values.reduce((a, b) => a + b) / rewardScores.length;
  }

  String _getPolicyImpactLevel(double sentimentShift) {
    if (sentimentShift > 0.1) return 'HIGH+';
    if (sentimentShift > 0.05) return 'MED+';
    if (sentimentShift > -0.05) return 'LOW';
    if (sentimentShift > -0.1) return 'MED-';
    return 'HIGH-';
  }

  Color _getPolicyImpactColor(double sentimentShift) {
    if (sentimentShift > 0.05) return AppTheme.accentGreen;
    if (sentimentShift > -0.05) return AppTheme.accentAmber;
    return AppTheme.accentRed;
  }

  String _getRiskLevel(int anomalies) {
    if (anomalies == 0) return 'NONE';
    if (anomalies <= 2) return 'LOW';
    if (anomalies <= 5) return 'MED';
    return 'HIGH';
  }

  Color _getRiskColor(int anomalies) {
    if (anomalies == 0) return AppTheme.accentGreen;
    if (anomalies <= 2) return AppTheme.accentCyan;
    if (anomalies <= 5) return AppTheme.accentAmber;
    return AppTheme.accentRed;
  }

  String _getStabilityTrend(TickSummary tick) {
    final avgScore = _calculateOverallAverage(tick.averageRewardScore);
    if (avgScore > 0.5) return 'STABLE';
    if (avgScore > 0) return 'MIXED';
    return 'UNSTABLE';
  }

  // Placeholder methods for other tabs (you can implement these later)
  Widget _buildDemographicBreakdown(TickSummary? finalTick) {
    if (finalTick == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: Text(
            'No demographic data available',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 11,
              color: AppTheme.textMuted,
            ),
          ),
        ),
      );
    }

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
              Icon(Icons.groups, size: 16, color: AppTheme.accentCyan),
              SizedBox(width: 8),
              Text(
                'DEMOGRAPHIC BREAKDOWN',
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
          
          // Income Groups Analysis
          _buildDemographicSection(
            'INCOME GROUPS',
            [
              _buildDemographicCard('B40 (Bottom 40%)', 
                finalTick.averageRewardScore['B40'] ?? 0.0, 
                AppTheme.accentRed,
                'Most vulnerable to policy changes',
                _countAgentsByDemographic(finalTick, 'B40')),
              _buildDemographicCard('M40 (Middle 40%)', 
                finalTick.averageRewardScore['M40'] ?? 0.0, 
                AppTheme.accentAmber,
                'Moderate policy sensitivity',
                _countAgentsByDemographic(finalTick, 'M40')),
              _buildDemographicCard('T20 (Top 20%)', 
                finalTick.averageRewardScore['T20'] ?? 0.0, 
                AppTheme.accentGreen,
                'Least affected by changes',
                _countAgentsByDemographic(finalTick, 'T20')),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Regional Distribution
          _buildRegionalDistribution(finalTick),
          
          const SizedBox(height: 24),
          
          // Behavioral Patterns
          _buildBehavioralPatterns(finalTick),
        ],
      ),
    );
  }

  Widget _buildDemographicSection(String title, List<Widget> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: cards.map((card) => Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: card,
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildDemographicCard(String group, double score, Color color, String description, int agentCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                group,
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '$agentCount agents',
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 8,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            score >= 0 ? '+${score.toStringAsFixed(2)}' : score.toStringAsFixed(2),
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: score >= 0 ? AppTheme.accentGreen : AppTheme.accentRed,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 9,
              color: AppTheme.textMuted,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionalDistribution(TickSummary finalTick) {
    final regions = _analyzeRegionalDistribution(finalTick);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'REGIONAL IMPACT DISTRIBUTION',
          style: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: regions.entries.map((entry) => 
              _buildRegionalItem(entry.key, entry.value)
            ).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRegionalItem(String region, Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              region,
              style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 10,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${data['count']} agents',
              style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 9,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Avg: ${data['avgScore'].toStringAsFixed(2)}',
              style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: data['avgScore'] >= 0 ? AppTheme.accentGreen : AppTheme.accentRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBehavioralPatterns(TickSummary finalTick) {
    final patterns = _analyzeBehavioralPatterns(finalTick);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BEHAVIORAL PATTERNS',
          style: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.5,
          children: [
            _buildPatternCard('Satisfaction Rate', '${patterns['satisfactionRate']}%', AppTheme.accentGreen),
            _buildPatternCard('Adaptation Speed', patterns['adaptationSpeed'], AppTheme.accentCyan),
            _buildPatternCard('Risk Tolerance', patterns['riskTolerance'], AppTheme.accentAmber),
            _buildPatternCard('Policy Sensitivity', patterns['policySensitivity'], AppTheme.accentRed),
          ],
        ),
      ],
    );
  }

  Widget _buildPatternCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 9,
              color: AppTheme.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper methods for demographic analysis
  int _countAgentsByDemographic(TickSummary tick, String demographic) {
    return tick.agentActions.where((agent) => agent.demographic == demographic).length;
  }

  Map<String, Map<String, dynamic>> _analyzeRegionalDistribution(TickSummary finalTick) {
    final regions = <String, List<double>>{};
    
    for (final agent in finalTick.agentActions) {
      final region = agent.agentId.split('_').first; // Assuming agent IDs have region prefix
      regions.putIfAbsent(region, () => []).add(agent.rewardScore);
    }
    
    return regions.map((region, scores) => MapEntry(region, {
      'count': scores.length,
      'avgScore': scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length,
    }));
  }

  Map<String, dynamic> _analyzeBehavioralPatterns(TickSummary finalTick) {
    final positiveAgents = finalTick.agentActions.where((a) => a.rewardScore > 0).length;
    final totalAgents = finalTick.agentActions.length;
    
    return {
      'satisfactionRate': totalAgents > 0 ? ((positiveAgents / totalAgents) * 100).round() : 0,
      'adaptationSpeed': _getAdaptationSpeed(finalTick),
      'riskTolerance': _getRiskTolerance(finalTick),
      'policySensitivity': _getPolicySensitivity(finalTick),
    };
  }

  String _getAdaptationSpeed(TickSummary tick) {
    final avgScore = _calculateOverallAverage(tick.averageRewardScore);
    if (avgScore > 0.3) return 'FAST';
    if (avgScore > 0) return 'MODERATE';
    return 'SLOW';
  }

  String _getRiskTolerance(TickSummary tick) {
    final variance = _calculateScoreVariance(tick.agentActions.map((a) => a.rewardScore).toList());
    if (variance < 0.1) return 'LOW';
    if (variance < 0.3) return 'MODERATE';
    return 'HIGH';
  }

  String _getPolicySensitivity(TickSummary tick) {
    final extremeScores = tick.agentActions.where((a) => a.rewardScore.abs() > 0.5).length;
    final totalAgents = tick.agentActions.length;
    final ratio = totalAgents > 0 ? extremeScores / totalAgents : 0;
    
    if (ratio > 0.3) return 'HIGH';
    if (ratio > 0.1) return 'MODERATE';
    return 'LOW';
  }

  double _calculateScoreVariance(List<double> scores) {
    if (scores.isEmpty) return 0.0;
    final mean = scores.reduce((a, b) => a + b) / scores.length;
    final variance = scores.map((score) => (score - mean) * (score - mean)).reduce((a, b) => a + b) / scores.length;
    return variance;
  }

  Widget _buildAnomalyAnalysis(List<Anomaly> anomalies) {
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
          Row(
            children: [
              const Icon(Icons.warning, size: 16, color: AppTheme.accentRed),
              const SizedBox(width: 8),
              const Text(
                'ANOMALY ANALYSIS',
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentRed,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${anomalies.length} detected',
                  style: const TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          if (anomalies.isEmpty)
            const Center(
              child: Text(
                'No anomalies detected - policy performing within expected parameters',
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
            )
          else ...[
            // Anomaly severity breakdown
            _buildAnomalySeverityBreakdown(anomalies),
            const SizedBox(height: 16),
            
            // Individual anomaly cards
            Container(
              height: 200,
              child: ListView.builder(
                itemCount: anomalies.length,
                itemBuilder: (context, index) => _buildAnomalyCard(anomalies[index], index + 1),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStabilityAnalysis(List<double> history) {
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: Text(
            'No stability data available',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 11,
              color: AppTheme.textMuted,
            ),
          ),
        ),
      );
    }

    final stabilityMetrics = _calculateStabilityMetrics(history);
    
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
              Icon(Icons.analytics, size: 16, color: AppTheme.accentCyan),
              SizedBox(width: 8),
              Text(
                'STABILITY ANALYSIS',
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
          
          // Stability metrics grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildStabilityMetricCard('Volatility', '${stabilityMetrics['volatility']}%', 
                stabilityMetrics['volatilityColor']),
              _buildStabilityMetricCard('Trend', stabilityMetrics['trend'], 
                stabilityMetrics['trendColor']),
              _buildStabilityMetricCard('Consistency', '${stabilityMetrics['consistency']}%', 
                stabilityMetrics['consistencyColor']),
              _buildStabilityMetricCard('Recovery', stabilityMetrics['recovery'], 
                stabilityMetrics['recoveryColor']),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Stability insights
          _buildStabilityInsights(stabilityMetrics),
        ],
      ),
    );
  }

  Widget _buildAnomalySeverityBreakdown(List<Anomaly> anomalies) {
    final severityCounts = <String, int>{};
    for (final anomaly in anomalies) {
      final severity = _getAnomalySeverity(anomaly);
      severityCounts[severity] = (severityCounts[severity] ?? 0) + 1;
    }
    
    return Row(
      children: [
        Expanded(
          child: _buildSeverityCard('Critical', severityCounts['Critical'] ?? 0, AppTheme.accentRed),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSeverityCard('High', severityCounts['High'] ?? 0, AppTheme.accentAmber),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSeverityCard('Medium', severityCounts['Medium'] ?? 0, AppTheme.accentCyan),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSeverityCard('Low', severityCounts['Low'] ?? 0, AppTheme.accentGreen),
        ),
      ],
    );
  }

  Widget _buildSeverityCard(String severity, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            severity,
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 9,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
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

  Widget _buildAnomalyCard(Anomaly anomaly, int index) {
    final severity = _getAnomalySeverity(anomaly);
    final color = _getSeverityColor(severity);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'A$index',
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                severity,
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                'Tick N/A', // Since Anomaly doesn't have tickNumber
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 9,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${anomaly.type}: ${anomaly.reason}', // Use type and reason instead of description
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 10,
              color: AppTheme.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStabilityMetricCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 9,
              color: AppTheme.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStabilityInsights(Map<String, dynamic> metrics) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STABILITY INSIGHTS',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          ...metrics['insights'].map<Widget>((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: AppTheme.accentCyan)),
                Expanded(
                  child: Text(
                    insight,
                    style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      color: AppTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  // Helper methods for anomaly and stability analysis
  String _getAnomalySeverity(Anomaly anomaly) {
    // Simple severity classification based on type and reason keywords
    final type = anomaly.type.toLowerCase();
    final reason = anomaly.reason.toLowerCase();
    
    if (type.contains('critical') || reason.contains('critical') || 
        reason.contains('severe') || reason.contains('crisis')) {
      return 'Critical';
    } else if (type.contains('high') || reason.contains('high') || 
               reason.contains('significant') || reason.contains('major')) {
      return 'High';
    } else if (type.contains('moderate') || reason.contains('moderate') || 
               reason.contains('medium')) {
      return 'Medium';
    }
    return 'Low';
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'Critical': return AppTheme.accentRed;
      case 'High': return AppTheme.accentAmber;
      case 'Medium': return AppTheme.accentCyan;
      default: return AppTheme.accentGreen;
    }
  }

  Map<String, dynamic> _calculateStabilityMetrics(List<double> history) {
    final variance = _calculateScoreVariance(history);
    final volatility = (variance * 100).round();
    
    // Calculate trend
    final firstHalf = history.take(history.length ~/ 2).toList();
    final secondHalf = history.skip(history.length ~/ 2).toList();
    final firstAvg = firstHalf.isEmpty ? 0.0 : firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.isEmpty ? 0.0 : secondHalf.reduce((a, b) => a + b) / secondHalf.length;
    
    String trend;
    Color trendColor;
    if (secondAvg > firstAvg + 5) {
      trend = 'RISING';
      trendColor = AppTheme.accentGreen;
    } else if (secondAvg < firstAvg - 5) {
      trend = 'FALLING';
      trendColor = AppTheme.accentRed;
    } else {
      trend = 'STABLE';
      trendColor = AppTheme.accentCyan;
    }
    
    // Calculate consistency (inverse of volatility)
    final consistency = (100 - volatility).clamp(0, 100);
    
    // Generate insights
    final insights = <String>[];
    if (volatility > 30) {
      insights.add('High volatility indicates policy instability or external shocks');
    }
    if (trend == 'RISING') {
      insights.add('Positive trend suggests policy is gaining effectiveness over time');
    } else if (trend == 'FALLING') {
      insights.add('Declining trend may indicate policy fatigue or unintended consequences');
    }
    if (consistency > 70) {
      insights.add('High consistency indicates predictable policy outcomes');
    }
    
    return {
      'volatility': volatility,
      'volatilityColor': volatility > 30 ? AppTheme.accentRed : AppTheme.accentGreen,
      'trend': trend,
      'trendColor': trendColor,
      'consistency': consistency,
      'consistencyColor': consistency > 70 ? AppTheme.accentGreen : AppTheme.accentAmber,
      'recovery': _getRecoveryRate(history),
      'recoveryColor': AppTheme.accentCyan,
      'insights': insights.isEmpty ? ['Stability metrics within normal parameters'] : insights,
    };
  }

  Widget _buildStabilityChart(List<double> history) {
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: Text(
            'No stability data available',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 11,
              color: AppTheme.textMuted,
            ),
          ),
        ),
      );
    }

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
              Icon(Icons.show_chart, size: 16, color: AppTheme.accentCyan),
              SizedBox(width: 8),
              Text(
                'STABILITY PROGRESSION',
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
          
          // Chart visualization
          Container(
            height: 200,
            child: CustomPaint(
              painter: StabilityChartPainter(history),
              size: Size.infinite,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Chart statistics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildChartStat('Initial', history.first.toStringAsFixed(1), AppTheme.accentAmber),
              _buildChartStat('Final', history.last.toStringAsFixed(1), 
                history.last >= history.first ? AppTheme.accentGreen : AppTheme.accentRed),
              _buildChartStat('Peak', _getMaxValue(history).toStringAsFixed(1), AppTheme.accentGreen),
              _buildChartStat('Trough', _getMinValue(history).toStringAsFixed(1), AppTheme.accentRed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTickByTickAnalysis(List<TickSummary> ticks) {
    if (ticks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: Text(
            'No tick data available',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 11,
              color: AppTheme.textMuted,
            ),
          ),
        ),
      );
    }

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
              Icon(Icons.timeline, size: 16, color: AppTheme.accentCyan),
              SizedBox(width: 8),
              Text(
                'TICK-BY-TICK ANALYSIS',
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
          
          // Timeline entries
          Container(
            height: 300,
            child: ListView.builder(
              itemCount: ticks.length,
              itemBuilder: (context, index) {
                final tick = ticks[index];
                final isLast = index == ticks.length - 1;
                return _buildTimelineEntry(tick, index + 1, isLast);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendAnalysis(List<TickSummary> ticks) {
    if (ticks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: Text(
            'No trend data available',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 11,
              color: AppTheme.textMuted,
            ),
          ),
        ),
      );
    }

    final trends = _analyzeTrends(ticks);
    
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
              Icon(Icons.trending_up, size: 16, color: AppTheme.accentCyan),
              SizedBox(width: 8),
              Text(
                'TREND ANALYSIS',
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
          
          // Trend cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2,
            children: [
              _buildTrendCard('Overall Direction', trends['direction'], trends['directionColor']),
              _buildTrendCard('Volatility Level', trends['volatility'], trends['volatilityColor']),
              _buildTrendCard('Recovery Rate', trends['recovery'], trends['recoveryColor']),
              _buildTrendCard('Momentum', trends['momentum'], trends['momentumColor']),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Key insights
          _buildTrendInsights(trends),
        ],
      ),
    );
  }

  Widget _buildChartStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 9,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineEntry(TickSummary tick, int tickNumber, bool isLast) {
    final avgScore = _calculateOverallAverage(tick.averageRewardScore);
    final color = avgScore >= 0 ? AppTheme.accentGreen : AppTheme.accentRed;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color, width: 2),
                ),
                child: Center(
                  child: Text(
                    '$tickNumber',
                    style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: AppTheme.border,
                ),
            ],
          ),
          
          const SizedBox(width: 12),
          
          // Tick details
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Month $tickNumber',
                        style: const TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Avg Score: ${avgScore.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${tick.agentActions.length} agents active • ${tick.averageRewardScore.length} demographics',
                    style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 9,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 10,
              color: AppTheme.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendInsights(Map<String, dynamic> trends) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'KEY INSIGHTS',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          ...trends['insights'].map<Widget>((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: AppTheme.accentCyan)),
                Expanded(
                  child: Text(
                    insight,
                    style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      color: AppTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  // Helper methods for trend analysis
  double _getMaxValue(List<double> values) {
    return values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
  }

  double _getMinValue(List<double> values) {
    return values.isEmpty ? 0.0 : values.reduce((a, b) => a < b ? a : b);
  }

  Map<String, dynamic> _analyzeTrends(List<TickSummary> ticks) {
    final scores = ticks.map((tick) => _calculateOverallAverage(tick.averageRewardScore)).toList();
    
    // Calculate trend direction
    final firstHalf = scores.take(scores.length ~/ 2).toList();
    final secondHalf = scores.skip(scores.length ~/ 2).toList();
    final firstAvg = firstHalf.isEmpty ? 0.0 : firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.isEmpty ? 0.0 : secondHalf.reduce((a, b) => a + b) / secondHalf.length;
    
    String direction;
    Color directionColor;
    if (secondAvg > firstAvg + 0.1) {
      direction = 'IMPROVING';
      directionColor = AppTheme.accentGreen;
    } else if (secondAvg < firstAvg - 0.1) {
      direction = 'DECLINING';
      directionColor = AppTheme.accentRed;
    } else {
      direction = 'STABLE';
      directionColor = AppTheme.accentCyan;
    }
    
    // Calculate volatility
    final variance = _calculateScoreVariance(scores);
    String volatility;
    Color volatilityColor;
    if (variance > 0.3) {
      volatility = 'HIGH';
      volatilityColor = AppTheme.accentRed;
    } else if (variance > 0.1) {
      volatility = 'MODERATE';
      volatilityColor = AppTheme.accentAmber;
    } else {
      volatility = 'LOW';
      volatilityColor = AppTheme.accentGreen;
    }
    
    // Generate insights
    final insights = <String>[];
    if (direction == 'IMPROVING') {
      insights.add('Policy shows positive long-term impact on citizen welfare');
    } else if (direction == 'DECLINING') {
      insights.add('Policy may need adjustment to prevent further deterioration');
    }
    
    if (volatility == 'HIGH') {
      insights.add('High volatility suggests policy instability or external shocks');
    }
    
    if (scores.isNotEmpty && scores.last > 0.5) {
      insights.add('Final stability score indicates successful policy implementation');
    }
    
    return {
      'direction': direction,
      'directionColor': directionColor,
      'volatility': volatility,
      'volatilityColor': volatilityColor,
      'recovery': _getRecoveryRate(scores),
      'recoveryColor': AppTheme.accentCyan,
      'momentum': _getMomentum(scores),
      'momentumColor': AppTheme.accentAmber,
      'insights': insights.isEmpty ? ['No significant patterns detected'] : insights,
    };
  }

  String _getRecoveryRate(List<double> scores) {
    if (scores.length < 3) return 'N/A';
    
    final minIndex = scores.indexOf(_getMinValue(scores));
    final recoveryScores = scores.skip(minIndex).toList();
    
    if (recoveryScores.length < 2) return 'N/A';
    
    final recoverySlope = (recoveryScores.last - recoveryScores.first) / recoveryScores.length;
    
    if (recoverySlope > 0.1) return 'FAST';
    if (recoverySlope > 0.05) return 'MODERATE';
    return 'SLOW';
  }

  String _getMomentum(List<double> scores) {
    if (scores.length < 3) return 'N/A';
    
    final recent = scores.takeLast(3).toList();
    final trend = recent.last - recent.first;
    
    if (trend > 0.1) return 'POSITIVE';
    if (trend < -0.1) return 'NEGATIVE';
    return 'NEUTRAL';
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
          const Row(
            children: [
              Icon(Icons.psychology, size: 16, color: AppTheme.accentPurple),
              SizedBox(width: 8),
              Text(
                'AI POLICY RECOMMENDATIONS',
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
          
          // AI Recommendation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.accentPurple.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.accentPurple.withValues(alpha: 0.2)),
            ),
            child: Text(
              result.aiPolicyRecommendation,
              style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 12,
                color: AppTheme.textPrimary,
                height: 1.6,
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Strategic Recommendations
          _buildStrategicRecommendations(result),
        ],
      ),
    );
  }

  Widget _buildRiskAssessment(SimulateResponse result, SimulationState state) {
    final risks = _analyzeRisks(result, state);
    
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
              Icon(Icons.security, size: 16, color: AppTheme.accentRed),
              SizedBox(width: 8),
              Text(
                'RISK ASSESSMENT',
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
          const SizedBox(height: 20),
          
          // Risk matrix
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildRiskCard('Political Risk', risks['political'], risks['politicalColor']),
              _buildRiskCard('Economic Risk', risks['economic'], risks['economicColor']),
              _buildRiskCard('Social Risk', risks['social'], risks['socialColor']),
              _buildRiskCard('Implementation Risk', risks['implementation'], risks['implementationColor']),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Risk mitigation strategies
          _buildRiskMitigation(risks),
        ],
      ),
    );
  }

  Widget _buildImplementationGuidance(SimulateResponse result) {
    final guidance = _generateImplementationGuidance(result);
    
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
              Icon(Icons.construction, size: 16, color: AppTheme.accentGreen),
              SizedBox(width: 8),
              Text(
                'IMPLEMENTATION GUIDANCE',
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentGreen,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Implementation phases
          ...guidance['phases'].asMap().entries.map((entry) => 
            _buildImplementationPhase(entry.key + 1, entry.value)
          ).toList(),
          
          const SizedBox(height: 20),
          
          // Success metrics
          _buildSuccessMetrics(guidance['metrics']),
        ],
      ),
    );
  }

  Widget _buildStrategicRecommendations(SimulateResponse result) {
    final recommendations = _generateStrategicRecommendations(result);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STRATEGIC RECOMMENDATIONS',
          style: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        
        ...recommendations.map((rec) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: rec['color'].withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: rec['color'].withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(rec['icon'], size: 14, color: rec['color']),
                  const SizedBox(width: 8),
                  Text(
                    rec['title'],
                    style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: rec['color'],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                rec['description'],
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 10,
                  color: AppTheme.textPrimary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildRiskCard(String title, String level, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 10,
              color: AppTheme.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            level,
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRiskMitigation(Map<String, dynamic> risks) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MITIGATION STRATEGIES',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          ...risks['mitigations'].map<Widget>((mitigation) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: AppTheme.accentGreen)),
                Expanded(
                  child: Text(
                    mitigation,
                    style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      color: AppTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildImplementationPhase(int phaseNumber, Map<String, dynamic> phase) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentGreen),
                ),
                child: Center(
                  child: Text(
                    '$phaseNumber',
                    style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                phase['title'],
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                phase['duration'],
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 9,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            phase['description'],
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 10,
              color: AppTheme.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: phase['actions'].map<Widget>((action) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                action,
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 8,
                  color: AppTheme.accentCyan,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMetrics(List<Map<String, dynamic>> metrics) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SUCCESS METRICS',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          ...metrics.map((metric) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    metric['name'],
                    style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    metric['target'],
                    style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: metric['color'],
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  // Helper methods for recommendations
  List<Map<String, dynamic>> _generateStrategicRecommendations(SimulateResponse result) {
    final recommendations = <Map<String, dynamic>>[];
    
    // Based on sentiment shift
    if (result.macroSummary.overallSentimentShift > 0.1) {
      recommendations.add({
        'title': 'Accelerate Implementation',
        'description': 'Strong positive sentiment indicates policy acceptance. Consider expanding scope or accelerating timeline.',
        'icon': Icons.speed,
        'color': AppTheme.accentGreen,
      });
    } else if (result.macroSummary.overallSentimentShift < -0.1) {
      recommendations.add({
        'title': 'Policy Adjustment Required',
        'description': 'Negative sentiment suggests need for policy refinement or additional support measures.',
        'icon': Icons.tune,
        'color': AppTheme.accentRed,
      });
    }
    
    // Based on inequality
    if (result.macroSummary.inequalityDelta > 0.05) {
      recommendations.add({
        'title': 'Address Inequality Concerns',
        'description': 'Policy may be increasing inequality. Consider targeted support for vulnerable groups.',
        'icon': Icons.balance,
        'color': AppTheme.accentAmber,
      });
    }
    
    // Based on anomalies
    if (result.anomalies.length > 3) {
      recommendations.add({
        'title': 'Enhance Monitoring Systems',
        'description': 'High anomaly count suggests need for better monitoring and early warning systems.',
        'icon': Icons.monitor,
        'color': AppTheme.accentCyan,
      });
    }
    
    // Default recommendation
    if (recommendations.isEmpty) {
      recommendations.add({
        'title': 'Maintain Current Course',
        'description': 'Policy appears to be performing within expected parameters. Continue monitoring.',
        'icon': Icons.check_circle,
        'color': AppTheme.accentGreen,
      });
    }
    
    return recommendations;
  }

  Map<String, dynamic> _analyzeRisks(SimulateResponse result, SimulationState state) {
    // Calculate risk levels based on simulation results
    final politicalRisk = result.anomalies.length > 2 ? 'HIGH' : 'MODERATE';
    final economicRisk = result.macroSummary.inequalityDelta > 0.1 ? 'HIGH' : 'LOW';
    final socialRisk = result.macroSummary.overallSentimentShift < -0.05 ? 'HIGH' : 'MODERATE';
    final implementationRisk = state.ticks.length < 6 ? 'HIGH' : 'LOW';
    
    return {
      'political': politicalRisk,
      'politicalColor': politicalRisk == 'HIGH' ? AppTheme.accentRed : AppTheme.accentAmber,
      'economic': economicRisk,
      'economicColor': economicRisk == 'HIGH' ? AppTheme.accentRed : AppTheme.accentGreen,
      'social': socialRisk,
      'socialColor': socialRisk == 'HIGH' ? AppTheme.accentRed : AppTheme.accentAmber,
      'implementation': implementationRisk,
      'implementationColor': implementationRisk == 'HIGH' ? AppTheme.accentRed : AppTheme.accentGreen,
      'mitigations': [
        'Establish stakeholder engagement protocols',
        'Implement phased rollout approach',
        'Create feedback mechanisms for continuous improvement',
        'Develop contingency plans for adverse scenarios',
        'Ensure adequate resource allocation and training',
      ],
    };
  }

  Map<String, dynamic> _generateImplementationGuidance(SimulateResponse result) {
    return {
      'phases': [
        {
          'title': 'Preparation Phase',
          'duration': '1-2 months',
          'description': 'Establish governance structure, stakeholder alignment, and resource allocation.',
          'actions': ['Stakeholder mapping', 'Resource planning', 'Risk assessment', 'Communication strategy'],
        },
        {
          'title': 'Pilot Implementation',
          'duration': '3-6 months',
          'description': 'Limited rollout to test assumptions and gather initial feedback.',
          'actions': ['Pilot selection', 'Baseline measurement', 'Monitoring setup', 'Feedback collection'],
        },
        {
          'title': 'Full Deployment',
          'duration': '6-12 months',
          'description': 'Scale implementation based on pilot learnings and established processes.',
          'actions': ['Phased rollout', 'Training programs', 'System integration', 'Performance tracking'],
        },
        {
          'title': 'Optimization',
          'duration': 'Ongoing',
          'description': 'Continuous improvement based on performance data and stakeholder feedback.',
          'actions': ['Performance review', 'Process refinement', 'Stakeholder feedback', 'Policy adjustment'],
        },
      ],
      'metrics': [
        {'name': 'Citizen Satisfaction', 'target': '>75%', 'color': AppTheme.accentGreen},
        {'name': 'Implementation Timeline', 'target': 'On schedule', 'color': AppTheme.accentCyan},
        {'name': 'Budget Adherence', 'target': '±5%', 'color': AppTheme.accentAmber},
        {'name': 'Anomaly Rate', 'target': '<3 per month', 'color': AppTheme.accentRed},
      ],
    };
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