
import re
import pandas as pd
from pathlib import Path


FINDINGS_FILE = "findings_validation (1).csv"
CONSENSUS_THRESHOLD = 3

CATEGORY_ALIASES = {
    "arithmetic_issues": "arithmetic",
    "unchecked_return_values_for_low_level_calls": "unchecked_low_level_calls",
}


def normalize_category(value: str) -> str:

    if pd.isna(value):
        return value
    normalized = str(value).strip().lower()
    normalized = normalized.replace("-", " ")
    normalized = re.sub(r"\s+", "_", normalized)
    return CATEGORY_ALIASES.get(normalized, normalized)


def load_findings_and_ground_truth(path: str) -> pd.DataFrame:

    df = pd.read_csv(path)
    df["contract"] = df["contract"].str.lower()
    df["detected_category"] = df["detected_category"].apply(normalize_category)

    if "ground_truth_category" in df.columns:
        print("'ground_truth_category'")

        df = df.rename(columns={"ground_truth_category": "actual_category"})
        df["actual_category"] = df["actual_category"].apply(normalize_category)
        return df
    else:
        
        print("⚠️ The column 'ground_truth_category' does not exist. The category will be extracted from the folder name.")
        def extract_from_path(contract_path: str) -> str:
            p = Path(contract_path)
            return p.parent.name.lower()
        df["actual_category"] = df["contract"].apply(extract_from_path)
        return df


def build_binary_detection_matrix(findings, all_contracts, all_categories, all_tools):

    detected_pairs = findings[["tool", "contract", "detected_category"]].drop_duplicates()
    matrices = {}
    for tool in all_tools:
        sub = detected_pairs[detected_pairs["tool"] == tool]
        mat = pd.DataFrame(0, index=all_contracts, columns=all_categories)
        for _, row in sub.iterrows():
            if row["contract"] in mat.index and row["detected_category"] in mat.columns:
                mat.loc[row["contract"], row["detected_category"]] = 1
        matrices[tool] = mat
    return matrices


def build_consensus_matrix(matrices, all_contracts, all_categories, all_tools, threshold=CONSENSUS_THRESHOLD):

    votes = pd.DataFrame(0, index=all_contracts, columns=all_categories)
    for tool in all_tools:
        votes = votes.add(matrices[tool], fill_value=0)

    consensus_mat = (votes >= threshold).astype(int)
    return consensus_mat, votes


def precision_recall_f1_accuracy(tp, fp, fn, tn):
    precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
    recall = tp / (tp + fn) if (tp + fn) > 0 else 0.0
    f1 = (2 * precision * recall / (precision + recall)) if (precision + recall) > 0 else 0.0
    accuracy = (tp + tn) / (tp + fp + fn + tn) if (tp + fp + fn + tn) > 0 else 0.0
    return precision, recall, f1, accuracy


def compute_per_tool_category_metrics(matrices, ground_truth, all_categories, total_contracts):
    rows = []
    for tool, mat in matrices.items():
        for category in all_categories:
            is_positive = (ground_truth == category)
            detected = mat[category] == 1
            tp = int((is_positive & detected).sum())
            fn = int((is_positive & ~detected).sum())
            fp = int((~is_positive & detected).sum())
            tn = total_contracts - tp - fn - fp
            precision, recall, f1, accuracy = precision_recall_f1_accuracy(tp, fp, fn, tn)
            rows.append({
                "tool": tool,
                "category": category,
                "TP": tp, "FP": fp, "FN": fn, "TN": tn,
                "precision": round(precision, 3),
                "recall": round(recall, 3),
                "f1": round(f1, 3),
                "accuracy": round(accuracy, 3),
            })
    return pd.DataFrame(rows)


