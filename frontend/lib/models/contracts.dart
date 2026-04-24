// contracts.dart — Dart model classes for all API Contracts (Pre-A through E).
//
// Mirrors the Pydantic schemas in backend/schemas.py exactly so that
// JSON serialisation/deserialisation is symmetric.

// ─── Contract Pre-A ──────────────────────────────────────────────────────────

/// Contract Pre-A: request body for POST /validate-policy
class ValidatePolicyRequest {
  final String rawPolicyText;

  const ValidatePolicyRequest({required this.rawPolicyText});

  Map<String, dynamic> toJson() => {'raw_policy_text': rawPolicyText};
}

// ─── EnvironmentBlueprint (nested in Contract Pre-B) ─────────────────────────

/// A single AI-generated Dynamic Sublayer (3–5 per policy).
class BlueprintSublayer {
  final String name;
  final String parentKnob;
  final String impactType; // 'expense' | 'multiplier' | 'income'
  final double baselineValue;
  final double policyValue;
  final String unit;

  const BlueprintSublayer({
    required this.name,
    required this.parentKnob,
    required this.impactType,
    required this.baselineValue,
    required this.policyValue,
    required this.unit,
  });

  factory BlueprintSublayer.fromJson(Map<String, dynamic> json) =>
      BlueprintSublayer(
        name: json['name'] as String,
        parentKnob: json['parent_knob'] as String,
        impactType: json['impact_type'] as String,
        baselineValue: (json['baseline_value'] as num).toDouble(),
        policyValue: (json['policy_value'] as num).toDouble(),
        unit: json['unit'] as String,
      );

  /// Formatted delta string, e.g. "+RM0.50" or "-5%"
  String get deltaLabel {
    final delta = policyValue - baselineValue;
    final sign = delta >= 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(2)} $unit';
  }
}

/// The AI-Driven Environment Blueprint returned when a policy is feasible.
class EnvironmentBlueprint {
  final String policySummary;
  final List<BlueprintSublayer> dynamicSublayers;

  const EnvironmentBlueprint({
    required this.policySummary,
    required this.dynamicSublayers,
  });

