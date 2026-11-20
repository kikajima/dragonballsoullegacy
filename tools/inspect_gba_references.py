"""Read-only ROM inventory and text leads; not a disassembler or mechanics proof."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROM_DIR = ROOT / "references" / "roms"
TERMS = re.compile(rb"kamehameha|masenko|special beam|spirit bomb|big bang|energy punch|scatter shot|burning attack|hold the|release the", re.I)


def inspect(path):
    blob = path.read_bytes()
    if len(blob) < 192:
        return {"file": path.name, "error": "Truncated header"}
    expected = (-sum(blob[0xA0:0xBD]) - 0x19) & 0xFF
    leads = []
    for match in re.finditer(rb"[\x20-\x7e]{6,}", blob):
        if TERMS.search(match.group()):
            leads.append({"offset": hex(match.start()), "text": match.group().decode("ascii")[:700]})
    return {
        "file": path.name,
        "bytes": len(blob),
        "sha256": hashlib.sha256(blob).hexdigest(),
        "title": blob[0xA0:0xAC].rstrip(b"\0").decode("ascii", errors="replace"),
        "game_code": blob[0xAC:0xB0].decode("ascii", errors="replace"),
        "revision": blob[0xBC],
        "header_checksum_valid": expected == blob[0xBD],
        "fixed_byte_valid": blob[0xB2] == 0x96,
        "text_leads": leads,
        "limitation": "Header validation is not a whole-ROM integrity check. Text leads do not prove timing, damage, collisions or executable code behavior.",
    }


if __name__ == "__main__":
    results = [inspect(path) for path in sorted(ROM_DIR.glob("*.gba"))]
    output = ROM_DIR / "inventory.json"
    output.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    for result in results:
        summary = {key: value for key, value in result.items() if key != "text_leads"}
        summary["text_lead_count"] = len(result.get("text_leads", []))
        print(json.dumps(summary, ensure_ascii=False))
        for lead in result.get("text_leads", [])[:8]:
            print(lead)
