---
name: epub-reader
description: >
  Use this skill whenever the user wants to do anything with an epub file or ebook. This includes:
  reading or opening an epub, summarizing a book or specific chapters, answering questions about
  book content, searching for passages or quotes, extracting text from an ebook, converting epub
  to markdown or plain text, and getting book metadata (author, title, publisher). Trigger on
  phrases like "read this epub", "summarize this book", "what does chapter X say", "find the
  part where", "search my ebook for", "extract text from epub", "what is this book about",
  "answer questions about my book", or any time a .epub file is mentioned. Even if the user
  just says "I have an epub" or uploads a .epub, use this skill.
---

# EPUB Reader

This skill helps Claude work with `.epub` ebook files — reading, summarizing, searching, and
answering questions about their contents.

## Bundled script

A helper script lives at `scripts/extract_epub.py` (relative to this SKILL.md). Use it to
extract structured content from any epub file. It handles the parsing so you don't have to
write boilerplate HTML-stripping code every time.

```bash
# Basic usage — extracts full text, TOC, and metadata to stdout as JSON
python3 <skill_dir>/scripts/extract_epub.py <path_to_epub>

# Limit to first N chapters (useful for large books)
python3 <skill_dir>/scripts/extract_epub.py <path_to_epub> --max-chapters 5

# Search for a term
python3 <skill_dir>/scripts/extract_epub.py <path_to_epub> --search "search term"

# Extract a single chapter by index (0-based)
python3 <skill_dir>/scripts/extract_epub.py <path_to_epub> --chapter 2
```

The script outputs JSON with this shape:
```json
{
  "metadata": { "title": "...", "author": "...", "publisher": "...", "language": "..." },
  "toc": ["Chapter 1: ...", "Chapter 2: ..."],
  "chapters": [
    { "index": 0, "title": "Chapter 1", "text": "...", "word_count": 3200 }
  ],
  "total_words": 85000
}
```

When searching, chapters will have a `"matches"` key with snippets around each match.

## Locating the skill directory

The skill directory path is the directory that contains this SKILL.md file. In Claude Code,
you can find it from the skill path in your system prompt. In Cowork, it will be in a temp
folder. Store it in a variable so you can reference it throughout:

```bash
SKILL_DIR="<path to epub-reader skill folder>"
python3 "$SKILL_DIR/scripts/extract_epub.py" "$EPUB_PATH"
```

## Handling file input

**In Claude Code**: The user will typically give you a file path like `~/Books/dune.epub` or
`./my-book.epub`. Expand `~` and resolve relative paths before passing to the script.

**In Cowork**: Uploaded files land in the uploads directory. Use the Read tool to check what's
there, or ask the user for the file path. The script accepts any absolute path.

If the epub path is ambiguous or missing, ask the user to confirm the path before proceeding.

## Workflow by task type

### Summarizing a book or chapter

1. Run the script to extract the full text (or a specific chapter with `--chapter N`).
2. For a full book summary: read the TOC and the first ~500 words of each chapter to build
   a high-level map, then write a cohesive summary. You don't need to read every word —
   chapter openings carry most of the structural meaning.
3. For a chapter summary: extract that chapter and summarize in full.
4. Format: lead with a one-paragraph overview, then key themes or chapter-by-chapter breakdown
   if the user asked for detail.

### Answering questions about book content

1. First run with `--search "<key terms from the question>"` to locate the relevant section(s).
2. If the search returns useful matches, read those passages carefully and answer.
3. If the search comes up empty, fall back to extracting the relevant chapters by index and
   reading them directly.
4. Always cite where in the book you found the answer (chapter name or approximate location).

### Searching for passages or quotes

1. Use `--search "the phrase or term"` — the output will include surrounding context for each
   match.
2. Present each match with: chapter name, a short excerpt showing the match in context, and
   the chapter index.
3. If the search term is a fuzzy description (e.g., "the scene where the hero meets the villain"),
   extract the most likely chapters and skim them yourself.

### Converting to markdown or plain text

1. Run the script to extract all chapters.
2. Assemble the content: metadata block at the top, then each chapter as a markdown section
   (`## Chapter Title`), then the chapter text.
3. Save the output to a file (e.g., `<book_title>.md`) and provide a link. If the user asked
   for plain text, use `.txt` and skip markdown headers.

## Output format guidance

- **Summaries**: prose paragraphs, no bullet points unless the user asks. Aim for 200–400 words
  for a full book summary; adjust for chapter summaries.
- **Q&A**: answer directly, then quote the relevant passage(s) as a blockquote. Keep quotes
  tight — 2–5 sentences is usually enough.
- **Search results**: list each match with chapter context. If there are many hits, show the
  top 5 and offer to show more.
- **Saving to file**: always save to the workspace folder and provide a `computer://` link so
  the user can open it directly.

## Large books

If the epub has more than ~30 chapters or the total word count exceeds ~150,000 words, be
strategic:
- For summaries, use `--max-chapters` to process in passes rather than loading everything at once.
- For Q&A, rely on search first; only load full chapters when search is insufficient.
- Let the user know if you're only summarizing a portion and ask if they want more.

## Dependencies

The script uses `ebooklib` and `beautifulsoup4`, both of which are typically pre-installed.
If they're missing, install them:

```bash
pip install ebooklib beautifulsoup4 --break-system-packages -q
```
