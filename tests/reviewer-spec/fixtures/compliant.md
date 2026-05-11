# Fixture: compliant per-task implementation

## TASK_REQUIREMENTS

Task 1: Add a function `greet(name: str) -> str` in `lib/greet.py` that returns `f"Hello, {name}!"`. Add a passing test in `tests/test_greet.py`.

## IMPLEMENTER_REPORT

Implemented `greet` in `lib/greet.py:1-2`. Added `test_greet_basic` in `tests/test_greet.py:1-4`. All tests pass.

## FILES_TO_REVIEW

```python
# lib/greet.py
def greet(name: str) -> str:
    return f"Hello, {name}!"
```

```python
# tests/test_greet.py
from lib.greet import greet

def test_greet_basic():
    assert greet("world") == "Hello, world!"
```

## EXPECTED VERDICT

✅ Spec compliant