  factory EnvironmentBlueprint.fromJson(Map<String, dynamic> json) =>
      EnvironmentBlueprint(
        policySummary: json['policy_summary'] as String,
        dynamicSublayers: (json['dynamic_sublayers'] as List<dynamic>)
            .map((e) => BlueprintSublayer.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ─── Contract Pre-B ──────────────────────────────────────────────────────────

/// Contract Pre-B: response from POST /validate-policy
/// Maps backend field `is_feasible` → Dart field `isValid` for UI consistency.
class ValidatePolicyResponse {
  final bool isValid;
  final String? rejectionReason;
  final List<String> refinedOptions;
  final List<String> suggestions;
  final EnvironmentBlueprint? environmentBlueprint;

  const ValidatePolicyResponse({
    required this.isValid,
    this.rejectionReason,
    this.refinedOptions = const [],
    this.suggestions = const [],
    this.environmentBlueprint,
  });

  factory ValidatePolicyResponse.fromJson(Map<String, dynamic> json) {
    final bpJson = json['environment_blueprint'] as Map<String, dynamic>?;
    return ValidatePolicyResponse(
      isValid: (json['is_feasible'] ?? json['is_valid']) as bool,
      rejectionReason: json['rejection_reason'] as String?,
      refinedOptions: (json['refined_options'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      suggestions: (json['suggestions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      environmentBlueprint:
          bpJson != null ? EnvironmentBlueprint.fromJson(bpJson) : null,
    );
  }
}

// ─── Contract A ──────────────────────────────────────────────────────────────

/// Optional manual overrides for the 8 Universal Knobs.
class KnobOverrides {
  final double? disposableIncomeDelta;
  final double? operationalExpenseIndex;
  final double? capitalAccessPressure;
  final double? systemicFriction;
  final double? socialEquityWeight;
  final double? systemicTrustBaseline;
  final double? futureMobilityIndex;
  final double? ecologicalPressure;

  const KnobOverrides({
    this.disposableIncomeDelta,
    this.operationalExpenseIndex,
    this.capitalAccessPressure,
    this.systemicFriction,
    this.socialEquityWeight,
    this.systemicTrustBaseline,
    this.futureMobilityIndex,
    this.ecologicalPressure,
  });

  Map<String, dynamic> toJson() => {
        if (disposableIncomeDelta != null)
          'disposable_income_delta': disposableIncomeDelta,
        if (operationalExpenseIndex != null)
          'operational_expense_index': operationalExpenseIndex,
        if (capitalAccessPressure != null)
          'capital_access_pressure': capitalAccessPressure,
        if (systemicFriction != null) 'systemic_friction': systemicFriction,
        if (socialEquityWeight != null)
          'social_equity_weight': socialEquityWeight,
        if (systemicTrustBaseline != null)
          'systemic_trust_baseline': systemicTrustBaseline,
        if (futureMobilityIndex != null)
          'future_mobility_index': futureMobilityIndex,
        if (ecologicalPressure != null)
          'ecological_pressure': ecologicalPressure,
      };
}

/// Contract A: request body for POST /simulate
class SimulateRequest {
  final String policyText;
  final int simulationTicks;
  final int agentCount;
  final KnobOverrides knobOverrides;

  const SimulateRequest({
    required this.policyText,
    this.simulationTicks = 4,
    this.agentCount = 5,
    this.knobOverrides = const KnobOverrides(),
  });

  Map<String, dynamic> toJson() => {
        'policy_text': policyText,
        'simulation_ticks': simulationTicks,
        'agent_count': agentCount,
        'knob_overrides': knobOverrides.toJson(),
      };
}

// ─── Contract D ──────────────────────────────────────────────────────────────

/// Contract D: a single agent's decision for one tick (as returned inside Contract E).
class AgentDecision {
  final String agentId;
  final String action;
  final double sentimentScore;
  final double financialHealthChange;
  final String internalMonologue;
  final bool isBreakingPoint;
  final double rewardScore;
  final String demographic;

  const AgentDecision({
    required this.agentId,
    required this.action,
    required this.sentimentScore,
    required this.financialHealthChange,
    required this.internalMonologue,
    required this.isBreakingPoint,
    this.rewardScore = 0.0,
    this.demographic = '',
  });

  factory AgentDecision.fromJson(Map<String, dynamic> json) {
    return AgentDecision(
      agentId: json['agent_id'] as String,
      action: json['action'] as String,
      sentimentScore: (json['sentiment_score'] as num).toDouble(),
      financialHealthChange:
          (json['financial_health_change'] as num).toDouble(),
      internalMonologue: json['internal_monologue'] as String? ?? '',
      isBreakingPoint: json['is_breaking_point'] as bool? ?? false,
      rewardScore: (json['reward_score'] as num?)?.toDouble() ?? 0.0,
      demographic: json['demographic'] as String? ?? '',
    );
  }
}

// ─── Contract E ──────────────────────────────────────────────────────────────

class SimulationMetadata {
  final String policy;
  final int totalTicks;

  const SimulationMetadata({required this.policy, required this.totalTicks});

  factory SimulationMetadata.fromJson(Map<String, dynamic> json) =>
      SimulationMetadata(
        policy: json['policy'] as String,
        totalTicks: json['total_ticks'] as int,
      );
}

class MacroSummary {
  final double overallSentimentShift;
  final double inequalityDelta;

  const MacroSummary(
      {required this.overallSentimentShift, required this.inequalityDelta});

  factory MacroSummary.fromJson(Map<String, dynamic> json) => MacroSummary(
        overallSentimentShift:
            (json['overall_sentiment_shift'] as num).toDouble(),
        inequalityDelta: (json['inequality_delta'] as num).toDouble(),
      );
}

class TickSummary {
  final int tickId;
  final double averageSentiment;
  final List<AgentDecision> agentActions;
  // ── MARL/RL enrichment ────────────────────────────────────────────────────
  /// Average reward score per demographic: {'B40': 0.42, 'M40': 0.61, 'T20': 0.78}
  final Map<String, double> averageRewardScore;
  /// Most common action summary per demographic: {'B40': '60% of B40 agents are cutting_expenses'}
  final Map<String, String> demoActionSummary;
  /// Overall reward stability score mapped to [0, 100]
  final double rewardStabilityScore;

  const TickSummary({
    required this.tickId,
    required this.averageSentiment,
    required this.agentActions,
    this.averageRewardScore = const {},
    this.demoActionSummary = const {},
    this.rewardStabilityScore = 50.0,
  });

  factory TickSummary.fromJson(Map<String, dynamic> json) {
    Map<String, double> rewardMap = {};
    final rawReward = json['average_reward_score'];
    if (rawReward is Map) {
      rawReward.forEach((k, v) {
        rewardMap[k.toString()] = (v as num).toDouble();
      });
    }

    Map<String, String> actionMap = {};
    final rawAction = json['demo_action_summary'];
    if (rawAction is Map) {
      rawAction.forEach((k, v) {
        actionMap[k.toString()] = v.toString();
      });
    }

    return TickSummary(
      tickId: json['tick_id'] as int,
      averageSentiment: (json['average_sentiment'] as num).toDouble(),
      agentActions: (json['agent_actions'] as List<dynamic>)
          .map((e) => AgentDecision.fromJson(e as Map<String, dynamic>))
          .toList(),
      averageRewardScore: rewardMap,
      demoActionSummary: actionMap,
      rewardStabilityScore:
          (json['reward_stability_score'] as num?)?.toDouble() ?? 50.0,
    );
  }
}

class Anomaly {
  final String type;
  final String agentId;
  final String demographic;
  final String reason;

  const Anomaly({
    required this.type,
    required this.agentId,
    required this.demographic,
    required this.reason,
  });

  factory Anomaly.fromJson(Map<String, dynamic> json) => Anomaly(
        type: json['type'] as String,
        agentId: json['agent_id'] as String,
        demographic: json['demographic'] as String,
        reason: json['reason'] as String,
      );
}

/// Contract E: full dashboard payload — the final SSE "complete" event.
class SimulateResponse {
  final SimulationMetadata simulationMetadata;
  final MacroSummary macroSummary;
  final List<TickSummary> timeline;
  final List<Anomaly> anomalies;
  final String aiPolicyRecommendation;

  const SimulateResponse({
    required this.simulationMetadata,
    required this.macroSummary,
    required this.timeline,
    required this.anomalies,
    required this.aiPolicyRecommendation,
  });

  factory SimulateResponse.fromJson(Map<String, dynamic> json) =>
      SimulateResponse(
        simulationMetadata: SimulationMetadata.fromJson(
            json['simulation_metadata'] as Map<String, dynamic>),
        macroSummary: MacroSummary.fromJson(
            json['macro_summary'] as Map<String, dynamic>),
        timeline: (json['timeline'] as List<dynamic>)
            .map((e) => TickSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        anomalies: (json['anomalies'] as List<dynamic>)
            .map((e) => Anomaly.fromJson(e as Map<String, dynamic>))
            .toList(),
        aiPolicyRecommendation: json['ai_policy_recommendation'] as String,
      );
}