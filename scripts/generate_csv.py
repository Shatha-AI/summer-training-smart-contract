from pathlib import Path
import pandas as pd

base = Path("dataset/selected_contracts")

rows = []

for category in base.iterdir():
    if category.is_dir():
        for contract in category.glob("*.sol"):
            rows.append({
                "contract": str(contract),
                "category": category.name
            })

df = pd.DataFrame(rows)

df.to_csv("dataset/selected_contracts.csv", index=False)

print("CSV created successfully!")