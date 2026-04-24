// simulation_state.dart — State-Driven Lifecycle Controller for PolicyIQ MARL
//
// This is the single source of truth for the simulation lifecycle.
// All UI components react to SimulationStatus changes.

import 'package:flutter/foundation.dart';
import '../models/contracts.dart';

// ─── SimulationStatus Enum ────────────────────────────────────────────────────

/// The 6 lifecycle states of a PolicyIQ simulation.
/// UI buttons and visibility are driven by this status.
enum SimulationStatus {
  /// No policy has been entered yet.
  idle,

  /// Policy is being validated by the Gatekeeper AI.
  validating,

  /// Policy is valid and EnvironmentBlueprint is ready for review.
  /// User must review the sublayers before proceeding.
  readyToReview,

  /// Simulation is actively running (SSE ticks streaming).
  simulating,

  /// Simulation has completed successfully.
  completed,

  /// Simulation or validation failed.
  failed,
}

// ─── SimulationState (ChangeNotifier) ─────────────────────────────────────────

/// Shared state for the entire PolicyIQ simulation UI.
/// Consumed by all screens via Provider.
class SimulationState extends ChangeNotifier {
  // ── Lifecycle Status ──────────────────────────────────────────────────────
  SimulationStatus _status = SimulationStatus.idle;
  SimulationStatus get status => _status;

  // ── Input State ───────────────────────────────────────────────────────────
  String policyText = '';
  int simulationTicks = 4;
  int agentCount = 50;
  KnobOverrides knobOverrides = const KnobOverrides();

  // ── Validation State ──────────────────────────────────────────────────────
  ValidatePolicyResponse? validationResult;
  String? validationError;

  /// True once the backend Gatekeeper has approved the policy.
  bool get isPolicyApproved => validationResult?.isValid == true;

  /// The EnvironmentBlueprint from the last successful validation.
  EnvironmentBlueprint? get environmentBlueprint =>
      validationResult?.environmentBlueprint;

  // ── Simulation State ──────────────────────────────────────────────────────
  List<TickSummary> ticks = [];
  SimulateResponse? finalResult;
  String? simulationError;

  /// Reward stability history for the live stress-test chart.
  List<double> rewardStabilityHistory = [];

  // ── Scenario Versioning (A/B Comparison) ──────────────────────────────────
  List<SavedScenario> savedScenarios = [];
  String? comparisonScenarioId;

  SavedScenario? get comparisonScenario => savedScenarios
      .where((s) => s.id == comparisonScenarioId)
      .firstOrNull;

  // ── Status Transitions ────────────────────────────────────────────────────

  void setValidating() {
    _status = SimulationStatus.validating;
    validationResult = null;
    validationError = null;
    notifyListeners();
  }

  void setValidationSuccess(ValidatePolicyResponse result) {
    try {
      validationResult = result;
      validationError = null;
      
      // Verify EnvironmentBlueprint can be accessed without errors
      if (result.isValid && result.environmentBlueprint != null) {
        final blueprint = result.environmentBlueprint!;
        print('[SIMULATION_STATE] EnvironmentBlueprint loaded successfully:');
        print('  - Policy Summary: ${blueprint.policySummary}');
        print('  - Sublayers: ${blueprint.dynamicSublayers.length}');
        
        // Auto-apply blueprint values to knob overrides
        _applyBlueprintToKnobs(blueprint);
      }
      
      _status = SimulationStatus.readyToReview;
      notifyListeners();
    } catch (e) {
      print('[SIMULATION_STATE] Error processing validation result: $e');
      validationError = 'Failed to parse validation response: $e';
      _status = SimulationStatus.failed;
      notifyListeners();
    }
  }

