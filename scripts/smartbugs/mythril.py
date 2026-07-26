import pandas as pd
import subprocess

df = pd.read_csv("dataset/selected_contracts.csv")

results = []

for _, row in df.iterrows():

    contract = row["contract"]
    category = row["category"]

    process = subprocess.run(
        ["myth", "analyze", contract],
        capture_output=True,
        text=True
    )

    output = process.stdout if process.stdout else process.stderr

    results.append({
        "contract": contract,
        "category": category,
        "output": output
    })

pd.DataFrame(results).to_csv(
    "results/mythril_results.csv",
    index=False
)
