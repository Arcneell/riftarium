"""Extrait un jeu d'illustrations officielles depuis la galerie de cartes Riftbound."""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "sources" / "cards-fr.json"
TARGET = ROOT / "data" / "assets-fr.json"

DOMAIN_ORDER = ["fury", "calm", "mind", "body", "chaos", "order"]
SHOWCASE_TYPES = ["unit", "spell", "gear", "rune", "battlefield", "legend"]
RARITY_RANK = {"epic": 0, "rare": 1, "uncommon": 2, "common": 3, "showcase": 4}


def type_id(card) -> str:
    kinds = card.get("cardType", {}).get("type", [])
    return kinds[0]["id"] if kinds else ""


def type_label(card) -> str:
    kinds = card.get("cardType", {}).get("type", [])
    return kinds[0].get("label", "") if kinds else ""


def sized(url: str, width: int) -> str:
    """Demande au CDN une largeur precise pour eviter de charger du 744px inutile."""
    base = url.split("?")[0]
    return f"{base}?auto=format&fit=max&w={width}&accountingTag=RB"


def strip_tags(html: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", html)).strip()


def card_entry(card, width=560):
    image = card["cardImage"]
    return {
        "id": card["id"],
        "name": card["name"],
        "code": card["publicCode"],
        "set": card["set"]["value"]["label"],
        "type": type_label(card),
        "typeId": type_id(card),
        "rarity": card["rarity"]["value"]["label"],
        "orientation": card["orientation"],
        "domains": [d["id"] for d in card.get("domain", {}).get("values", [])],
        "artists": [a["label"] for a in card.get("illustrator", {}).get("values", [])],
        "image": sized(image["url"], width),
        "colors": image.get("colors", {}),
        "alt": f"Carte Riftbound : {card['name']} ({card['publicCode']})",
    }


def main():
    payload = json.loads(SOURCE.read_text(encoding="utf-8"))
    cards = payload["pageProps"]["page"]["blades"][2]["cards"]["items"]

    domain_icons = {}
    type_icons = {}
    for card in cards:
        for domain in card.get("domain", {}).get("values", []):
            if domain["id"] not in domain_icons and domain.get("icon"):
                domain_icons[domain["id"]] = {"label": domain["label"], "icon": domain["icon"]["url"]}
        for kind in card.get("cardType", {}).get("type", []):
            if kind["id"] not in type_icons and kind.get("icon"):
                type_icons[kind["id"]] = {"label": kind["label"], "icon": kind["icon"]["url"]}

    heroes = {}
    for domain in DOMAIN_ORDER:
        pool = [
            card for card in cards
            if [d["id"] for d in card.get("domain", {}).get("values", [])] == [domain]
            and type_id(card) == "unit"
            and card["rarity"]["value"]["id"] in {"epic", "rare"}
            and card["orientation"] == "portrait"
        ]
        pool.sort(key=lambda card: (RARITY_RANK.get(card["rarity"]["value"]["id"], 9), card["publicCode"]))
        if pool:
            heroes[domain] = card_entry(pool[0], 420)

    banners = [
        card_entry(card, 1000)
        for card in cards
        if card["orientation"] == "landscape" and card["set"]["value"]["id"] == "OGN"
    ][:8]

    showcase = {}
    for kind in SHOWCASE_TYPES:
        pool = [card for card in cards if type_id(card) == kind and card["set"]["value"]["id"] == "OGN"]
        pool.sort(key=lambda card: (RARITY_RANK.get(card["rarity"]["value"]["id"], 9), card["publicCode"]))
        if pool:
            entry = card_entry(pool[0], 500)
            entry["text"] = strip_tags(pool[0].get("text", {}).get("richText", {}).get("body", ""))
            showcase[kind] = entry

    fan = [
        card_entry(card, 420)
        for card in cards
        if card["rarity"]["value"]["id"] == "epic"
        and card["orientation"] == "portrait"
        and card["set"]["value"]["id"] == "OGN"
        and type_id(card) == "unit"
    ][:5]

    TARGET.parent.mkdir(exist_ok=True)
    TARGET.write_text(json.dumps({
        "source": "https://playriftbound.com/fr-fr/card-gallery/",
        "notice": "Illustrations et icones (c) Riot Games, Inc. Servies depuis le CDN officiel.",
        "domainIcons": domain_icons,
        "typeIcons": type_icons,
        "domainHeroes": heroes,
        "banners": banners,
        "showcase": showcase,
        "fan": fan,
    }, ensure_ascii=False, indent=1), encoding="utf-8")

    print(f"Domaines: {len(domain_icons)} | types: {len(type_icons)}")
    for domain, card in heroes.items():
        print(f"  {domain:6} -> {card['name']} ({card['code']})")
    print("Showcase:")
    for kind, card in showcase.items():
        print(f"  {kind:12} -> {card['name']} [{card['type']}] {card['orientation']}")
    print(f"Bannieres: {len(banners)} | eventail: {len(fan)}")
    print(f"Ecrit {TARGET}")


if __name__ == "__main__":
    main()
