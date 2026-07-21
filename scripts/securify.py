print("script started")
import os
import csv
import subprocess
import re

# ==========================
# Configuration
# ==========================

HOST_ROOT = r"C:\Users\LN\Documents\summer-training-smart-contract"

DATASET_DIR = os.path.join(HOST_ROOT, "dataset", "smartbugs")

OUTPUT_DIR = os.path.join(HOST_ROOT, "results")
os.makedirs(OUTPUT_DIR, exist_ok=True)

OUTPUT_CSV = os.path.join(
    OUTPUT_DIR,
    "securify_results_check.csv"
)

DOCKER_IMAGE = "securify:latest"

# ==========================
# CSV
# ==========================

csv_file = open(
    OUTPUT_CSV,
    "w",
    newline="",
    encoding="utf-8"
)

writer = csv.writer(csv_file)

writer.writerow([
    "contract",
    "tool",
    "rule",
    "category",
    "severity",
    "status",
    "description"
])

# ==========================
# Regex
# ==========================

pattern = re.compile(
    r"Severity:\s*(.*?)\n"
    r"Pattern:\s*(.*?)\n"
    r"Description:\s*(.*?)\n"
    r"Type:\s*(.*?)\n",
    re.DOTALL
)

# ==========================
# Scan Contracts
# ==========================

count = 0

for root, _, files in os.walk(DATASET_DIR):

    category = os.path.basename(root)

    for file in files:

        if not file.endswith(".sol"):
            continue

        count += 1

        host_path = os.path.join(root, file)

        docker_path = host_path.replace(HOST_ROOT, "/src")
        docker_path = docker_path.replace("\\", "/")

        print(f"[{count}] {file}")

        cmd = [
            "docker",
            "run",
            "--rm",
            "-v",
            f"{HOST_ROOT}:/src",
            DOCKER_IMAGE,
            docker_path
        ]

        try:

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=300
            )

            output = result.stdout + result.stderr

        except Exception as e:

            writer.writerow([
                file,
                "Securify 2.0",
                "",
                category,
                "",
                "ERROR",
                str(e)
            ])

            continue

        matches = pattern.findall(output)

        if not matches:

            writer.writerow([
                file,
                "Securify 2.0",
                "",
                category,
                "",
                "NO_RESULT",
                output[:300]
            ])

            continue

        for severity, rule, description, status in matches:

            writer.writerow([
                file,
                "Securify 2.0",
                rule.strip(),
                category,
                severity.strip(),
                status.strip(),
                description.replace("\n", " ").strip()
            ])

csv_file.close()

print("\n================================")
print("Finished.")
print("CSV saved to:")
print(OUTPUT_CSV)
