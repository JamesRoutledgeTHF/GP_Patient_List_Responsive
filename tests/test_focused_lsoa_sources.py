"""Exercise the new LSOA SQL on synthetic residence/sex records.

Uses SQLite for the portable aggregate queries, not SQL Server or an R render.
Also checks exported figure provenance and the reference report's chart order.
"""
from pathlib import Path
import re
import sqlite3
import unittest

ROOT = Path(__file__).resolve().parents[1]
LOADER = (ROOT / "08_Get_Focused_Patient_List_Data.R").read_text()
REPORT = (ROOT / "05_Patient_List_Focused.Rmd").read_text()


def query_for(name):
    pattern = r'^' + name + r' <- DBI::dbGetQuery\(\s*con,\s*glue::glue\("(.*?)"\)'
    query = re.search(pattern, LOADER, re.S | re.M).group(1)
    for variable, value in (("start_sql", "2024-01-01"),
                            ("end_sql", "2024-12-31"),
                            ("snapshot_sql", "2024-07-01")):
        query = query.replace("{" + variable + "}", value)
    return query


class LSOASourceTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        self.db.execute("ATTACH DATABASE ':memory:' AS Demography")
        table = "Demography.No_Of_Patients_Regd_At_GP_Practice_LSOA_2021_Level1"
        self.db.execute(f"CREATE TABLE {table} (LSOA_Code TEXT, "
                        "Effective_Snapshot_Date TEXT, Sex TEXT, Size REAL)")
        rows = [("E01000001", "2024-07-01", "FEMALE", 100),
                ("E01000001", "2024-07-01", "MALE", 50),
                ("E01000002", "2024-07-01", "FEMALE", 30),
                ("E01000002", "2024-07-01", "MALE", 20),
                ("W01000001", "2024-07-01", "FEMALE", 50),
                ("OTHER", "2024-07-01", "MALE", 25),
                (None, "2024-07-01", "FEMALE", 10),
                ("E01000001", "2024-10-01", "MALE", 31),
                ("E01000001", "2025-01-01", "FEMALE", 999)]
        self.db.executemany(f"INSERT INTO {table} VALUES (?,?,?,?)", rows)

    def tearDown(self):
        self.db.close()

    def test_national_excludes_wales_other_and_missing_residence(self):
        self.assertEqual(self.db.execute(query_for("national_registered")).fetchall(),
                         [("2024-07-01", 200), ("2024-10-01", 31)])

    def test_lsoa_sex_reconciles_to_national(self):
        rows = self.db.execute(query_for("lsoa_registered_sex_time_series")).fetchall()
        july = {sex: count for date, sex, count in rows if date == "2024-07-01"}
        self.assertEqual(july, {"Female": 130, "Male": 70})
        self.assertEqual(sum(july.values()), 200)
        unfiltered = self.db.execute(query_for("lsoa_registered_july")).fetchall()
        self.assertEqual(sum(row[2] for row in unfiltered), 285)

    def test_age_is_explicit_exception_and_local_denominators_are_lsoa(self):
        self.assertIn("practice_national_registered", LOADER)
        self.assertNotIn("practice_registered_snapshot", LOADER + REPORT)
        self.assertNotIn("practice_region_registered", REPORT)
        self.assertNotIn("practice_icb_registered", REPORT)
        for name in ("lsoa_region_registered", "lsoa_icb_registered"):
            self.assertIn(name, REPORT)
        self.assertIn("sex_snapshot <- sex_comparison", REPORT)
        fields = set(re.findall(r"registration_coverage\$(\w+)", REPORT))
        helper = (ROOT / "12_Summarise_Registration_Coverage.R").read_text()
        for field in fields:
            self.assertRegex(helper, rf"\b{field}\s*=")

    def test_every_chart_has_embedded_source_label_and_reference_order(self):
        chunks = re.findall(r"^```\{r\s+([^,}\s]+)[^\n]*\}\n(.*?)^```", REPORT, re.M | re.S)
        charts = [(name, code) for name, code in chunks
                  if "label_chart(" in code and name != "setup"]
        self.assertEqual(len(charts), 20)
        age_charts = {"age-time-series", "age-snapshot-chart", "age-sex-snapshot-chart"}
        for name, code in charts:
            source = "Practice-level registrations" if name in age_charts else "LSOA-level registrations"
            self.assertIn('"' + source + '"', code, name)
            if "patients-per-gp" in name:
                self.assertIn("practice-level workforce", code)
            if "payment" in name:
                self.assertIn("practice-level annual payment", code)
        names = [name for name, _ in charts]
        self.assertLess(names.index("icb-fixed-total-payment-chart"),
                        names.index("national-payment-loss-chart"))
        self.assertNotIn("patients-per-gp-region-percentage-difference", names)
        self.assertNotRegex(REPORT, r'label = payment_currency\([^\n]+,\s*\n\s*colour = "(?:Registered|ONS)')
        self.assertIn('colour = "grey20"', REPORT)


if __name__ == "__main__":
    unittest.main()
