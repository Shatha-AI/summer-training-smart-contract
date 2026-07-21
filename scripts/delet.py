import pandas as pd

df = pd.read_csv("results/slither_results_clean.csv")

df = df.rename(columns={
    "Contract": "contract",
    "Vulnerability Type": "rule"
})

df.to_csv("results/slither_results_clean.csv", index=False)