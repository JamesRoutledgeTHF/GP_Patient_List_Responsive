"""Exercise practice registration SQL and the LSOA-only IMD source.

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


class PracticeSourceTests(unittest.TestCase):
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
        practice = "Demography.No_Of_Patients_Regd_At_GP_Practice_Single_Age1"
        self.db.execute(f"CREATE TABLE {practice} (GP_Practice_Code TEXT, "
                        "Effective_Snapshot_Date TEXT, Sex TEXT, Age TEXT, Size REAL)")
        practice_rows = [("P1", "2024-07-01", "FEMALE", "5", 150),
                         ("P1", "2024-07-01", "MALE", "6", 70),
                         ("P2", "2024-07-01", "FEMALE", "25", 80),
                         ("P2", "2024-07-01", "MALE", "26", 60),
                         (None, "2024-07-01", "FEMALE", "35", 40),
                         ("P1", "2024-10-01", "MALE", "6", 31),
                         ("P1", "2025-01-01", "FEMALE", "5", 999)]
        self.db.executemany(f"INSERT INTO {practice} VALUES (?,?,?,?,?)", practice_rows)
        ons = "Demography.ONS_Population_Estimates_For_LSOAs_By_Year_Of_Age1"
        self.db.execute(f"CREATE TABLE {ons} (Area_Code TEXT, Effective_Snapshot_Date TEXT, Size REAL)")
        self.db.executemany(f"INSERT INTO {ons} VALUES (?,?,?)", [
            ("E01000001", "2024-07-01", 100), ("E01000001", "2024-07-01", 30),
            ("E01000002", "2024-07-01", 60), ("W01000001", "2024-07-01", 999),
            ("E01000001", "2024-08-01", 999), ("E01000001", "2025-07-01", 999)])

    def tearDown(self):
        self.db.close()

    def test_national_uses_complete_practice_source(self):
        self.assertEqual(self.db.execute(query_for("national_registered")).fetchall(),
                         [("2024-07-01", 400), ("2024-10-01", 31)])

    def test_snapshot_groups_practices_and_retains_lsoa_for_imd(self):
        practices = dict(self.db.execute(query_for("practice_registered_snapshot")).fetchall())
        self.assertEqual(practices, {"P1": 220, "P2": 140})
        self.assertEqual(400 - sum(practices.values()), 40)
        unfiltered = self.db.execute(query_for("lsoa_registered_july")).fetchall()
        self.assertEqual(sum(row[2] for row in unfiltered), 285)
        english = sum(row[2] for row in unfiltered
                      if row[0] is not None and row[0].startswith("E01"))
        self.assertEqual(english, 200)

    def test_local_population_sources_and_coverage_fields(self):
        self.assertIn("practice_registered_snapshot", LOADER + REPORT)
        self.assertNotIn("lsoa_registered_sex_time_series", LOADER + REPORT)
        for name in ("practice_region_registered", "practice_icb_registered"):
            self.assertIn(name, REPORT)
        self.assertNotIn("lsoa_region_registered", REPORT)
        self.assertNotIn("lsoa_icb_registered", REPORT)
        self.assertRegex(REPORT, r"sex_comparison <- full_join\(\s*practice_registered_demographic_time_series")
        self.assertIn("sex_snapshot <- sex_comparison", REPORT)
        self.assertIn("imd_snapshot <- imd_july", REPORT)
        fields = set(re.findall(r"registration_coverage\$(\w+)", REPORT))
        helper = (ROOT / "12_Summarise_Registration_Coverage.R").read_text()
        for field in fields:
            self.assertRegex(helper, rf"\b{field}\s*=")

    def test_every_chart_has_embedded_source_label_and_reference_order(self):
        chunks = re.findall(r"^```\{r\s+([^,}\s]+)[^\n]*\}\n(.*?)^```", REPORT, re.M | re.S)
        charts = [(name, code) for name, code in chunks
                  if "label_chart(" in code and name != "setup"]
        self.assertEqual(len(charts), 22)
        for name, code in charts:
            source = "LSOA-level registrations" if name in {"imd-snapshot-chart", "region-snapshot-chart", "icb-snapshot-chart"} else "Practice-level registrations"
            self.assertIn('"' + source + '"', code, name)
            if "patients-per-gp" in name:
                self.assertIn("practice-level workforce", code)
            if "payment" in name and "per-resident" not in name:
                self.assertIn("practice-level annual payment", code)
        names = [name for name, _ in charts]
        self.assertLess(names.index("icb-fixed-total-payment-chart"),
                        names.index("national-payment-loss-chart"))
        self.assertNotIn("patients-per-gp-region-percentage-difference", names)
        self.assertNotRegex(REPORT, r'label = payment_currency\([^\n]+,\s*\n\s*colour = "(?:Registered|ONS)')
        self.assertIn('colour = "grey20"', REPORT)
        self.assertNotIn("select(-Registered, -Raw_Difference, -Pct_Difference)", REPORT)
        self.assertIn("imd_trend_chart(\"Registered patients\"", REPORT)
        self.assertIn("imd_trend_chart(\"ONS population estimate\"", REPORT)

    def test_july_history_queries_filter_residence_and_dates(self):
        query = query_for("lsoa_registered_history")
        query = query.replace("MONTH(Effective_Snapshot_Date)",
                              "CAST(strftime('%m', Effective_Snapshot_Date) AS INTEGER)")
        self.assertEqual(self.db.execute(query).fetchall(),
                         [("E01000001", "2024-07-01", 150),
                          ("E01000002", "2024-07-01", 50)])
        ons_query = query_for("lsoa_ons_history").replace("MONTH(Effective_Snapshot_Date)",
            "CAST(strftime('%m', Effective_Snapshot_Date) AS INTEGER)")
        self.assertEqual(self.db.execute(ons_query).fetchall(),
                         [("E01000001", "2024-07-01", 130),
                          ("E01000002", "2024-07-01", 60)])


if __name__ == "__main__":
    unittest.main()
