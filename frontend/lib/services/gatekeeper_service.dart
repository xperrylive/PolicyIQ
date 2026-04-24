// gatekeeper_service.dart — Thin wrapper around ApiClient for policy validation.
//
// All validation is performed by the FastAPI backend (POST /validate-policy).
// No Gemini/Google API keys or URLs live here.

import '../models/contracts.dart';
import 'api_client.dart';

class GatekeeperService {
  final ApiClient _client;

  GatekeeperService({ApiClient? client}) : _client = client ?? ApiClient();

  /// Validates [policyText] via the backend Gatekeeper endpoint.
  ///
  /// Returns a [ValidatePolicyResponse] and updates [state] so the UI
  /// (e.g. 'Start Simulation' button) reacts to the approval status.
  Future<ValidatePolicyResponse> validatePolicy(
    String policyText,
    SimulationState state,
  ) async {
    state.setValidating(true);
    try {
      final result = await _client.validatePolicy(policyText);
      state.setValidationResult(result);
      return result;
    } catch (e) {
      state.setValidationResult(null, error: e.toString());
      rethrow;
    }
  }
}
