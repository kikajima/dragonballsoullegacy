from __future__ import annotations

import html
import re
import shutil
import time
import urllib.request
from html.parser import HTMLParser
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


def absolute_url(value: str) -> str:
    value = html.unescape(value.strip())
    if value.startswith("//"):
        return "https:" + value
    if value.startswith("/"):
        return BASE + value
    return value


def full_sheet_url(value: str) -> str:
    value = absolute_url(value)
    value = value.replace("/resources/sheet_icons/", "/resources/sheets/")
    value = value.replace("/resources/icons/", "/resources/sheets/")
    return value


class AssetListingParser(HTMLParser):
    def __init__(self, slug: str) -> None:
        super().__init__(convert_charrefs=True)
        self.slug = slug
        self.assets: dict[int, dict[str, str]] = {}
        self._active_id: int | None = None
        self._active_text: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attrs_dict = {key: value or "" for key, value in attrs}
        if tag == "a":
            href = attrs_dict.get("href", "")
            match = re.search(
                rf"/game_boy_advance/{re.escape(self.slug)}/asset/(\d+)/",
                href,
                re.I,
            )
            if match:
                self._active_id = int(match.group(1))
                self._active_text = []
                self.assets.setdefault(self._active_id, {})
                return

        if tag == "img" and self._active_id is not None:
            src = (
                attrs_dict.get("data-src", "")
                or attrs_dict.get("src", "")
                or attrs_dict.get("data-original", "")
            )
            if src and str(self._active_id) in src:
                self.assets[self._active_id]["image"] = full_sheet_url(src)

    def handle_data(self, data: str) -> None:
        if self._active_id is not None:
            self._active_text.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag != "a" or self._active_id is None:
            return
        text_value = clean_name(" ".join(self._active_text))
        if text_value and text_value != "asset":
            existing = self.assets[self._active_id].get("name", "")
            if not existing or existing.startswith("asset-"):
                self.assets[self._active_id]["name"] = text_value
        self._active_id = None
        self._active_text = []


def game_assets(slug: str) -> dict[int, dict[str, str]]:
    urls = [
        f"{BASE}/game_boy_advance/{slug}/",
        f"{BASE}/game_boy_advance/{slug}/page-1/",
        f"{BASE}/game_boy_advance/{slug}/page-2/",
    ]
    found: dict[int, dict[str, str]] = {}
    fallback = re.compile(
        rf'/game_boy_advance/{re.escape(slug)}/asset/(\d+)/',
        re.I,
    )

    for url in urls:
        try:
            page = request(url).decode("utf-8", "replace")
        except Exception:
            continue

        parser = AssetListingParser(slug)
        parser.feed(page)
        for asset_id, metadata in parser.assets.items():
            target = found.setdefault(asset_id, {})
            target.update({k: v for k, v in metadata.items() if v})

        for match in fallback.finditer(page):
            found.setdefault(int(match.group(1)), {})

    for asset_id, metadata in found.items():
        metadata.setdefault("name", f"asset-{asset_id}")

    return found


def download_asset(slug: str, asset_id: int, image_url: str) -> bytes:
    asset_page = f"{BASE}/game_boy_advance/{slug}/asset/{asset_id}/"
    if not image_url:
        raise RuntimeError(
            f"Asset {slug}/{asset_id} has no image URL in the game listing"
        )
    data = request(image_url, referer=asset_page)
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise RuntimeError(
            f"Asset {slug}/{asset_id} listing image was not a PNG: {image_url}"
        )
    return data


def main() -> None:
    if DEST.exists():
        shutil.rmtree(DEST)
    DEST.mkdir(parents=True, exist_ok=True)

    catalog = ["game\tasset_id\tname\tsource_image\trelative_path"]
    total = 0
    for slug, (game_name, expected) in GAMES.items():
        assets = game_assets(slug)
        print(f"{slug}: discovered {len(assets)} assets (expected {expected})")
        if len(assets) < expected:
            raise RuntimeError(
                f"Only discovered {len(assets)} of {expected} assets for {slug}"
            )

        missing_images = [
            asset_id
            for asset_id, metadata in assets.items()
            if not metadata.get("image")
        ]
        if missing_images:
            raise RuntimeError(
                f"{slug}: no listing image URL for asset IDs {missing_images[:20]}"
            )

        game_dir = DEST / slug
        game_dir.mkdir(parents=True, exist_ok=True)
        for index, (asset_id, metadata) in enumerate(sorted(assets.items()), start=1):
            safe_name = clean_name(metadata["name"])
            image_url = metadata["image"]
            filename = f"{asset_id}__{safe_name}.png"
            target = game_dir / filename
            target.write_bytes(download_asset(slug, asset_id, image_url))
            catalog.append(
                f"{game_name}\t{asset_id}\t{safe_name}\t{image_url}\t{slug}/{filename}"
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
