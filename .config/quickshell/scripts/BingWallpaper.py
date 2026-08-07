#!/usr/bin/env python3
"""
Bing UHD Wallpaper Downloader
Supports:
  --check-updates   : compare remote list vs local files, print NEW:filename lines
  --download        : download filtered/all wallpapers (skips already-downloaded)
  --daily           : fetch/download today's (newest) wallpaper, print DAILY:/path
  --filter          : all | current | last | custom (default: all)
  --month           : YYYY-MM  (used with --filter custom)
  --path            : override download directory
  --count-only      : print COUNT:N and exit
"""

import re
import sys
import json
import argparse
import requests
from pathlib import Path
from datetime import datetime, timedelta

# ── Config ──────────────────────────────────────────────────────────────────
TARGET_DIR      = Path.home() / "Pictures" / "BingWallpaper"
README_URL      = "https://raw.githubusercontent.com/v5tech/bing-wallpaper/refs/heads/main/README.md"
JSON_CACHE_FILE = Path.home() / ".cache" / "quickshell" / "bingwall" / "bing_wallpapers.json"
HEADERS         = {"User-Agent": "Mozilla/5.0 BingWallpaperDownloader/2026"}


# ── Helpers ──────────────────────────────────────────────────────────────────
def ensure_dirs():
    TARGET_DIR.mkdir(parents=True, exist_ok=True)
    JSON_CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)


def fetch_readme() -> str | None:
    print(f"[FETCH] {README_URL}", flush=True)
    try:
        r = requests.get(README_URL, headers=HEADERS, timeout=20)
        r.raise_for_status()
        print(f"[FETCH] OK – {len(r.text):,} chars", flush=True)
        return r.text
    except Exception as e:
        print(f"[FETCH] ERROR: {e}", file=sys.stderr, flush=True)
        return None


def parse_wallpapers(md: str) -> list[dict]:
    """
    Parse the bing-wallpaper README.md.

    The actual README format has date and UHD download URL in the same cell:
        ![title](thumb_url) 2026-03-25 [download 4k](https://cn.bing.com/th?id=OHR.Name_UHD.jpg)

    Strategy 1: match date + [download 4k](UHD_URL) pairs directly.
    Strategy 2: fallback loose scan for any _UHD.jpg URL with nearby date.
    """
    items: list[dict] = []
    seen_urls: set[str] = set()

    # ── Strategy 1: date followed by [download 4k](UHD_URL) ─────────────────
    cell_re = re.compile(
        r'(\d{4}-\d{2}-\d{2})\s+\[download 4k\]\((https://[^\)]+?_UHD\.jpg)\)',
        re.IGNORECASE
    )
    for m in cell_re.finditer(md):
        date_str, url = m.group(1), m.group(2)
        if url in seen_urls:
            continue
        seen_urls.add(url)
        entry = _make_entry(url, date_str)
        if entry:
            items.append(entry)

    # ── Strategy 2: loose scan for any _UHD.jpg URL not yet found ───────────
    loose_re = re.compile(r'(https://cn\.bing\.com/th\?id=[^\s\)&"\']+?_UHD\.jpg)', re.IGNORECASE)
    for url in loose_re.findall(md):
        if url in seen_urls:
            continue
        seen_urls.add(url)
        pos = md.find(url)
        # Look for a date within 150 chars before or after the URL
        context = md[max(0, pos - 150): pos + 150]
        dm = re.search(r'(\d{4}-\d{2}-\d{2})', context)
        date_str = dm.group(1) if dm else "unknown"
        entry = _make_entry(url, date_str)
        if entry:
            items.append(entry)

    # Sort newest-first
    items.sort(
        key=lambda x: x["date"] if x["date"] != "unknown" else "0000-00-00",
        reverse=True,
    )
    print(f"[PARSE] {len(items)} wallpapers found", flush=True)
    return items


