#!/usr/bin/env python3
"""Build an open Hebrew -> French dictionary for Sarah IA Translate Live.

Sources (all freely licensed):
  * Tatoeba Hebrew/French sentence pairs (CC BY 2.0 FR)
  * French Wiktionary: French words/expressions with Hebrew translations,
    and Hebrew entries with French definitions (CC BY-SA 4.0, via kaikki.org)
  * English Wiktionary translation tables: Hebrew and French translations
    of the same English sense (CC BY-SA 4.0, via kaikki.org)

Output: TSV  kind <TAB> hebrew_key <TAB> french
  kind: s = whole sentence, e = multi-word expression, w = single word
  hebrew_key: Hebrew without vowel points / punctuation, single spaces.
"""
import bz2, gzip, io, json, re, sys, tarfile, unicodedata
from collections import OrderedDict

HEB_LETTER = re.compile(r"[א-ת]")
NIQQUD = re.compile(r"[֑-ׇ]")
NON_LETTER = re.compile(r"[^\wא-ת]+", re.UNICODE)


def key(hebrew: str) -> str:
    text = NIQQUD.sub("", unicodedata.normalize("NFC", hebrew))
    text = text.replace("־", " ")  # maqaf
    text = NON_LETTER.sub(" ", text)
    return " ".join(text.split())


def is_hebrew(text: str) -> bool:
    letters = [c for c in text if c.isalpha()]
    heb = sum(1 for c in letters if HEB_LETTER.match(c))
    return heb >= 1 and heb * 10 >= len(letters) * 9


def clean_fr(text: str) -> str:
    text = re.sub(r"\s*\([^)]*\)", "", text)  # drop "(familier)" etc.
    text = " ".join(text.split()).strip(" ;,.")
    return text


def good_fr(text: str) -> bool:
    return 0 < len(text) <= 80 and not HEB_LETTER.search(text) and any(c.isalpha() for c in text)


entries = {"s": OrderedDict(), "e": OrderedDict(), "w": OrderedDict()}
stats = {}


def add(hebrew: str, french: str, source: str, sentence: bool = False):
    k = key(hebrew)
    fr = clean_fr(french) if not sentence else " ".join(french.split())
    if not k or not is_hebrew(k) or not good_fr(fr) and not sentence:
        return
    if sentence and (not fr or len(fr) > 200):
        return
    words = k.count(" ") + 1
    kind = "s" if sentence else ("e" if words >= 2 else "w")
    if words > 14:
        return
    table = entries[kind]
    if k in table:
        return
    table[k] = fr
    stats[source] = stats.get(source, 0) + 1


def iter_jsonl_gz(path, must_contain=()):
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt", encoding="utf-8") as fh:
        for line in fh:
            # Cheap pre-filter: the raw dump has millions of irrelevant lines.
            if must_contain and not all(m in line for m in must_contain):
                continue
            try:
                yield json.loads(line)
            except ValueError:
                continue


def tr_lang(t):
    return t.get("lang_code") or t.get("code") or ""


def all_translations(entry):
    out = list(entry.get("translations") or [])
    for sense in entry.get("senses") or []:
        out.extend(sense.get("translations") or [])
    return out


def load_tatoeba(heb_path, fra_path, links_path):
    def sentences(path):
        result = {}
        with bz2.open(path, "rt", encoding="utf-8") as fh:
            for line in fh:
                parts = line.rstrip("\n").split("\t")
                if len(parts) >= 3:
                    result[parts[0]] = parts[2]
        return result

    heb = sentences(heb_path)
    fra = sentences(fra_path)
    pairs = 0
    with tarfile.open(links_path, "r:bz2") as tar:
        for member in tar:
            if not member.isfile():
                continue
            fh = io.TextIOWrapper(tar.extractfile(member), encoding="utf-8")
            for line in fh:
                parts = line.split()
                if len(parts) >= 2 and parts[0] in heb and parts[1] in fra:
                    add(heb[parts[0]], fra[parts[1]], "tatoeba", sentence=True)
                    pairs += 1
    print(f"tatoeba: {len(heb)} heb, {len(fra)} fra, {pairs} linked pairs", flush=True)


def load_fr_wiktionary(path):
    for entry in iter_jsonl_gz(path):
        lang = entry.get("lang_code")
        if lang == "fr":
            word = entry.get("word") or ""
            hebrew = [t for t in all_translations(entry) if tr_lang(t) == "he" and t.get("word")]
            # Prefer the main sense: translations listed first.
            for t in hebrew[:2]:
                add(t["word"], word, "frwikt_translation")
        elif lang == "he":
            word = entry.get("word") or ""
            for sense in (entry.get("senses") or [])[:1]:
                for gloss in (sense.get("glosses") or [])[:1]:
                    gloss = gloss.split(";")[0]
                    if len(gloss) <= 60:
                        add(word, gloss, "frwikt_hebrew_entry")


def load_en_wiktionary_pivot(path):
    seen = 0
    for entry in iter_jsonl_gz(path, must_contain=('"he"', '"fr"')):
        if entry.get("lang_code") != "en":
            continue
        seen += 1
        by_sense = {}
        for t in all_translations(entry):
            code = tr_lang(t)
            if code not in ("he", "fr") or not t.get("word"):
                continue
            sense = t.get("sense") or ""
            by_sense.setdefault(sense, {"he": [], "fr": []})[code].append(t["word"])
        for group in by_sense.values():
            if group["he"] and group["fr"] and len(group["he"]) <= 3:
                for hebrew in group["he"][:2]:
                    add(hebrew, group["fr"][0], "enwikt_pivot")
    print(f"en wiktionary: {seen} English entries scanned", flush=True)


def main():
    args = dict(a.split("=", 1) for a in sys.argv[1:])
    if args.get("tatoeba_heb"):
        load_tatoeba(args["tatoeba_heb"], args["tatoeba_fra"], args["tatoeba_links"])
    if args.get("frwikt"):
        load_fr_wiktionary(args["frwikt"])
        print(f"after fr wiktionary: {stats}", flush=True)
    if args.get("enwikt"):
        load_en_wiktionary_pivot(args["enwikt"])
    out = args.get("out", "he_fr_dictionary.tsv")
    with open(out, "w", encoding="utf-8") as fh:
        fh.write("# Sarah IA Hebrew->French dictionary. Tatoeba (CC BY 2.0 FR), Wiktionary (CC BY-SA 4.0).\n")
        for kind in ("s", "e", "w"):
            for k, fr in entries[kind].items():
                fh.write(f"{kind}\t{k}\t{fr}\n")
    total = sum(len(t) for t in entries.values())
    print(f"TOTAL={total} sentences={len(entries['s'])} expressions={len(entries['e'])} words={len(entries['w'])}")
    print(f"SOURCES={stats}")


if __name__ == "__main__":
    main()
