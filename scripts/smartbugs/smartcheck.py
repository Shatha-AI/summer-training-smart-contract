import pandas as pd
import subprocess

df = pd.read_csv("dataset/selected_contracts.csv")

results = []

for _, row in df.iterrows():

    contract = row["contract"]

    process = subprocess.run(
        ["smartcheck", contract],
        capture_output=True,
        text=True
    )

    results.append({
        "contract": contract,
        "category": row["category"],
        "output": process.stdout
    })

pd.DataFrame(results).to_csv(
    "results/smartcheck_results.csv",
    index=False
)