def compute_tool_summary(per_category_df):
    summary_rows = []
    for tool, g in per_category_df.groupby("tool"):
        macro_p = g["precision"].mean()
        macro_r = g["recall"].mean()
        macro_f1 = g["f1"].mean()
        macro_acc = g["accuracy"].mean()
        tp_sum, fp_sum, fn_sum, tn_sum = g["TP"].sum(), g["FP"].sum(), g["FN"].sum(), g["TN"].sum()
        micro_p, micro_r, micro_f1, micro_acc = precision_recall_f1_accuracy(tp_sum, fp_sum, fn_sum, tn_sum)
        summary_rows.append({
            "tool": tool,
            "category": "ALL_CATEGORIES (micro)",
            "TP": tp_sum, "FP": fp_sum, "FN": fn_sum, "TN": tn_sum,
            "precision": round(micro_p, 3),
            "recall": round(micro_r, 3),
            "f1": round(micro_f1, 3),
            "accuracy": round(micro_acc, 3),
        })
        summary_rows.append({
            "tool": tool,
            "category": "ALL_CATEGORIES (macro avg)",
            "TP": tp_sum, "FP": fp_sum, "FN": fn_sum, "TN": tn_sum,
            "precision": round(macro_p, 3),
            "recall": round(macro_r, 3),
            "f1": round(macro_f1, 3),
            "accuracy": round(macro_acc, 3),
        })
    return pd.DataFrame(summary_rows).sort_values(["tool", "category"])


def main():

    df = load_findings_and_ground_truth(FINDINGS_FILE)

    all_contracts = sorted(df["contract"].unique())
    all_tools = sorted(df["tool"].unique())
    all_categories = sorted(df["actual_category"].unique())
    total_contracts = len(all_contracts)

    ground_truth_series = df.drop_duplicates(subset=["contract", "actual_category"]).set_index("contract")["actual_category"]
    ground_truth_series = ground_truth_series[~ground_truth_series.index.duplicated(keep='first')]
    ground_truth = ground_truth_series.reindex(all_contracts)

    matrices = build_binary_detection_matrix(df, all_contracts, all_categories, all_tools)


    consensus_mat, votes_mat = build_consensus_matrix(
        matrices, all_contracts, all_categories, all_tools, threshold=CONSENSUS_THRESHOLD
    )

    per_category_df = compute_per_tool_category_metrics(matrices, ground_truth, all_categories, total_contracts)
    summary_df = compute_tool_summary(per_category_df)
    tool_metrics = summary_df[summary_df["category"] == "ALL_CATEGORIES (micro)"][
        ["tool", "TP", "FP", "FN", "TN", "precision", "recall", "f1", "accuracy"]
    ]


    consensus_per_category_df = compute_per_tool_category_metrics(
        {"consensus": consensus_mat}, ground_truth, all_categories, total_contracts
    )
    consensus_summary_df = compute_tool_summary(consensus_per_category_df)


    detection_frames = []
    for tool in all_tools:
        mat_out = matrices[tool].astype(bool).reset_index().rename(columns={"index": "contract"})
        mat_out.insert(0, "tool", tool)
        detection_frames.append(mat_out)

    detection_all = pd.concat(detection_frames, ignore_index=True)


    final_flat = detection_all.merge(tool_metrics, on="tool", how="left")

    output_path = "tools_results_accuracy(ByContract)_combined.csv"
    final_flat.to_csv(output_path, index=False, encoding="utf-8-sig")
    print(f" save in : {output_path}")
    print(final_flat.to_string(index=False))


    consensus_mat_out = consensus_mat.astype(bool).reset_index().rename(columns={"index": "contract"})
    consensus_mat_out.insert(0, "tool", "consensus")


    consensus_micro = consensus_summary_df[consensus_summary_df["category"] == "ALL_CATEGORIES (micro)"][
        ["tool", "TP", "FP", "FN", "TN", "precision", "recall", "f1", "accuracy"]
    ]


    consensus_flat = consensus_mat_out.merge(consensus_micro, on="tool", how="left")

    consensus_output_path = "tools_results_accuracy(Consensus)_combined.csv"
    consensus_flat.to_csv(consensus_output_path, index=False, encoding="utf-8-sig")
    print(f" save in : {consensus_output_path}")
    print(consensus_flat.to_string(index=False))

    return final_flat, consensus_flat


if __name__ == "__main__":
    main()