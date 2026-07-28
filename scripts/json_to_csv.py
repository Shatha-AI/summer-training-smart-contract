import json
import pandas as pd

with open("results/smartBugs_results/ConFuzzius.json", "r", encoding="utf-8") as f:
    data = json.load(f)

rows = []

for issue in data["findings"]:

    rows.append({
        "contract": issue.get("contract", ""),
        "contract_name": issue.get("contract_name", ""),
        "tool": issue.get("tool", ""),
        "rule": issue.get("rule", ""),
        "category": issue.get("category", ""),
        "swc": issue.get("swc", ""),
        "severity": issue.get("severity", ""),
        "line": issue.get("line", ""),
        "column": issue.get("column", ""),
        "code": issue.get("code", ""),
        "mode": issue.get("mode", "")
    })

df = pd.DataFrame(rows)

df.to_csv(
    "results/smartBugs_results/confuzzius_results.csv",
    index=False
)

print(df.head())
print(f"Total findings: {len(df)}")
print("Done!")
