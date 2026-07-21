import os
import subprocess
import csv
import re

#  إذا تغير مكان الداتا
DATASET_DIR = r"C:\Users\LN\Documents\summer-training-smart-contract\dataset\smartbugs"

OUTPUT_CSV = r"C:\Users\LN\Documents\summer-training-smart-contract\results\securify_results_check.csv"

IMAGE = "securify:latest"

rows = []

for root, dirs, files in os.walk(DATASET_DIR):

    category = os.path.basename(root)

    for file in files:

        if not file.endswith(".sol"):
            continue

        contract_path = os.path.join(root, file)

        print("=" * 70)
        print("Analyzing:", file)

        docker_path = contract_path.replace("\\", "/")
        docker_path = docker_path.replace(
            "C:\Users\LN\Documents\summer-training-smart-contract",
            "\src"
        )

        command = [
            "docker",
            "run",
            "--rm",
            "-v",
            "C:\\Users\\LN\\Documents\\summer-training-smart-contract:\src",
            IMAGE,
            docker_path
        ]

        try:

            result = subprocess.run(
                command,
                capture_output=True,
                text=True,
                timeout=300
            )

            output = result.stdout + result.stderr

        except Exception as e:

            rows.append([
                file,
                "Securify 2.0",
                "",
                category,
                "",
                "ERROR",
                str(e)
            ])

            continue

        pattern = re.compile(
            r"Severity:\s*(.*?)\n"
            r"Pattern:\s*(.*?)\n"
            r"Description:\s*(.*?)\n"
            r"Type:\s*(.*?)\n",
            re.DOTALL
        )

        matches = pattern.findall(output)

        if len(matches) == 0:

            rows.append([
                file,
                "Securify 2.0",
                "",
                category,
                "",
                "NO_RESULT",
                output[:500]
            ])

        else:

            for severity, rule, description, status in matches:

                rows.append([
                    file,
                    "Securify 2.0",
                    rule.strip(),
                    category,
                    severity.strip(),
                    status.strip(),
                    description.replace("\n", " ").strip()
                ])

with open(
    OUTPUT_CSV,
    "w",
    newline="",
    encoding="utf-8"
) as f:

    writer = csv.writer(f)

    writer.writerow([
        "contract",
        "tool",
        "rule",
        "category",
        "severity",
        "status",
        "description"
    ])

    writer.writerows(rows)

print("\nFinished.")
print("Saved to:")
print(OUTPUT_CSV)