def _make_entry(url: str, date_str: str) -> dict | None:
    """Build a wallpaper entry dict from a URL and date string.

    NOTE: local_path is intentionally omitted here — it must be set at
    runtime after TARGET_DIR may have been overridden by --path.
    Call _resolve_local_paths(items) once TARGET_DIR is finalised.
    """
    # Extract filename from ?id=OHR.Foo_EN-US1234_UHD.jpg
    id_part = ""
    if "?id=" in url:
        id_part = url.split("?id=")[1].split("&")[0].rstrip(")")
    if not id_part:
        id_part = url.split("/")[-1].split("?")[0]
    if not id_part or len(id_part) < 8:
        return None

    filename = re.sub(r'[^a-zA-Z0-9._-]', '_', id_part)
    if not filename.endswith("_UHD.jpg"):
        filename += "_UHD.jpg"

    month = date_str[:7] if date_str != "unknown" else "unknown"
    return {
        "date":       date_str,
        "month":      month,
        "url":        url,
        "filename":   filename,
        "local_path": "",   # filled in by _resolve_local_paths()
    }


def _resolve_local_paths(items: list[dict]) -> None:
    """Rewrite local_path for every entry to reflect the current TARGET_DIR.

    Called once TARGET_DIR is final (i.e. after --path is applied).
    This fixes the bug where _make_entry captured TARGET_DIR at parse
    time (before main() could override it), causing --path to be ignored
    for disk-presence checks and actual downloads.
    """
    for item in items:
        item["local_path"] = str(TARGET_DIR / item["filename"])


def load_cache() -> list[dict]:
    try:
        with open(JSON_CACHE_FILE) as f:
            return json.load(f)
    except Exception:
        return []


def save_cache(items: list[dict]):
    try:
        JSON_CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(JSON_CACHE_FILE, "w") as f:
            json.dump(items, f, indent=2)
        print(f"[CACHE] Saved {len(items)} entries → {JSON_CACHE_FILE}", flush=True)
    except Exception as e:
        print(f"[CACHE] Save failed: {e}", file=sys.stderr, flush=True)


def local_filenames() -> set[str]:
    """Return basenames of every image already on disk."""
    return {
        p.name
        for p in TARGET_DIR.iterdir()
        if p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}
    } if TARGET_DIR.exists() else set()


def filter_wallpapers(items: list[dict], filter_type: str, custom_month: str | None) -> list[dict]:
    if filter_type == "all":
        return items
    today        = datetime.now()
    cur_month    = today.strftime("%Y-%m")
    last_month   = (today.replace(day=1) - timedelta(days=1)).strftime("%Y-%m")
    if filter_type == "current":
        return [w for w in items if w["month"] == cur_month]
    if filter_type == "last":
        return [w for w in items if w["month"] == last_month]
    if filter_type == "custom" and custom_month:
        return [w for w in items if w["month"] == custom_month]
    return items


def download_image(entry: dict) -> tuple[bool, str]:
    path = Path(entry["local_path"])
    if path.exists():
        return True, "skipped"
    print(f"[DL] {entry['filename']}  ({entry['date']})", flush=True)
    try:
        r = requests.get(entry["url"], headers=HEADERS, stream=True, timeout=30)
        r.raise_for_status()
        with open(path, "wb") as f:
            for chunk in r.iter_content(chunk_size=65536):
                f.write(chunk)
        print(f"[DL] ✓ saved {path}", flush=True)
        return True, "downloaded"
    except Exception as e:
        print(f"[DL] FAIL: {e}", file=sys.stderr, flush=True)
        return False, "failed"


# ── Modes ────────────────────────────────────────────────────────────────────

def mode_check_updates(items: list[dict]):
    """
    Compare remote list with local files.
    Prints one line per new (not-yet-downloaded) wallpaper:
        NEW:<filename>|<date>|<url>
    Then a summary:
        UPDATE_COUNT:<n>
    QML can parse these lines to decide whether to prompt the user.
    """
    on_disk  = local_filenames()
    new_ones = [w for w in items if w["filename"] not in on_disk]
    for w in new_ones:
        print(f"NEW:{w['filename']}|{w['date']}|{w['url']}", flush=True)
    print(f"UPDATE_COUNT:{len(new_ones)}", flush=True)


def mode_daily(items: list[dict]) -> int:
    """
    Ensure the newest wallpaper is downloaded and print:
        DAILY:/absolute/path/to/file
    Returns exit code.
    """
    if not items:
        print("DAILY_ERROR:no wallpapers in cache", flush=True)
        return 1

    newest = items[0]  # already sorted newest-first
    path   = Path(newest["local_path"])

    if not path.exists():
        ok, status = download_image(newest)
        if not ok:
            print(f"DAILY_ERROR:download failed for {newest['filename']}", flush=True)
            return 1

    print(f"DAILY:{path}", flush=True)
    return 0


