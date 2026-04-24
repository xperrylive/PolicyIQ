import json
import random
import os

os.makedirs("backend/ai_engine/agent_dna", exist_ok=True)

# Statistical Weighting (40% B40, 40% M40, 20% T20)
population_pool = (["B40"] * 20) + (["M40"] * 20) + (["T20"] * 10)
random.shuffle(population_pool)

occupations = {
    "B40": ["Gig Worker", "Rider", "Factory Worker", "Junior Clerk", "Unemployed"],
    "M40": ["Teacher", "Civil Servant", "Engineer", "Nurse", "Sales Manager"],
    "T20": ["SME Owner", "Doctor", "Senior Executive", "Consultant"]
}

locations = ["Urban KL", "Suburban Selangor", "Rural Sabah", "Penang", "Johor Bahru"]

agents = []
for i, tier in enumerate(population_pool):
    # DOSM Grounded Income Brackets (2024/2026 estimates)
    if tier == "B40":
        income = random.randint(2500, 4800)
        debt_ratio = random.uniform(0.4, 0.8) # B40 often has higher debt-to-income
    elif tier == "M40":
        income = random.randint(4850, 10950)
        debt_ratio = random.uniform(0.3, 0.6)
    else: # T20
        income = random.randint(11000, 35000)
        debt_ratio = random.uniform(0.1, 0.4)

    agents.append({
        "agent_id": f"AGT-{i+1:03}",
        "demographic": tier,
        "occupation": random.choice(occupations[tier]),
        "location": random.choice(locations),
        "monthly_income_rm": income,
        "disposable_buffer_rm": round(income * random.uniform(-0.05, 0.1), 2),
        "liquid_savings_rm": round(income * random.uniform(0.2, 5.0), 2),
        "debt_to_income_ratio": round(debt_ratio, 2),
        "dependents_count": random.randint(1, 6) if tier != "T20" else random.randint(0, 3)
    })

with open("backend/ai_engine/agent_dna/agents_master.json", "w") as f:
    json.dump(agents, f, indent=2)

print("Generated 50 Grounded Malaysian Profiles (40/40/20 Split).")