  /// Automatically apply EnvironmentBlueprint sublayer values to knob overrides
  void _applyBlueprintToKnobs(EnvironmentBlueprint blueprint) {
    print('[SIMULATION_STATE] Applying blueprint with ${blueprint.dynamicSublayers.length} sublayers');
    
    // Initialize a map to accumulate deltas per knob
    final Map<String, double> knobDeltas = {
      'disposable_income_delta': 0.0,
      'operational_expense_index': 0.0,
      'capital_access_pressure': 0.0,
      'systemic_friction': 0.0,
      'social_equity_weight': 0.0,
      'systemic_trust_baseline': 0.0,
      'future_mobility_index': 0.0,
      'ecological_resource_pressure': 0.0,
    };

    // Mapping function to normalize parent knob names
    String normalizeKnobName(String parentKnob) {
      final normalized = parentKnob.toLowerCase().replaceAll(' ', '_');
      
      // Handle various possible naming conventions
      if (normalized.contains('disposable') || normalized.contains('income')) {
        return 'disposable_income_delta';
      } else if (normalized.contains('operational') || normalized.contains('expense')) {
        return 'operational_expense_index';
      } else if (normalized.contains('capital') || normalized.contains('access')) {
        return 'capital_access_pressure';
      } else if (normalized.contains('friction') || normalized.contains('systemic_friction')) {
        return 'systemic_friction';
      } else if (normalized.contains('equity') || normalized.contains('social')) {
        return 'social_equity_weight';
      } else if (normalized.contains('trust') || normalized.contains('baseline')) {
        return 'systemic_trust_baseline';
      } else if (normalized.contains('mobility') || normalized.contains('future')) {
        return 'future_mobility_index';
      } else if (normalized.contains('ecological') || normalized.contains('resource') || normalized.contains('pressure')) {
        return 'ecological_resource_pressure';
      }
      
      // If no match, return the original (will be logged as unknown)
      return normalized;
    }

    // Aggregate sublayer deltas by parent knob
    for (final sublayer in blueprint.dynamicSublayers) {
      final delta = sublayer.policyValue - sublayer.baselineValue;
      final normalizedKnob = normalizeKnobName(sublayer.parentKnob);
      
      print('[SIMULATION_STATE] Sublayer ${sublayer.name}: ${sublayer.baselineValue} -> ${sublayer.policyValue} (Δ${delta}) -> ${sublayer.parentKnob} (normalized: $normalizedKnob)');
      
      if (knobDeltas.containsKey(normalizedKnob)) {
        knobDeltas[normalizedKnob] = knobDeltas[normalizedKnob]! + delta;
      } else {
        print('[SIMULATION_STATE] WARNING: Unknown parent knob: ${sublayer.parentKnob} (normalized: $normalizedKnob)');
        // Try to assign to a reasonable default based on impact type
        if (sublayer.impactType == 'income') {
          knobDeltas['disposable_income_delta'] = knobDeltas['disposable_income_delta']! + delta;
        } else if (sublayer.impactType == 'expense') {
          knobDeltas['operational_expense_index'] = knobDeltas['operational_expense_index']! + delta;
        }
      }
    }

    print('[SIMULATION_STATE] Knob deltas: $knobDeltas');

    // Use a more aggressive scaling factor to make values visible
    const scalingFactor = 0.1; // Increased back to 0.1 for more visible changes
    
    knobOverrides = KnobOverrides(
      disposableIncomeDelta: (knobDeltas['disposable_income_delta']! * scalingFactor).clamp(-1.0, 1.0),
      operationalExpenseIndex: (knobDeltas['operational_expense_index']! * scalingFactor).clamp(-1.0, 1.0),
      capitalAccessPressure: (knobDeltas['capital_access_pressure']! * scalingFactor).clamp(-1.0, 1.0),
      systemicFriction: (knobDeltas['systemic_friction']! * scalingFactor).clamp(-1.0, 1.0),
      socialEquityWeight: (knobDeltas['social_equity_weight']! * scalingFactor).clamp(-1.0, 1.0),
      systemicTrustBaseline: (knobDeltas['systemic_trust_baseline']! * scalingFactor).clamp(-1.0, 1.0),
      futureMobilityIndex: (knobDeltas['future_mobility_index']! * scalingFactor).clamp(-1.0, 1.0),
      ecologicalPressure: (knobDeltas['ecological_resource_pressure']! * scalingFactor).clamp(-1.0, 1.0),
    );
    
    print('[SIMULATION_STATE] Final knobOverrides: $knobOverrides');
  }

  void setValidationFailed(String error) {
    validationError = error;
    _status = SimulationStatus.failed;
    // Note: validationResult should already be set by the caller
    // so that suggestions and refined_options are available in the UI
    notifyListeners();
  }

  void setSimulating() {
    _status = SimulationStatus.simulating;
    
    // Clean slate: wipe all previous simulation data
    ticks = [];
    finalResult = null;
    simulationError = null;
    rewardStabilityHistory = [];
    
    // Clear any comparison scenario to avoid confusion
    comparisonScenarioId = null;
    
    notifyListeners();
  }

  void addTick(TickSummary tick) {
    ticks = [...ticks, tick];
    rewardStabilityHistory = [
      ...rewardStabilityHistory,
      tick.rewardStabilityScore
    ];
    
    // Immediate unrest detection - trigger red glow if stability < 40
    if (tick.rewardStabilityScore < 40) {
      // This will trigger UI updates immediately via notifyListeners
      // The dashboard will detect this in the build method and show red glow
    }
    
    notifyListeners();
  }

  void setSimulationComplete(SimulateResponse result) {
    finalResult = result;
    _status = SimulationStatus.completed;
    notifyListeners();
  }

  void setSimulationFailed(String error) {
    simulationError = error;
    _status = SimulationStatus.failed;
    notifyListeners();
  }

  void resetToIdle() {
    _status = SimulationStatus.idle;
    policyText = '';
    validationResult = null;
    validationError = null;
    ticks = [];
    finalResult = null;
    simulationError = null;
    rewardStabilityHistory = [];
    notifyListeners();
  }

  // ── Scenario Management ───────────────────────────────────────────────────

  SavedScenario? saveCurrentScenario(String label) {
    if (finalResult == null) return null;
    final scenario = SavedScenario(
      id: 'scenario_${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      policyText: policyText,
      stabilityHistory: List.unmodifiable(rewardStabilityHistory),
      result: finalResult!,
      savedAt: DateTime.now(),
    );
    savedScenarios = [...savedScenarios, scenario];
    notifyListeners();
    return scenario;
  }

  void refineFromScenario(SavedScenario scenario) {
    policyText = scenario.policyText;
    _status = SimulationStatus.idle;
    ticks = [];
    finalResult = null;
    simulationError = null;
    rewardStabilityHistory = [];
    notifyListeners();
  }

  void setComparisonScenario(String? scenarioId) {
    comparisonScenarioId = scenarioId;
    notifyListeners();
  }

  void updateKnobOverrides(KnobOverrides overrides) {
    knobOverrides = overrides;
    notifyListeners();
  }
}

// ─── SavedScenario ────────────────────────────────────────────────────────────

class SavedScenario {
  final String id;
  final String label;
  final String policyText;
  final List<double> stabilityHistory;
  final SimulateResponse result;
  final DateTime savedAt;

  const SavedScenario({
    required this.id,
    required this.label,
    required this.policyText,
    required this.stabilityHistory,
    required this.result,
    required this.savedAt,
  });
}
