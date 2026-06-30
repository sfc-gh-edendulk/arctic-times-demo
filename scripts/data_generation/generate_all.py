"""
Arctic Times — Synthetic Data Generator

Generates all seed data for the demo:
  1. GA4 tracking events (batch_1 + batch_2 with schema evolution)
  2. GA4 events (VARIANT format for dot-notation demo)
  3. Subscribers (with PII for masking demo)

Output: JSON files in scripts/data_generation/output/
Load:   COPY INTO ... FROM @stage FILE_FORMAT=(TYPE='JSON')

Requirements: pip install -r requirements.txt
"""

import json
import os
import random
import uuid
from datetime import datetime, timedelta
from pathlib import Path

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

OUTPUT_DIR = Path(__file__).parent / "output"
NUM_GA4_EVENTS = 300_000
NUM_SUBSCRIBERS = 80_000
NUM_ARTICLES = 500
DAYS_BACK = 30

SECTIONS = [
    "Politique", "International", "Economie", "Culture",
    "Sciences", "Sport", "Planete", "Opinions", "Societe"
]
PUBLICATIONS = [
    "Arctic Times", "Courrier Polaire", "Telerama Nord",
    "La Vie Glaciale", "Arctic Times Diplomatique"
]
EVENT_TYPES = [
    "page_view", "scroll", "click", "session_start",
    "paywall_hit", "subscribe_click", "share"
]
BROWSERS = ["Chrome", "Safari", "Firefox", "Edge", "Samsung Internet"]
DEVICES = ["mobile", "desktop", "tablet"]
OS_LIST = ["iOS", "Android", "Windows", "macOS", "Linux"]
COUNTRIES = ["FR", "FR", "FR", "FR", "BE", "CH", "CA", "SN", "MA"]
FR_CITIES = ["Paris", "Lyon", "Marseille", "Toulouse", "Bordeaux", "Lille", "Nantes", "Strasbourg", "Nice", "Rennes"]
SOURCES = ["google", "direct", "facebook", "twitter", "newsletter", "apple_news"]
MEDIUMS = ["organic", "direct", "referral", "social", "email", "cpc"]
SUBSCRIPTION_TYPES = ["premium", "standard", "digital_only", "student"]
FIRST_NAMES = ["Jean", "Marie", "Pierre", "Sophie", "Laurent", "Claire", "Nicolas", "Isabelle", "Thomas", "Camille"]
LAST_NAMES = ["Martin", "Bernard", "Dubois", "Thomas", "Robert", "Richard", "Petit", "Durand", "Leroy", "Moreau"]

random.seed(42)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def random_timestamp(days_back=DAYS_BACK):
    base = datetime.now() - timedelta(days=days_back)
    offset = random.randint(0, days_back * 24 * 3600)
    return (base + timedelta(seconds=offset)).strftime("%Y-%m-%dT%H:%M:%SZ")


def random_article_id():
    return f"ART_{random.randint(1000, 9999)}"


# ---------------------------------------------------------------------------
# 1. GA4 Tracking Events (schema evolution demo)
# ---------------------------------------------------------------------------

