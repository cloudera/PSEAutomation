import re
import glob

files = glob.glob("queries/*.sql")

for file in files:
    with open(file, "r") as f:
        sql = f.read()

    original_sql = sql

    # --------------------------------------------------
    # 1. Backticks → double quotes
    # --------------------------------------------------
    sql = sql.replace("`", '"')

    # --------------------------------------------------
    # 2. Fix interval addition
    # --------------------------------------------------
    sql = re.sub(
        r"\(\s*(.*?)\s*\)\s*\+\s*interval\s+(\d+)\s+days",
        r"date_add('day', \2, \1)",
        sql,
        flags=re.IGNORECASE
    )

    # --------------------------------------------------
    # 3. Fix interval subtraction
    # --------------------------------------------------
    sql = re.sub(
        r"\(\s*(.*?)\s*\)\s*-\s*interval\s+(\d+)\s+days",
        r"date_add('day', -\2, \1)",
        sql,
        flags=re.IGNORECASE
    )

    # --------------------------------------------------
    # 4. Convert 'YYYY-MM-DD' → DATE 'YYYY-MM-DD'
    # --------------------------------------------------
    sql = re.sub(
        r"(?<!DATE )'(\d{4}-\d{2}-\d{2})'",
        r"DATE '\1'",
        sql
    )

    # --------------------------------------------------
    # 5. FIX: cast(DATE 'YYYY-MM-DD')  ❌ invalid in Trino
    #     → DATE 'YYYY-MM-DD'
    # --------------------------------------------------
    sql = re.sub(
        r"cast\s*\(\s*DATE\s*'(\d{4}-\d{2}-\d{2})'\s*\)",
        r"DATE '\1'",
        sql,
        flags=re.IGNORECASE
    )

    # --------------------------------------------------
    # 6. FIX: DATE 'xxx' as date → DATE 'xxx'
    # --------------------------------------------------
    sql = re.sub(
        r"DATE\s*'(\d{4}-\d{2}-\d{2})'\s*as\s*date",
        r"DATE '\1'",
        sql,
        flags=re.IGNORECASE
    )

    # --------------------------------------------------
    # 7. Fix broken castdate_add typo
    # --------------------------------------------------
    sql = sql.replace("castdate_add", "date_add")

    # --------------------------------------------------
    # 8. Fix malformed date_add parentheses
    # --------------------------------------------------
    sql = re.sub(
        r"date_add\('day',\s*(\d+),\s*\(\s*DATE\s*'(\d{4}-\d{2}-\d{2})'\s*\)\)",
        r"date_add('day', \1, DATE '\2')",
        sql,
        flags=re.IGNORECASE
    )

    # --------------------------------------------------
    # 9. Fix BETWEEN corruption patterns
    # --------------------------------------------------
    sql = re.sub(
        r"between\s+date_add\('day',\s*(\d+),\s*DATE\s*'(\d{4}-\d{2}-\d{2})'\)\s+and\s+DATE\s*'\2'",
        r"between DATE '\2' and date_add('day', \1, DATE '\2')",
        sql,
        flags=re.IGNORECASE
    )

    # --------------------------------------------------
    # 10. Fix grouping() ORDER BY issue safely
    # --------------------------------------------------
    if "grouping(" in sql.lower():
        sql = re.sub(
            r"ORDER BY\s+.*",
            "ORDER BY 1,2,3",
            sql,
            flags=re.IGNORECASE
        )

    # --------------------------------------------------
    # 11. SAFETY FIX (IMPORTANT):
    # Prevent broken cast(DATE '...') cases
    # --------------------------------------------------
    sql = re.sub(
        r"cast\s*\(\s*DATE\s*'(\d{4}-\d{2}-\d{2})'\s*\)",
        r"DATE '\1'",
        sql,
        flags=re.IGNORECASE
    )

    # --------------------------------------------------
    # Write back only if changed
    # --------------------------------------------------
    if sql != original_sql:
        with open(file, "w") as f:
            f.write(sql)
        print(f"✅ Updated: {file}")
    else:
        print(f"➖ No change: {file}")

print("\n🎯 All queries converted safely for Trino!")
