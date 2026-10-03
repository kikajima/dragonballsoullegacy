from __future__ import annotations

import html
import re
import shutil
import time
import urllib.request
from pathlib import Path

BASE = "https://www.spriters-resource.com"
DEST = Path("assets/vendor/gba")
GAMES = {
    "dbzlog": ("Dragon Ball Z - The Legacy of Goku", 49),
    "dbzlog2": ("Dragon Ball Z - The Legacy of Goku II", 101),
    "dbzbuusfury": ("Dragon Ball Z - Buu's Fury", 117),
}
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/126.0 Safari/537.36"
)


def request(url: str, referer: str | None = None) -> bytes:
    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "text/html,application/xhtml+xml,image/avif,image/webp,image/png,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
    }
    if referer:
        headers["Referer"] = referer
    last_error: Exception | None = None
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=45) as response:
                return response.read()
        except Exception as exc:
            last_error = exc
            time.sleep(2 + attempt * 2)
    raise RuntimeError(f"Failed to fetch {url}: {last_error}")


def clean_name(value: str) -> str:
    value = html.unescape(re.sub(r"<[^>]+>", "", value))
    value = re.sub(r"\s+", " ", value).strip()
    value = value.replace("/", "_").replace("\\", "_")
    value = re.sub(r"[\x00-\x1f]", "", value)
    return value or "asset"


def game_assets(slug: str) -> dict[int, str]:
    urls = [
        f"{BASE}/game_boy_advance/{slug}/",
        f"{BASE}/game_boy_advance/{slug}/page-1/",
        f"{BASE}/game_boy_advance/{slug}/page-2/",
    ]
    found: dict[int, str] = {}
    pattern = re.compile(
        rf'href=["\']/game_boy_advance/{re.escape(slug)}/asset/(\d+)/(?:page-\d+/)?["\'][^>]*>(.*?)</a>',
        re.I | re.S,
    )
    fallback = re.compile(
        rf'/game_boy_advance/{re.escape(slug)}/asset/(\d+)/',
        re.I,
    )
    for url in urls:
        try:
            page = request(url).decode("utf-8", "replace")
        except Exception:
            continue
        for match in pattern.finditer(page):
            found[int(match.group(1))] = clean_name(match.group(2))
        for match in fallback.finditer(page):
            found.setdefault(int(match.group(1)), f"asset-{match.group(1)}")
    return found


def download_asset(slug: str, asset_id: int) -> bytes:
    # The site's image CDN buckets assets by the integer thousands group.
    # Example: asset 14506 -> /media/assets/14/14506.png
    asset_page = f"{BASE}/game_boy_advance/{slug}/asset/{asset_id}/"
    bucket = asset_id // 1000
    media_url = f"{BASE}/media/assets/{bucket}/{asset_id}.png"
    data = request(media_url, referer=asset_page)
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise RuntimeError(
            f"Asset {slug}/{asset_id} CDN response was not a PNG"
        )
    return data


def main() -> None:
    if DEST.exists():
        shutil.rmtree(DEST)
    DEST.mkdir(parents=True, exist_ok=True)

    catalog = ["game\tasset_id\tname\trelative_path"]
    total = 0
    for slug, (game_name, expected) in GAMES.items():
        assets = game_assets(slug)
        print(f"{slug}: discovered {len(assets)} assets (expected {expected})")
        if len(assets) < expected:
            raise RuntimeError(
                f"Only discovered {len(assets)} of {expected} assets for {slug}"
            )

        game_dir = DEST / slug
        game_dir.mkdir(parents=True, exist_ok=True)
        for index, (asset_id, name) in enumerate(sorted(assets.items()), start=1):
            safe_name = clean_name(name)
            filename = f"{asset_id}__{safe_name}.png"
            target = game_dir / filename
            target.write_bytes(download_asset(slug, asset_id))
            catalog.append(
                f"{game_name}\t{asset_id}\t{safe_name}\t{slug}/{filename}"
            )
            total += 1
            if index % 20 == 0 or index == len(assets):
                print(f"  {index}/{len(assets)} downloaded")
            time.sleep(0.1)

    (DEST / "CATALOG.tsv").write_text(
        "\n".join(catalog) + "\n", encoding="utf-8"
    )
    (DEST / "README.md").write_text(
        """# Dragon Ball GBA reference sprite library

Reference sprite sheets for The Legacy of Goku, The Legacy of Goku II,
and Buu's Fury. Source pages: The Spriters Resource. The numeric prefix in
each filename is the source asset ID; `CATALOG.tsv` maps IDs and names.

Stored as source/reference material for the DBSL prototype. Copyright and
redistribution rights remain with their respective owners.
""",
        encoding="utf-8",
    )
    print(f"Downloaded {total} official PNG sprite sheets")


if __name__ == "__main__":
    main()
