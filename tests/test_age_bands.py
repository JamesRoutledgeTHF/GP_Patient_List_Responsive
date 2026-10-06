"""Check numeric age boundaries in the report SQL without a database.

SQLite executes the CASE expressions for valid integer ages; TRY_CAST is
replaced with CAST for these fixtures only. This is not a SQL Server test.
"""
import csv
from pathlib import Path
import re
import sqlite3
import unittest

ROOT = Path(__file__).resolve().parents[1]


class AgeBandTests(unittest.TestCase):
    def test_production_sql_boundaries(self):
        connection = sqlite3.connect(":memory:")
        for name in ("07_Get_LSOA_Data.R", "08_Get_Focused_Patient_List_Data.R"):
            text = (ROOT / name).read_text()
            cases = re.findall(r"CASE\s+WHEN Age = '95\+'[\s\S]*?\bEND", text)
            self.assertTrue(cases, name)
            for case in cases:
                numeric_case = case.replace("TRY_CAST", "CAST")
                for age in list(range(-1, 106)) + ["95+", None]:
                    expected = (
                        None if age is None or age == -1 else
                        "90+" if age == "95+" or age >= 90 else
                        f"{age // 10 * 10}-{age // 10 * 10 + 9}"
                    )
                    result = connection.execute(
                        f"SELECT {numeric_case} FROM (SELECT ? AS Age)", (age,)
                    ).fetchone()[0]
                    self.assertEqual(result, expected, (name, age))
        connection.close()

    def test_legacy_chart_mapping(self):
        text = (ROOT / "05_Patient_List_Responsive.Rmd").read_text()
        for lower in range(0, 90, 10):
            self.assertRegex(
                text,
                rf'Age_Group == "Age_{lower}_{lower + 9}"\s+~ "{lower}-{lower + 9}"',
            )
        self.assertRegex(text, r'Age_Group == "Age_90_plus"\s+~ "90\+"')
        self.assertNotRegex(text, r'"(?:0-10|11-20|21-30|81\+)"')

    def test_published_reference_reconciles(self):
        with (ROOT / "data/ons_mid2024_age_band_reference.csv").open() as file:
            rows = list(csv.DictReader(file))
        self.assertEqual(
            [r["Age_Band"] for r in rows],
            [f"{lower}-{lower + 9}" for lower in range(0, 90, 10)] + ["90+"],
        )
        for row in rows:
            self.assertEqual(int(row["England"]) + int(row["Wales"]),
                             int(row["England_and_Wales"]))
        self.assertEqual([int(rows[0][key]) for key in
                          ("England", "Wales", "England_and_Wales")],
                         [6473967, 321552, 6795519])
        self.assertEqual(sum(int(r["England"]) for r in rows), 58620101)
        self.assertEqual(sum(int(r["Wales"]) for r in rows), 3186581)


if __name__ == "__main__":
    unittest.main()