def generate_ga4_tracking():
    """Generate GA4 events in two batches to demonstrate schema evolution."""
    batch_1_dir = OUTPUT_DIR / "ga4_stage" / "batch_1"
    batch_2_dir = OUTPUT_DIR / "ga4_stage" / "batch_2"
    batch_1_dir.mkdir(parents=True, exist_ok=True)
    batch_2_dir.mkdir(parents=True, exist_ok=True)

    split = int(NUM_GA4_EVENTS * 0.6)

    # Batch 1: standard schema
    batch_1 = []
    for _ in range(split):
        batch_1.append({
            "event_name": random.choice(EVENT_TYPES),
            "event_timestamp": random_timestamp(),
            "user_pseudo_id": str(uuid.uuid4())[:12],
            "article_id": random_article_id(),
            "section": random.choice(SECTIONS),
            "device_category": random.choice(DEVICES),
            "browser": random.choice(BROWSERS),
            "os": random.choice(OS_LIST),
            "country": random.choice(COUNTRIES),
            "city": random.choice(FR_CITIES),
            "traffic_source": random.choice(SOURCES),
            "traffic_medium": random.choice(MEDIUMS),
            "engagement_time_sec": random.randint(5, 600),
            "scroll_pct": random.randint(0, 100),
        })

    # Write batch 1 as chunked JSON files (~50K events each)
    chunk_size = 50_000
    for i in range(0, len(batch_1), chunk_size):
        chunk = batch_1[i:i + chunk_size]
        path = batch_1_dir / f"events_{i // chunk_size:03d}.json"
        with open(path, "w") as f:
            for event in chunk:
                f.write(json.dumps(event) + "\n")

    # Batch 2: adds consent_state, engagement_score, ab_test_variant
    batch_2 = []
    for _ in range(NUM_GA4_EVENTS - split):
        batch_2.append({
            "event_name": random.choice(EVENT_TYPES),
            "event_timestamp": random_timestamp(days_back=7),
            "user_pseudo_id": str(uuid.uuid4())[:12],
            "article_id": random_article_id(),
            "section": random.choice(SECTIONS),
            "device_category": random.choice(DEVICES),
            "browser": random.choice(BROWSERS),
            "os": random.choice(OS_LIST),
            "country": random.choice(COUNTRIES),
            "city": random.choice(FR_CITIES),
            "traffic_source": random.choice(SOURCES),
            "traffic_medium": random.choice(MEDIUMS),
            "engagement_time_sec": random.randint(5, 600),
            "scroll_pct": random.randint(0, 100),
            # NEW FIELDS (schema evolution)
            "consent_state": random.choice(["granted", "denied", "pending"]),
            "engagement_score": round(random.uniform(0, 100), 1),
            "ab_test_variant": random.choice(["control", "variant_a", "variant_b", None]),
        })

    for i in range(0, len(batch_2), chunk_size):
        chunk = batch_2[i:i + chunk_size]
        path = batch_2_dir / f"events_{i // chunk_size:03d}.json"
        with open(path, "w") as f:
            for event in chunk:
                f.write(json.dumps(event) + "\n")

    print(f"  GA4 batch_1: {split:,} events → {batch_1_dir}")
    print(f"  GA4 batch_2: {NUM_GA4_EVENTS - split:,} events → {batch_2_dir}")


# ---------------------------------------------------------------------------
# 2. GA4 Events (VARIANT format for dot-notation demo)
# ---------------------------------------------------------------------------

def generate_ga4_variant():
    """Generate nested VARIANT events for semi-structured querying demo."""
    out_dir = OUTPUT_DIR / "ga4_variant"
    out_dir.mkdir(parents=True, exist_ok=True)

    events = []
    for _ in range(50_000):
        events.append({
            "raw_event": {
                "event_name": random.choice(EVENT_TYPES),
                "event_timestamp": random_timestamp(),
                "user_pseudo_id": str(uuid.uuid4())[:12],
                "article_id": random_article_id(),
                "event_params": [
                    {"key": "article_section", "value": random.choice(SECTIONS)},
                    {"key": "page_title", "value": f"Article {random.randint(1, 500)}"},
                    {"key": "engagement_time_msec", "value": str(random.randint(1000, 300000))},
                ],
                "device": {
                    "category": random.choice(DEVICES),
                    "browser": random.choice(BROWSERS),
                    "os": random.choice(OS_LIST),
                },
                "geo": {
                    "country": random.choice(COUNTRIES),
                    "city": random.choice(FR_CITIES),
                    "region": "Ile-de-France" if random.random() < 0.4 else "Provence-Alpes-Cote d'Azur",
                },
                "traffic_source": {
                    "source": random.choice(SOURCES),
                    "medium": random.choice(MEDIUMS),
                    "campaign": random.choice([None, "summer_promo", "election_2026", "culture_week"]),
                },
            }
        })

    path = out_dir / "variant_events.json"
    with open(path, "w") as f:
        for event in events:
            f.write(json.dumps(event) + "\n")

    print(f"  GA4 VARIANT: 50,000 events → {path}")


