import requests
import json

BASE_URL = "http://127.0.0.1:8000"

def test_validation():
    print("--- Testing Policy Validation ---")
    # Backend expects 'raw_policy_text'
    payload = {"raw_policy_text": "Give every citizen RM100,000 monthly"}
    response = requests.post(f"{BASE_URL}/validate-policy", json=payload)
    print(response.json())

def test_simulation():
    print("\n--- Testing Full Simulation ---")
    # Backend expects 'policy_text'
    payload = {
        "policy_text": "Increase petrol prices by RM0.50",
        "agents": [{"id": "agent_1", "tier": "B40", "occupation": "Rider"}]
    }
    # Using stream=True for SSE
    response = requests.post(f"{BASE_URL}/simulate", json=payload, stream=True)
    for line in response.iter_lines():
        if line:
            decoded_line = line.decode('utf-8')
            if decoded_line.startswith("data: "):
                try:
                    data = json.loads(decoded_line[6:])
                    # If it's a tick event, it contains agent_actions
                    if "agent_actions" in data:
                        print(f"\n--- Tick {data.get('tick_id')} ---")
                        for action in data["agent_actions"]:
                            print(f"Agent: {action['agent_id']} | Sentiment: {action['sentiment_score']:.2f} | Monologue: {action['internal_monologue'][:80]}...")
                    elif data.get("type") == "summary":
                        print(f"\n--- Summary ---\n{data.get('content')}")
                except Exception:
                    # Not JSON or other data
                    pass

if __name__ == "__main__":
    test_validation()
    test_simulation()