def mode_download(items: list[dict], filter_type: str, custom_month: str | None):
    selected = filter_wallpapers(items, filter_type, custom_month)
    on_disk  = local_filenames()
    # Skip anything already on disk (double-check beyond download_image)
    to_fetch = [w for w in selected if w["filename"] not in on_disk]

    total   = len(to_fetch)
    already = len(selected) - total
    found   = len(selected)   # total matched by the filter (may be 0 if period not in archive)
    print(f"[DL] {total} to download, {already} already exist, {found} in archive", flush=True)
    # FOUND: tells QML how many the archive has for this period (0 = period not in archive yet)
    print(f"FOUND:{found}", flush=True)
    # If nothing found for this period, tell QML what the newest available date is
    if found == 0 and items:
        print(f"NEWEST:{items[0]['date']}", flush=True)
    # Emit total immediately so the QML progress bar can size itself
    print(f"TOTAL:{total}", flush=True)

    if total == 0:
        print(f"DONE:downloaded=0,skipped={already},failed=0", flush=True)
        return

    downloaded = skipped = failed = 0
    for i, entry in enumerate(to_fetch, 1):
        ok, status = download_image(entry)
        if status == "downloaded":
            downloaded += 1
            print(f"DOWNLOADED:{entry['filename']}|{entry['date']}", flush=True)
        elif status == "skipped":
            skipped += 1
        else:
            failed += 1
        # Emit progress after EVERY item (not just every 10)
        print(f"PROGRESS:{i}/{total}", flush=True)

    print(f"DONE:downloaded={downloaded},skipped={skipped},failed={failed}", flush=True)


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    global TARGET_DIR

    parser = argparse.ArgumentParser(description="Bing UHD Wallpaper Downloader")
    parser.add_argument("--filter",        choices=["current", "last", "custom", "all"], default="all")
    parser.add_argument("--month",         type=str,  help="YYYY-MM (with --filter custom)")
    parser.add_argument("--download",      action="store_true", help="Download filtered wallpapers")
    parser.add_argument("--check-updates", action="store_true", help="List wallpapers not yet on disk")
    parser.add_argument("--daily",         action="store_true", help="Download & print path of newest wallpaper")
    parser.add_argument("--count-only",    action="store_true", help="Print COUNT:N and exit")
    parser.add_argument("--path",          type=str,  help="Override download directory")
    parser.add_argument("--use-cache",     action="store_true", help="Use local JSON cache instead of fetching README")
    args = parser.parse_args()

    if args.path:
        TARGET_DIR = Path(args.path)

    ensure_dirs()

    # Fetch or load wallpaper list
    if args.use_cache:
        items = load_cache()
        if not items:
            print("[MAIN] Cache empty, fetching README…", flush=True)
            md = fetch_readme()
            if not md:
                sys.exit(1)
            items = parse_wallpapers(md)
            save_cache(items)
    else:
        md = fetch_readme()
        if not md:
            sys.exit(1)
        items = parse_wallpapers(md)
        save_cache(items)

    # ── CRITICAL: rewrite local_path to reflect the actual TARGET_DIR ────────
    # _make_entry() stores "" as a placeholder; this fills in the real paths
    # now that --path has been applied and TARGET_DIR is final.
    _resolve_local_paths(items)

    if not items:
        print("[MAIN] No wallpapers found.", flush=True)
        sys.exit(1)

    # ── Dispatch ─────────────────────────────────────────────────────────────
    if args.count_only:
        selected = filter_wallpapers(items, args.filter, args.month)
        print(f"COUNT:{len(selected)}", flush=True)
        return

    if args.check_updates:
        mode_check_updates(items)
        return

    if args.daily:
        sys.exit(mode_daily(items))

    if args.download:
        mode_download(items, args.filter, args.month)
        return

    print("[MAIN] No action specified. Use --download, --check-updates, --daily, or --count-only.", flush=True)


if __name__ == "__main__":
    main()
