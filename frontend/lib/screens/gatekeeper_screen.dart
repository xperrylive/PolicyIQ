// gatekeeper_screen.dart — PolicyIQ Gatekeeper (State-Driven Refactor)
//
// Changes:
// 1. 'Configure Knobs' → 'REVIEW ENVIRONMENT'
// 2. EnvironmentBlueprint sublayers displayed immediately after validation
// 3. 'View Analytics' removed until simulation is completed
// 4. All UI reacts to SimulationStatus enum

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/contracts.dart';
import '../services/api_client.dart';
import '../state/simulation_state.dart';

class GatekeeperScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigate;

  const GatekeeperScreen({super.key, this.onNavigate});

  @override
  State<GatekeeperScreen> createState() => _GatekeeperScreenState();
}

class _GatekeeperScreenState extends State<GatekeeperScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _pulseCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _pulseAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
      CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut),
    );
    _pulseCtrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _analyzeInput() async {
    if (_controller.text.isEmpty) return;
    final simState = context.read<SimulationState>();
    final client = context.read<ApiClient>();

    simState.policyText = _controller.text;
    simState.setValidating();

    try {
      final validation = await client.validatePolicy(_controller.text);

      if (!mounted) return;

      if (validation.isValid) {
        simState.setValidationSuccess(validation);
        _slideCtrl.forward(from: 0);
      } else {
        // CRITICAL FIX: Store the validation result BEFORE setting failed status
        // so that suggestions and refined_options are available in the UI
        simState.validationResult = validation;
        simState.setValidationFailed(
            validation.rejectionReason ?? 'Policy rejected');
        _slideCtrl.forward(from: 0);
      }
    } catch (e) {
      if (!mounted) return;
      simState.setValidationFailed('Validation error: $e');
    }
  }

  void _goToControlPanel() => widget.onNavigate?.call(1);

  Color _getStatusColor(SimulationStatus status) {
    switch (status) {
      case SimulationStatus.idle:
        return AppTheme.textMuted;
      case SimulationStatus.validating:
        return AppTheme.accentAmber;
      case SimulationStatus.readyToReview:
        return AppTheme.accentGreen;
      case SimulationStatus.simulating:
        return AppTheme.accentCyan;
      case SimulationStatus.completed:
        return AppTheme.accentGreen;
      case SimulationStatus.failed:
        return AppTheme.accentRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final simState = context.watch<SimulationState>();
    final statusColor = _getStatusColor(simState.status);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _buildHeader(simState, statusColor),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputSection(simState, statusColor),
                  const SizedBox(height: 32),
                  if (simState.status == SimulationStatus.failed)
                    SlideTransition(
                      position: _slideAnim,
                      child: _buildRejectionPanel(simState),
                    ),
                  if (simState.status == SimulationStatus.readyToReview)
                    SlideTransition(
                      position: _slideAnim,
                      child: _buildSuccessPanel(simState),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(SimulationState simState, Color statusColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accentCyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.policy, color: AppTheme.accentCyan, size: 20),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('POLICY INPUT',
                    style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                Text('Gatekeeper Validation System',
                    style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 12,
                        color: AppTheme.textMuted)),
              ],
            ),
          ),
          const Spacer(),
          _buildStatusBubble(_getStatusLabel(simState.status), statusColor),
        ],
      ),
    );
  }

  String _getStatusLabel(SimulationStatus status) {
    switch (status) {
      case SimulationStatus.idle:
        return 'IDLE';
      case SimulationStatus.validating:
        return 'VALIDATING';
      case SimulationStatus.readyToReview:
        return 'READY TO REVIEW';
      case SimulationStatus.simulating:
        return 'SIMULATING';
      case SimulationStatus.completed:
        return 'COMPLETED';
      case SimulationStatus.failed:
        return 'FAILED';
    }
  }

  Widget _buildStatusBubble(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 10,
              color: color,
              letterSpacing: 1,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildInputSection(SimulationState simState, Color statusColor) {
    final isValidating = simState.status == SimulationStatus.validating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('POLICY TEXT'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            maxLines: 6,
            style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 13,
                color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Enter Malaysian government policy text for simulation...',
              hintStyle: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 13,
                  color: AppTheme.textMuted),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (isValidating)
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, child) {
                  return Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppTheme.accentAmber.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Transform.scale(
                        scale: _pulseAnim.value,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: AppTheme.accentAmber, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(width: 12),
            Text(_getValidationMessage(simState.status),
                style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            ElevatedButton(
              onPressed: _controller.text.isNotEmpty && !isValidating
                  ? _analyzeInput
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: statusColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(isValidating ? 'ANALYZING...' : 'VALIDATE POLICY',
                  style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ),
          ],
        ),
      ],
    );
  }

  String _getValidationMessage(SimulationStatus status) {
    switch (status) {
      case SimulationStatus.idle:
        return 'Enter policy text to begin validation';
      case SimulationStatus.validating:
        return 'AI is analyzing your policy...';
      case SimulationStatus.readyToReview:
        return 'Policy is ready for environment review';
      case SimulationStatus.simulating:
        return 'Simulation in progress...';
      case SimulationStatus.completed:
        return 'Simulation completed';
      case SimulationStatus.failed:
        return 'Policy needs refinement';
    }
  }

  Widget _buildRejectionPanel(SimulationState simState) {
    final validation = simState.validationResult;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentRed.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning, size: 14, color: AppTheme.accentRed),
              SizedBox(width: 8),
              Text('POLICY REJECTED',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentRed)),
            ],
          ),
          const SizedBox(height: 12),
          Text(simState.validationError ?? 'Unknown error',
              style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 11,
                  color: AppTheme.textSecondary)),
          // REMOVED: refined_options section (redundant with suggestions)
          // Now only showing the clickable suggestion cards
          if (validation?.suggestions.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            _AdvisorSuggestions(
              suggestions: validation!.suggestions,
              onSuggestionTap: (suggestion) {
                setState(() {
                  _controller.text = suggestion;
                });
                _analyzeInput();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuccessPanel(SimulationState simState) {
    final blueprint = simState.environmentBlueprint;
    final validation = simState.validationResult;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.accentGreen.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 16),
              const SizedBox(width: 8),
              const Text('POLICY VALIDATED',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentGreen)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('READY FOR SIMULATION',
                    style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 10,
                        color: AppTheme.accentGreen,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (blueprint != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentCyan.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.2)),
              ),
              child: Text(blueprint.policySummary,
                  style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      height: 1.5)),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.layers, size: 12, color: AppTheme.accentCyan),
                SizedBox(width: 8),
                Text('ENVIRONMENT SUBLAYERS (AI PHYSICS)',
                    style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentCyan,
                        letterSpacing: 0.8)),
              ],
            ),
            const SizedBox(height: 8),
            ...blueprint.dynamicSublayers.map((sl) => _buildSublayerCard(sl)),
          ],
          if (validation?.suggestions.isNotEmpty == true) ...[
            const SizedBox(height: 20),
            _AdvisorSuggestions(
              suggestions: validation!.suggestions,
              onSuggestionTap: (suggestion) {
                setState(() {
                  _controller.text = suggestion;
                });
                _analyzeInput();
              },
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _goToControlPanel,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCyan,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('REVIEW ENVIRONMENT',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSublayerCard(BlueprintSublayer sl) {
    final impactColor = sl.impactType == 'income'
        ? AppTheme.accentGreen
        : sl.impactType == 'expense'
            ? AppTheme.accentRed
            : AppTheme.accentAmber;

    final delta = sl.policyValue - sl.baselineValue;
    final deltaStr = '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)} ${sl.unit}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 40,
            decoration: BoxDecoration(
              color: impactColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sl.name,
                    style: const TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text('↳ ${sl.parentKnob.replaceAll('_', ' ')}',
                    style: const TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 9,
                        color: AppTheme.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(deltaStr,
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: impactColor)),
              const SizedBox(height: 2),
              Text(
                  '${sl.baselineValue.toStringAsFixed(2)} → ${sl.policyValue.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 9,
                      color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color? color;

  const _SectionLabel(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color ?? AppTheme.textMuted,
            letterSpacing: 1));
  }
}

/// _AdvisorSuggestions — Displays strategic alternatives as clickable cards
class _AdvisorSuggestions extends StatelessWidget {
  final List<String> suggestions;
  final void Function(String) onSuggestionTap;

  const _AdvisorSuggestions({
    required this.suggestions,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.lightbulb_outline, size: 14, color: AppTheme.accentAmber),
            SizedBox(width: 8),
            Text('AI STRATEGIC ADVISOR',
                style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentAmber,
                    letterSpacing: 0.8)),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Click any suggestion to refine your policy automatically',
          style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 9,
              color: AppTheme.textMuted,
              fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,  // Increased from 140 to fit longer suggestions
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              return _SuggestionCard(
                suggestion: suggestions[index],
                index: index,
                onTap: () => onSuggestionTap(suggestions[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// _SuggestionCard — Individual suggestion card with lightbulb icon
class _SuggestionCard extends StatefulWidget {
  final String suggestion;
  final int index;
  final VoidCallback onTap;

  const _SuggestionCard({
    required this.suggestion,
    required this.index,
    required this.onTap,
  });

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 320,  // Increased from 280 to fit longer text
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppTheme.accentAmber.withValues(alpha: 0.08)
                : AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isHovered
                  ? AppTheme.accentAmber.withValues(alpha: 0.5)
                  : AppTheme.border,
              width: _isHovered ? 2 : 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: AppTheme.accentAmber.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.accentAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.lightbulb,
                        size: 16, color: AppTheme.accentAmber),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentAmber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text('OPTION ${widget.index + 1}',
                        style: const TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 9,
                            color: AppTheme.accentAmber,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  widget.suggestion,
                  style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                      height: 1.4),
                  // Removed maxLines and overflow to show full suggestion text
                  // The card will scroll if needed
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.touch_app,
                    size: 12,
                    color: _isHovered ? AppTheme.accentAmber : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Click to apply',
                    style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 8,
                        color:
                            _isHovered ? AppTheme.accentAmber : AppTheme.textMuted,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
