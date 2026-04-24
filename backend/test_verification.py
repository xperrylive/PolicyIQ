"""
test_verification.py — Economic Entity generation smoke test.

Run from inside the backend/ directory:
    cd backend
    python test_verification.py

Verifies that _synthetic_agents() produces correctly tier-differentiated
Economic Entity records (monthly_income_rm, digital_readiness_score, etc.)
for each B40 / M40 / T20 agent.
"""

try:
    from ai_engine.orchestrator import Orchestrator
except ImportError:
    from backend.ai_engine.orchestrator import Orchestrator

# ── Generate 5 synthetic Economic Entity agents ────────────────────────────────
agents = Orchestrator._synthetic_agents(count=5)

print("=" * 80)
print(f"{'ID':<10} {'Tier':<5} {'Income (RM)':>12} {'Savings (RM)':>13} "
      f"{'Buffer (RM)':>12} {'DTI':>6} {'Readiness':>10} {'Deps':>5}")
print("-" * 80)

for a in agents:
    print(
        f"{a['agent_id']:<10} "
        f"{a['demographic']:<5} "
        f"{a['monthly_income_rm']:>12,.0f} "
        f"{a['liquid_savings_rm']:>13,.0f} "
        f"{a['disposable_buffer_rm']:>12,.0f} "
        f"{a['debt_to_income_ratio']:>6.3f} "
        f"{a['digital_readiness_score']:>10.3f} "
        f"{a['dependents_count']:>5}"
    )

print("=" * 80)

# ── Detailed view of first agent ───────────────────────────────────────────────
first = agents[0]
print(f"\n-- Detailed profile: {first['agent_id']} ({first['demographic']}) --")
print(f"  Occupation    : {first['occupation']}")
print(f"  Location      : {first['location']}")
print(f"  Subsidy flags : {first['subsidy_flags']}")
print(f"  Sensitivity   : {first['sensitivity_matrix']}")

# ── Basic assertions ───────────────────────────────────────────────────────────
print("\n-- Assertions --")
tier_ranges = {
    "B40": (2000, 4849),
    "M40": (4850, 10959),
    "T20": (10960, 30000),
}
all_passed = True
for a in agents:
    tier = a["demographic"]
    lo, hi = tier_ranges[tier]
    income_ok = lo <= a["monthly_income_rm"] <= hi
    readiness_ok = 0.0 <= a["digital_readiness_score"] <= 1.0
    savings_ok = a["liquid_savings_rm"] >= 0
    status = "PASS" if (income_ok and readiness_ok and savings_ok) else "FAIL"
    if status == "FAIL":
        all_passed = False
    print(f"  [{status}] {a['agent_id']} ({tier}) — "
          f"income in range={income_ok}, readiness valid={readiness_ok}, savings>=0={savings_ok}")

print()
print("All assertions passed [OK]" if all_passed else "[FAIL] One or more assertions FAILED - check ranges above.")
