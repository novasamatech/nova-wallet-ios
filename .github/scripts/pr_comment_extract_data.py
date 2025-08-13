import os
import sys
import re
from datetime import datetime
import requests


ALLOWED_SEVERITIES = {"Major", "Critical", "Normal"}

# Matches: "Release severity: <value>" (case-insensitive, flexible spaces)
SEVERITY_LINE_RE = re.compile(r"^release\s+severity\s*:\s*(.+)$", re.IGNORECASE)

# Matches: "Release version: <value>" (case-insensitive, flexible spaces)
VERSION_LINE_RE = re.compile(r"^release\s+version\s*:\s*(.+)$", re.IGNORECASE)

# SemVer pattern with optional leading 'v', optional prerelease/build metadata
SEMVER_RE = re.compile(
    r"^v?(?P<core>\d+\.\d+\.\d+)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$"
)


def parse_base_params(comment_link: str) -> None:
    if not comment_link:
        print("COMMENT_LINK is not set. Provide a valid PR comment API URL in env var COMMENT_LINK.")
        sys.exit(1)

    env_file = os.getenv("GITHUB_ENV")
    if not env_file:
        print("GITHUB_ENV is not set. This script expects GitHub Actions environment.")
        sys.exit(1)

    try:
        resp = requests.get(comment_link, timeout=10)
        resp.raise_for_status()
        payload = resp.json()
    except requests.RequestException as e:
        print(f"Failed to fetch PR comment: {e}")
        sys.exit(1)
    except ValueError:
        print("Response is not valid JSON.")
        sys.exit(1)

    body = payload.get("body")
    if not isinstance(body, str) or not body.strip():
        print("PR comment body is empty. Add strings 'Release severity: Major | Critical | Normal' and 'Release version: 1.2.3'.")
        sys.exit(1)

    lines = [line.strip() for line in body.splitlines()]

    severity_raw = ""
    version_raw = ""

    for line in lines:
        m = SEVERITY_LINE_RE.match(line)
        if m:
            severity_raw = m.group(1).strip()
            continue
        m = VERSION_LINE_RE.match(line)
        if m:
            version_raw = m.group(1).strip()
            continue

    if not severity_raw:
        print("Release severity is missing. Add a line 'Release severity: Major | Critical | Normal'.")
        sys.exit(1)

    if severity_raw not in ALLOWED_SEVERITIES:
        print(f"Invalid severity '{severity_raw}'. Allowed values: Major, Critical, Normal.")
        sys.exit(1)

    if not version_raw:
        print("Release version is missing. Add a line 'Release version: 1.2.3'.")
        sys.exit(1)

    m_ver = SEMVER_RE.match(version_raw)
    if not m_ver:
        print(f"Invalid version '{version_raw}'. Expected SemVer (e.g., 1.2.3, 1.2.3-rc.1, 1.2.3+build.5).")
        sys.exit(1)

    # Normalize version: strip optional leading 'v'
    version = version_raw[1:] if version_raw.lower().startswith("v") else version_raw

    severity = severity_raw
    time_iso = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

    try:
        with open(env_file, "a", encoding="utf-8") as f:
            f.write(f"TIME={time_iso}\n")
            f.write(f"SEVERITY={severity}\n")
            f.write(f"VERSION={version}\n")
    except OSError as e:
        print(f"Failed to write to GITHUB_ENV: {e}")
        sys.exit(1)


if __name__ == "__main__":
    parse_base_params(os.getenv("COMMENT_LINK"))
