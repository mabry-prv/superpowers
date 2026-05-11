# Fixture: clean per-task implementation

## SCOPE

per-task

## DESCRIPTION

Added a `parse_csv_line(line: str) -> list[str]` helper with tests.

## PLAN_OR_REQUIREMENTS

Task 1: Add `parse_csv_line` in `lib/csv.py`. Handle quoted fields with embedded commas. Add tests covering: simple line, line with quoted field, line with empty fields.

## DIFF (BASE → HEAD)

```python
# lib/csv.py (new file)
import csv
from io import StringIO

def parse_csv_line(line: str) -> list[str]:
    return next(csv.reader(StringIO(line)))
```

```python
# tests/test_csv.py (new file)
import pytest
from lib.csv import parse_csv_line

def test_simple():
    assert parse_csv_line("a,b,c") == ["a", "b", "c"]

def test_quoted_field_with_comma():
    assert parse_csv_line('a,"b,c",d') == ["a", "b,c", "d"]

def test_empty_fields():
    assert parse_csv_line("a,,c") == ["a", "", "c"]
```

## EXPECTED VERDICT

APPROVED — three tests cover the spec'd cases, single-responsibility file, idiomatic use of stdlib `csv`. Ready to merge.
