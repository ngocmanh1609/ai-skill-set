# Stack pack: Python (Django, FastAPI, Flask, libraries)

Failure modes are read on every review (review-guide § Failure modes). Seed conventions
are read only during setup. A project rule, an "Enforced by tooling" line, or a
"Don't flag" entry that checks the same behavior drops the matching pack line. A
project rule that checks only part of a line leaves the rest in force.

**Detect:** `pyproject.toml`, `setup.cfg`, or `requirements*.txt`. Runner: `uv run`, `poetry run`, or plain, per the lockfile.

**Checks:**
- analyze: `ruff check {files}` (or `flake8`), plus `mypy {files}` / `pyright` if configured
- test: `pytest {tests}`
- test_for: `{ from: '(src/)?(.*)/([^/]*)\.py', to: 'tests/$2/test_$3.py' }` (adjust to the project layout)

**ignore_paths:** `poetry.lock`, `uv.lock`, `**/migrations/*.py` (review by hand only if the PR is about the schema), `**/*_pb2.py`, `**/__snapshots__/**`

**Failure modes:**
- A function argument defaults to a mutable list or dict — grep: 'def [a-z_0-9]+\(.*=[ ]*(\[\]|\{\})'
- A bare `except:` or `except Exception` swallows the error — grep: 'except[ ]*:|except Exception[ ]*:'
- SQL is built with an f-string or `%` from input — grep: '(execute|raw)\(f['"]'
- A query loop loads a relation per row where `select_related` or `prefetch_related` belongs
- `async def` calls a blocking client (`requests`, `time.sleep`, a sync database driver)
- A secret is logged, or `DEBUG=True` or permissive CORS is set where production settings are read
- A model change has no migration in the same PR
- A `copy` or `model_copy` drops a field a reader still uses

**Seed conventions:**
- New public functions have type hints if the project type-checks
