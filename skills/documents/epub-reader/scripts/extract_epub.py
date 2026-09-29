#!/usr/bin/env python3
"""
extract_epub.py — Extract structured content from an epub file.

Usage:
  python3 extract_epub.py <epub_path>                        # full extraction
  python3 extract_epub.py <epub_path> --max-chapters 5       # first N chapters
  python3 extract_epub.py <epub_path> --chapter 2            # single chapter (0-based)
  python3 extract_epub.py <epub_path> --search "some term"   # search across chapters
  python3 extract_epub.py <epub_path> --toc-only             # just TOC + metadata
"""

import argparse
import json
import re
import sys
from pathlib import Path

try:
    import ebooklib
    from ebooklib import epub
    from bs4 import BeautifulSoup
except ImportError:
    print(json.dumps({"error": "Missing dependencies. Run: pip install ebooklib beautifulsoup4 --break-system-packages"}))
    sys.exit(1)


def html_to_text(html_content: str) -> str:
    """Strip HTML tags and return clean plain text."""
    soup = BeautifulSoup(html_content, "html.parser")
    # Remove script/style tags
    for tag in soup(["script", "style"]):
        tag.decompose()
    text = soup.get_text(separator="\n")
    # Collapse excessive blank lines
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def get_metadata(book: epub.EpubBook) -> dict:
    """Extract book metadata."""
    def first(lst):
        return lst[0] if lst else None

    title = first(book.get_metadata("DC", "title"))
    author = first(book.get_metadata("DC", "creator"))
    publisher = first(book.get_metadata("DC", "publisher"))
    language = first(book.get_metadata("DC", "language"))
    date = first(book.get_metadata("DC", "date"))
    description = first(book.get_metadata("DC", "description"))

    # Metadata values can be tuples (value, attrs) or plain strings
    def extract(val):
        if val is None:
            return None
        if isinstance(val, tuple):
            return val[0]
        return str(val)

    return {
        "title": extract(title),
        "author": extract(author),
        "publisher": extract(publisher),
        "language": extract(language),
        "date": extract(date),
        "description": extract(description),
    }


def get_chapters(book: epub.EpubBook) -> list:
    """
    Extract chapters in reading order. Returns list of dicts:
      { index, title, text, word_count }
    Skips non-document items (images, CSS, etc.).
    """
    chapters = []

    # Build a title map from the TOC entries
    toc_titles = {}
    def walk_toc(items):
        for item in items:
            if isinstance(item, epub.Link):
                # href may include fragment: "chapter1.xhtml#section1"
                href = item.href.split("#")[0]
                toc_titles[href] = item.title
            elif isinstance(item, tuple):
                # Section: (Section, [children])
                section, children = item
                if hasattr(section, "href"):
                    href = section.href.split("#")[0]
                    toc_titles[href] = section.title
                walk_toc(children)

    walk_toc(book.toc)

    # Iterate items in spine order
    idx = 0
    for item_id, _ in book.spine:
        item = book.get_item_with_id(item_id)
        if item is None:
            continue
        if item.get_type() != ebooklib.ITEM_DOCUMENT:
            continue

        content_bytes = item.get_content()
        if not content_bytes:
            continue

        try:
            html = content_bytes.decode("utf-8", errors="replace")
        except Exception:
            continue

        text = html_to_text(html)
        if not text or len(text.strip()) < 20:
            # Skip near-empty items (cover page boilerplate, etc.)
            continue

        # Derive a title: prefer TOC, fall back to first heading, then filename
        file_name = Path(item.file_name).name
        title = toc_titles.get(file_name)
        if not title:
            # Try to extract first heading from the HTML
            soup = BeautifulSoup(html, "html.parser")
            heading = soup.find(re.compile(r"^h[1-6]$"))
            title = heading.get_text(strip=True) if heading else file_name

        word_count = len(text.split())
        chapters.append({
            "index": idx,
            "title": title,
            "text": text,
            "word_count": word_count,
        })
        idx += 1

    return chapters


def search_chapters(chapters: list, query: str, context_chars: int = 300) -> list:
    """
    Case-insensitive search across chapters.
    Returns chapters that have matches, each augmented with a 'matches' list.
    Each match is a dict: { position, snippet }
    """
    results = []
    pattern = re.compile(re.escape(query), re.IGNORECASE)

    for ch in chapters:
        text = ch["text"]
        matches = []
        for m in pattern.finditer(text):
            start = max(0, m.start() - context_chars // 2)
            end = min(len(text), m.end() + context_chars // 2)
            snippet = text[start:end].strip()
            # Mark the match within the snippet
            snippet = re.sub(pattern, lambda x: f"**{x.group()}**", snippet)
            matches.append({
                "position": m.start(),
                "snippet": snippet,
            })
        if matches:
            ch_copy = {k: v for k, v in ch.items() if k != "text"}
            ch_copy["matches"] = matches[:10]  # cap at 10 matches per chapter
            results.append(ch_copy)

    return results


def build_toc(chapters: list) -> list:
    """Return a simple ordered list of chapter titles."""
    return [f"{ch['index']}. {ch['title']} ({ch['word_count']:,} words)" for ch in chapters]


def main():
    parser = argparse.ArgumentParser(description="Extract content from an epub file")
    parser.add_argument("epub_path", help="Path to the .epub file")
    parser.add_argument("--max-chapters", type=int, default=None,
                        help="Limit extraction to first N chapters")
    parser.add_argument("--chapter", type=int, default=None,
                        help="Extract a single chapter by 0-based index")
    parser.add_argument("--search", type=str, default=None,
                        help="Search for a term across all chapters")
    parser.add_argument("--toc-only", action="store_true",
                        help="Return only the table of contents and metadata")
    args = parser.parse_args()

    epub_path = Path(args.epub_path).expanduser().resolve()
    if not epub_path.exists():
        print(json.dumps({"error": f"File not found: {epub_path}"}))
        sys.exit(1)

    try:
        book = epub.read_epub(str(epub_path))
    except Exception as e:
        print(json.dumps({"error": f"Failed to read epub: {e}"}))
        sys.exit(1)

    metadata = get_metadata(book)
    chapters = get_chapters(book)
    toc = build_toc(chapters)
    total_words = sum(ch["word_count"] for ch in chapters)

    # --- TOC-only mode ---
    if args.toc_only:
        print(json.dumps({
            "metadata": metadata,
            "toc": toc,
            "total_words": total_words,
            "chapter_count": len(chapters),
        }, ensure_ascii=False, indent=2))
        return

    # --- Search mode ---
    if args.search:
        results = search_chapters(chapters, args.search)
        print(json.dumps({
            "metadata": metadata,
            "query": args.search,
            "match_count": sum(len(r["matches"]) for r in results),
            "chapters_with_matches": len(results),
            "results": results,
        }, ensure_ascii=False, indent=2))
        return

    # --- Single chapter mode ---
    if args.chapter is not None:
        matching = [ch for ch in chapters if ch["index"] == args.chapter]
        if not matching:
            print(json.dumps({"error": f"Chapter {args.chapter} not found. Available: 0–{len(chapters)-1}"}))
            sys.exit(1)
        ch = matching[0]
        print(json.dumps({
            "metadata": metadata,
            "chapter": ch,
        }, ensure_ascii=False, indent=2))
        return

    # --- Full extraction (default) ---
    if args.max_chapters is not None:
        chapters = chapters[:args.max_chapters]

    print(json.dumps({
        "metadata": metadata,
        "toc": toc,
        "chapters": chapters,
        "total_words": total_words,
        "chapter_count": len(chapters),
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
