import pandas as pd
from pathlib import Path

# ملفات النتائج لكل أداة
files = {
    "smartcheck": "results/smartcheck_results_filtered.csv",
    "solhint": "results/solhint_results_filtered.csv",
    "slither": "results/slither_results_clean.csv",
}

# ملف الـ Mapping
mapping = pd.read_csv("dataset/rule_mapping.csv")

all_results = []

for tool, file in files.items():

    path = Path(file)

    if not path.exists():
        print(f"Skipping {tool}: file not found")
        continue

    # قراءة الملف
    df = pd.read_csv(path)

    # توحيد أسماء الأعمدة الخاصة بـ Slither
    if tool == "slither":
        df = df.rename(columns={
            "Contract": "contract",
            "Vulnerability Type": "rule",
            "Severity": "severity"
        })

    # التأكد من وجود الأعمدة المطلوبة
    required = ["contract", "rule", "severity"]

    missing = [c for c in required if c not in df.columns]

    if missing:
        print(f"Skipping {tool}: missing columns {missing}")
        continue

    # إضافة اسم الأداة
    df["tool"] = tool

    # استخراج الـ Mapping الخاص بالأداة (فقط rule و category)
    tool_mapping = mapping[
        mapping["tool"] == tool
    ][["rule", "category"]]

    # دمج النتائج مع الـ Mapping
    df = df.merge(
        tool_mapping,
        on="rule",
        how="left"
    )

    # حذف النتائج التي ليس لها Mapping
    df = df.dropna(subset=["category"])

    # إزالة التكرارات
    df = df.drop_duplicates(
        subset=["contract", "tool", "rule"]
    )

    # الاحتفاظ بالأعمدة المهمة فقط
    df = df[
        [
            "contract",
            "tool",
            "rule",
            "category",
            "severity"
        ]
    ]

    all_results.append(df)

# دمج جميع الأدوات
if all_results:

    final_df = pd.concat(
        all_results,
        ignore_index=True
    )

    final_df.to_csv(
        "results/all_results.csv",
        index=False
    )

    print("Done!")
    print(f"Total findings: {len(final_df)}")

else:
    print("No results found.")