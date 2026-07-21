import json
import pandas as pd

with open("results/solhint_full.json", "r", encoding="utf-8") as f:
    data = json.load(f)

rows = []

for contract, issues in data.items():

    for issue in issues:

        rows.append({
            "contract": contract,
            "rule": issue.get("ruleId", ""),
            "severity": issue.get("severity", ""),
            "message": issue.get("message", ""),
            "line": issue.get("line", "")
        })

df = pd.DataFrame(rows)

df.to_csv("results/solhint_results.csv", index=False)

print("Done!")