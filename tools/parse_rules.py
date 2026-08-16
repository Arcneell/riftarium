"""Convertit l'extraction texte des PDF officiels Riftbound en JSON structuré."""

import json
import re
import sys
from pathlib import Path

ENTRY_RE = re.compile(r"^(?P<num>\d{3}\.(?:\d+\.)?(?:[a-z]\.)?(?:\d+\.)?)(?P<gap>\s+)(?P<text>\S.*)$")
EXAMPLE_RE = re.compile(r"^\s*(?:Exemple|Exemples)\s*:\s*(.*)$")
REF_RE = re.compile(r"^\s*Voir r[èe]gle\s+(?P<num>[\d.]+?)\.?\s+(?P<label>.+?)\s+pour plus d'informations\.\s*$")
PAGE_RE = re.compile(r"^\s*\d{1,3}\s*$")


def slug(number: str) -> str:
    return number.rstrip(".").replace(".", "-")


def depth_of(number: str) -> int:
    return len(number.rstrip(".").split(".")) - 1


def looks_like_heading(number: str, text: str) -> bool:
    if depth_of(number) != 0:
        return False
    if len(text) > 70 or text.endswith((".", ":", "»")):
        return False
    return True


def parse(path: Path):
    raw = path.read_text(encoding="utf-8").replace("\f", "\n")
    entries = []
    current = None
    example = None
    example_indent = 0

    for line in raw.split("\n"):
        line = line.rstrip()
        if not line.strip() or PAGE_RE.match(line):
            example = None
            continue

        match = ENTRY_RE.match(line)
        if match:
            number = match.group("num")
            current = {
                "number": number,
                "id": slug(number),
                "depth": depth_of(number),
                "text": match.group("text").lstrip("* ").strip(),
                "examples": [],
                "refs": [],
            }
            entries.append(current)
            example = None
            continue

        if current is None:
            continue

        indent = len(line) - len(line.lstrip())
        stripped = line.strip()

        ref = REF_RE.match(stripped)
        if ref:
            current["refs"].append({"number": ref.group("num"), "label": ref.group("label")})
            example = None
            continue

        started = EXAMPLE_RE.match(stripped)
        if started:
            example = {"text": started.group(1).strip()}
            example_indent = indent
            current["examples"].append(example)
            continue

        if example is not None and indent >= example_indent:
            example["text"] = f"{example['text']} {stripped}".strip()
            continue

        example = None
        current["text"] = f"{current['text']} {stripped}".strip()

    return entries


def group(entries):
    chapters = []
    chapter = None
    section = None

    def new_section(number, title):
        return {"number": number, "id": slug(number), "title": title, "entries": []}

    for entry in entries:
        heading = looks_like_heading(entry["number"], entry["text"])
        is_chapter = heading and entry["number"].rstrip(".").isdigit() and int(entry["number"].rstrip(".")) % 100 == 0

        if is_chapter:
            chapter = {
                "number": entry["number"],
                "id": slug(entry["number"]),
                "title": entry["text"],
                "sections": [],
            }
            chapters.append(chapter)
            section = None
            continue

        if chapter is None:
            chapter = {"number": "000.", "id": "000", "title": "Préambule", "sections": []}
            chapters.append(chapter)

        if heading:
            section = new_section(entry["number"], entry["text"])
            chapter["sections"].append(section)
            continue

        if section is None:
            section = new_section(entry["number"], chapter["title"])
            chapter["sections"].append(section)

        section["entries"].append(entry)

    for chapter in chapters:
        chapter["sections"] = [s for s in chapter["sections"] if s["entries"]]
    return [c for c in chapters if c["sections"]]


def build(path: Path, meta: dict):
    entries = parse(path)
    chapters = group(entries)
    total = sum(len(s["entries"]) for c in chapters for s in c["sections"])
    print(f"{path.name}: {len(entries)} entrées, {len(chapters)} chapitres, {total} règles conservées")
    for chapter in chapters:
        print(f"  {chapter['number']} {chapter['title']} ({len(chapter['sections'])} sections)")
    return {**meta, "chapters": chapters, "ruleCount": total}


def main():
    root = Path(__file__).resolve().parent.parent
    src = root / "sources"
    out = root / "data"
    out.mkdir(exist_ok=True)

    documents = {
        "core": build(src / "core-fr.txt", {
            "key": "core",
            "title": "Règles du jeu",
            "subtitle": "Le moteur complet d'une partie de Riftbound",
            "updated": "16 juillet 2026",
            "source": "https://cmsassets.rgpub.io/sanity/files/dsfx7636/news_live/f668751be265e4bdf828145b593a74e0ddab6a9f.pdf",
        }),
        "tournament": build(src / "tournament-fr.txt", {
            "key": "tournament",
            "title": "Règles de tournoi",
            "subtitle": "Cadre officiel du jeu organisé",
            "updated": "16 juillet 2026",
            "source": "https://cmsassets.rgpub.io/sanity/files/dsfx7636/news_live/fe9e2bd1e9b466be164da79d64e79e68f5e4c037.pdf",
        }),
    }

    target = out / "rules-fr.json"
    target.write_text(json.dumps(documents, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"\nÉcrit {target} ({target.stat().st_size / 1024:.0f} Ko)")


if __name__ == "__main__":
    sys.exit(main())
