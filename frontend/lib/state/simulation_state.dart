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

  void setValidationFailed(String error) {
    validationError = error;
    _status = SimulationStatus.failed;
    // Note: validationResult should already be set by the caller
    // so that suggestions and refined_options are available in the UI
    notifyListeners();
  }

  void setSimulating() {
    _status = SimulationStatus.simulating;
    ticks = [];
    finalResult = null;
    simulationError = null;
    rewardStabilityHistory = [];
    notifyListeners();
  }

  void addTick(TickSummary tick) {
    ticks = [...ticks, tick];
    rewardStabilityHistory = [
      ...rewardStabilityHistory,
      tick.rewardStabilityScore
    ];
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
