from pathlib import Path
import pandas as pd
import subprocess

df = pd.read_csv("dataset/selected_contracts.csv")

results = []

for _, row in df.iterrows():

    contract_path = Path(row["contract"])  
    category = row["category"]

    result = subprocess.run(
        ["slither", str(contract_path)],    
        capture_output=True,
        text=True
    )

    results.append({
        "contract": str(contract_path),
        "category": category,
        "slither_output": result.stdout
    })

pd.DataFrame(results).to_csv(
    "results/slither_results.csv",
    index=False
)