# ---------------------------------------------------------------------------
# 3. Subscribers (PII for masking demo)
# ---------------------------------------------------------------------------

def generate_subscribers():
    """Generate subscriber records with PII fields for masking demo."""
    out_dir = OUTPUT_DIR / "subscribers"
    out_dir.mkdir(parents=True, exist_ok=True)

    subscribers = []
    for i in range(NUM_SUBSCRIBERS):
        first = random.choice(FIRST_NAMES)
        last = random.choice(LAST_NAMES)
        start_date = datetime.now() - timedelta(days=random.randint(30, 1800))
        days_since_login = random.randint(0, 90)
        last_login = datetime.now() - timedelta(days=days_since_login)
        articles_read_30d = random.randint(0, 120)
        paywall_bounces_30d = random.randint(0, 30)

        # Churn signal: more likely when inactive, low reading, high paywall bounces.
        # Gives the ML model a learnable pattern (days_since_login is top driver).
        churn_score = (
            days_since_login / 90.0 * 0.6
            + (1 - min(articles_read_30d, 60) / 60.0) * 0.25
            + min(paywall_bounces_30d, 30) / 30.0 * 0.15
        )
        churn_flag = random.random() < churn_score

        # Engagement segment derived from recent activity.
        if articles_read_30d >= 60 and days_since_login <= 7:
            segment = "loyal"
        elif articles_read_30d >= 20:
            segment = "regular"
        elif days_since_login >= 45:
            segment = "dormant"
        else:
            segment = "casual"

        subscribers.append({
            "user_id": f"USR_{i + 1:06d}",
            "full_name": f"{first} {last}",
            "email": f"{first.lower()}.{last.lower()}{random.randint(1, 99)}@arctic-times.fr",
            "phone": f"+33 6 {random.randint(10, 99)} {random.randint(10, 99)} {random.randint(10, 99)} {random.randint(10, 99)}",
            "subscription_type": random.choice(SUBSCRIPTION_TYPES),
            "start_date": start_date.strftime("%Y-%m-%d"),
            "last_login": last_login.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "articles_read_30d": articles_read_30d,
            "avg_session_sec": random.randint(30, 1200),
            "paywall_bounces_30d": paywall_bounces_30d,
            "ltv_estimated_eur": round(random.uniform(20, 2000), 2),
            "segment": segment,
            "churn_flag": churn_flag,
        })

    chunk_size = 20_000
    for i in range(0, len(subscribers), chunk_size):
        chunk = subscribers[i:i + chunk_size]
        path = out_dir / f"subscribers_{i // chunk_size:03d}.json"
        with open(path, "w") as f:
            for sub in chunk:
                f.write(json.dumps(sub) + "\n")

    print(f"  Subscribers: {NUM_SUBSCRIBERS:,} records → {out_dir}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    print("Arctic Times — Generating synthetic data...\n")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    generate_ga4_tracking()
    generate_ga4_variant()
    generate_subscribers()

    print(f"\nDone. Output at: {OUTPUT_DIR}")
    print("\nNext steps:")
    print("  1. Upload to Snowflake stages:")
    print("     PUT file://output/ga4_stage/batch_1/* @ARCTIC_TIMES.RAW.GA4_STAGE/batch_1/")
    print("     PUT file://output/ga4_stage/batch_2/* @ARCTIC_TIMES.RAW.GA4_STAGE/batch_2/")
    print("     PUT file://output/ga4_variant/* @ARCTIC_TIMES.RAW.GA4_VARIANT_STAGE/")
    print("     PUT file://output/subscribers/* @ARCTIC_TIMES.RAW.SUBSCRIBER_STAGE/")
    print("  2. Run COPY INTO commands from docs/demo_script.sql")


if __name__ == "__main__":
    main()
