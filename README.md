# Latte compiler

## Language extensions
- arrays
- classes with inheritance and virtual methods
- null implicitly converts to any array and to any class

## Language semantics
- variables namespace is independent of the functions (and methods) namespace, e.g. (accepted code):
```latte
int foo() { return 42; }
int main() {
    int foo = 3;
    if (foo() + foo != 45) error();
    return 0;
}
```
- field shadowing is not possible, e.g. (rejected code):
```latte
class X {
    int x;
}
class Y extends X {
    string x;
}
int main() {
    return 0;
}
```

## Tests
Tests comprehensively cover language construct, type conversions and required static analysis. Some tests reflect chosen language semantics, thus compilers implementing other interpretations may not pass them.

Tests are not divided into ones categories based on which extensions they require.
Test folder structure:
- `good/` -- tests that present correct programs
- `bad/` -- tests that present incorrect programs
- `warnings/` -- tests that present programs producing diagnostic warnings
