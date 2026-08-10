"""
Seed Supabase `facilities` table with Kenya Master Health Facility List (KMHFL).

Usage:
    1. Download the KMHFL CSV from https://kmhfl.health.go.ke
       (Look for "Export" or "Download facility list")
    2. Place the CSV in this directory as `kmhfl.csv`
    3. Set SUPABASE_URL and SUPABASE_SERVICE_KEY in ../.env
    4. Run: python seed_facilities.py

The script batches inserts for speed (~13 000 facilities).
"""

import csv
import os
import sys
import uuid
from datetime import datetime, timezone

from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

# ---------------------------------------------------------------------------
# Supabase init
# ---------------------------------------------------------------------------
URL = os.getenv("SUPABASE_URL")
KEY = os.getenv("SUPABASE_SERVICE_KEY")  # service_role key

if not URL or not KEY:
    print("ERROR: Set SUPABASE_URL and SUPABASE_SERVICE_KEY in .env")
    sys.exit(1)

supabase: Client = create_client(URL, KEY)

# ---------------------------------------------------------------------------
# Column mapping – KMHFL CSV column name → our facilities column
# Adjust these to match the actual CSV headers you downloaded.
# ---------------------------------------------------------------------------
KMHFL_COLUMNS = {
    "Facility Code": "kmhfl_code",
    "Facility Name": "name",
    "Official Name": "name",
    "County": "county",
    "Sub County": "sub_county",
    "Facility Type": "type_raw",
    "KEPH Level": "keph_level",
    "Owner": "owner_type",
    "Address": "address",
    "Phone Number": "phone",
    "Email": "email",
}


def normalize_type(raw: str) -> str:
    """Map KMHFL facility types → our simplified categories."""
    r = (raw or "").strip().lower().replace(" ", "_")
    if "hospital" in r:
        return "hospital"
    if "clinic" in r or "medical_centre" in r or "medical_center" in r:
        return "clinic"
    if any(w in r for w in ("health_centre", "health_center", "sub_district")):
        return "health_centre"
    if "dispensary" in r:
        return "dispensary"
    if "nursing" in r or "maternity" in r:
        return "nursing_home"
    if "pharmacy" in r or "chemist" in r:
        return "pharmacy"
    if "laboratory" in r or "lab" in r:
        return "laboratory"
    if "radiology" in r or "imaging" in r:
        return "imaging_centre"
    if "vct" in r or "hiv" in r:
        return "vct_centre"
    if "standalone" in r or "community" in r:
        return "community_unit"
    return "other"


def batch_insert(rows: list[dict]) -> int:
    """Insert a batch of facility rows. Returns count inserted."""
    if not rows:
        return 0
    result = supabase.table("facilities").upsert(rows, on_conflict="name,county").execute()
    return len(result.data) if result.data else 0


def main():
    csv_path = os.path.join(os.path.dirname(__file__), "kmhfl.csv")

    if not os.path.exists(csv_path):
        print(f"ERROR: kmhfl.csv not found at {csv_path}")
        print("Download it from https://kmhfl.health.go.ke and place it in the scripts/ folder.")
        sys.exit(1)

    print(f"Reading {csv_path} …")

    with open(csv_path, newline="", encoding="utf-8-sig") as f:
        # Sniff delimiter — KMHFL exports are sometimes tab-delimited
        sample = f.read(4096)
        f.seek(0)
        dialect = csv.Sniffer().sniff(sample, delimiters=",\t;")
        reader = csv.DictReader(f, dialect=dialect)

        print(f"  Detected columns: {reader.fieldnames}")

        batch: list[dict] = []
        total = 0
        skipped = 0
        BATCH_SIZE = 500
        now = datetime.now(timezone.utc).isoformat()

        for row_num, row in enumerate(reader, start=2):  # 1-based, skip header
            # Normalize column names (strip whitespace, lowercase for matching)
            norm = {k.strip().lower(): v.strip() if v else "" for k, v in row.items()}

            name = None
            for possible in ("facility name", "official name", "name", "facility_name"):
                val = norm.get(possible)
                if val:
                    name = val
                    break

            if not name:
                skipped += 1
                continue

            county = norm.get("county", "")
            sub_county = norm.get("sub county", norm.get("sub_county", ""))
            raw_type = norm.get("facility type", norm.get("type", ""))
            address = norm.get("address", norm.get("physical_address", ""))
            phone = norm.get("phone number", norm.get("phone", norm.get("mobile", "")))
            email = norm.get("email", norm.get("email_address", ""))

            batch.append({
                "id": str(uuid.uuid4()),
                "name": name,
                "type": normalize_type(raw_type),
                "county": county,
                "sub_county": sub_county,
                "address": address,
                "phone": phone[:50] if phone else None,
                "email": email[:100] if email else None,
                "created_at": now,
            })

            if len(batch) >= BATCH_SIZE:
                batch_insert(batch)
                total += len(batch)
                print(f"  Inserted {total} facilities …", end="\r")
                batch = []

        # Final batch
        if batch:
            batch_insert(batch)
            total += len(batch)

        print(f"\nDone. {total} facilities inserted, {skipped} rows skipped (no name).")


if __name__ == "__main__":
    main()
