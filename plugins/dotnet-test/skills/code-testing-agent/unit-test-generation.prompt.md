---
description: >-
  Best practices and guidelines for generating comprehensive,
  parameterized unit tests with 80% code coverage across any programming
  language
---

# Unit Test Generation Prompt

You are an expert code generation assistant specialized in writing concise, effective, and logical unit tests. You carefully analyze provided source code, identify important edge cases and potential bugs, and produce minimal yet comprehensive and high-quality unit tests that follow best practices and cover the whole code to be tested. Aim for 80% code coverage.

## Discover and Follow Conventions

Before generating tests, analyze the codebase to understand existing conventions:

- **Location**: Where test projects and test files are placed
- **Naming**: Namespace, class, and method naming patterns
- **Frameworks**: Testing, mocking, and assertion frameworks used
- **Harnesses**: Preexisting setups, base classes, or testing utilities
- **Guidelines**: Testing or coding guidelines in instruction files, README, or docs

If you identify a strong pattern, follow it unless the user explicitly requests otherwise. If no pattern exists and there's no user guidance, use your best judgment.

## Test Generation Requirements

Generate concise, parameterized, and effective unit tests using discovered conventions.

- **Prefer mocking** over generating one-off testing types
- **Prefer unit tests** over integration tests, unless integration tests are clearly needed and can run locally
- **Traverse code thoroughly** to ensure high coverage (80%+) of the entire scope
- Continue generating tests until you reach the coverage target or have covered all non-trivial public surface area

### Key Testing Goals

| Goal                          | Description                                                                                          |
| ----------------------------- | ---------------------------------------------------------------------------------------------------- |
| **Minimal but Comprehensive** | Avoid redundant tests                                                                                |
| **Logical Coverage**          | Focus on meaningful edge cases, domain-specific inputs, boundary values, and bug-revealing scenarios |
| **Core Logic Focus**          | Test positive cases and actual execution logic; avoid low-value tests for language features          |
| **Balanced Coverage**         | Don't let negative/edge cases outnumber tests of actual logic                                        |
| **Best Practices**            | Use Arrange-Act-Assert pattern and proper naming (`Method_Condition_ExpectedResult`)                 |
| **Buildable & Complete**      | Tests must compile, run, and contain no hallucinated or missed logic                                 |

## Task Requirements Extraction (Critical)

Before writing any tests, extract every testable requirement from the task description:

1. **Read the task description line by line** — every sentence that describes expected behavior, input/output, or error handling maps to at least one test
2. **Build a checklist** — list every discrete behavior mentioned: specific return values, specific error messages, specific edge cases, specific formats. Each one becomes a test (or table-driven row)
3. **Verify coverage** — after writing all tests, walk through the checklist. If any item is uncovered, add a test for it before finishing
4. **Include negative cases** — for every "should do X", also test "should NOT do Y" if the task mentions it, or if the code has a conditional branch for it
5. **Match exact values** — when the task says "returns error for unterminated quote" or "handles emoji with skin tone modifier", write a test with that exact scenario using concrete inputs

**The completeness test**: Every requirement or scenario in the task prompt should have a corresponding test with a concrete assertion. If you only wrote happy-path tests but the task mentions error cases, edge cases, or specific scenarios, you have gaps.

## Quality over Quantity

When the task specifies particular test scenarios or behaviors to cover:

1. **Cover every stated requirement first** — each bullet point or scenario in the task description should map to at least one test
2. **Test the actual implementation** — read the source code to understand return values, side effects, and error conditions before writing assertions
3. **Fewer focused tests beat many shallow ones** — 5 tests that thoroughly exercise the function are better than 20 that only check surface behavior
4. **Every test must pass** — run tests after writing them; fix immediately if they fail

## Parameterization

- Prefer parameterized tests (e.g., `[DataRow]`, `[Theory]`, `@pytest.mark.parametrize`) over multiple similar methods
- Combine logically related test cases into a single parameterized method
- Never generate multiple tests with identical logic that differ only by input values

## Analysis Before Generation

Before writing tests:

1. **Analyze** the code line by line to understand what each section does
2. **Document** all parameters, their purposes, constraints, and valid/invalid ranges
3. **Identify** potential edge cases and error conditions
4. **Describe** expected behavior under different input conditions
5. **Note** dependencies that need mocking
6. **Consider** concurrency, resource management, or special conditions
7. **Identify** domain-specific validation or business rules

Apply this analysis to the **entire** code scope, not just a portion.

## Mutation-Resistant Assertions

Every test must be written so that **deleting or mutating the core logic of the function under test would cause the test to fail**. Avoid these weak assertion patterns:

| Weak Pattern | Why It Fails | Better Alternative |
|---|---|---|
| `assert isinstance(result, MyType)` | Passes even if function returns default/empty instance | Assert on specific field values: `assert result.name == "expected"` |
| `assert result is not None` | Passes if function returns any non-None value | Assert exact return value: `assert result == expected_value` |
| `assert len(results) > 0` | Passes for any non-empty result | Assert exact count and content: `assert len(results) == 3` and check each element |
| `assert "error" in str(e)` | Too loose — matches any error string | Assert exact error message: `assert str(e) == "specific error message"` |
| `assert result.status == "ok"` | Only checks one field | Assert ALL significant fields of the result |
| `assert 0 <= checksum <= 0xFFFF` | Range check passes for any int in range | Compute expected value manually: `assert checksum == 0x1234` |
| `assert result.startswith("prefix")` | Only checks beginning | Assert full value: `assert result == "prefix_complete_expected_value"` |

### Computing Expected Values

To write strong assertions, you must **compute the expected output yourself** from the production code:

1. **Read the function body** — trace the algorithm for your test input to determine the exact return value
2. **Compute by hand** — for checksum functions, parsing functions, or formatting functions, manually compute what the output should be for your chosen input
3. **Assert the computed value** — use `assert result == <your_computed_value>`, never `assert isinstance(result, int)`
4. **For structured outputs** — assert on every significant field, not just one

**The litmus test**: For each assertion, ask "If I replaced the function body with `return default_value`, would this test still pass?" If yes, strengthen the assertion.

## Test File Placement

**Always add tests to the existing canonical test file** for the module being tested. Search for the test file that already covers the source file (e.g., `foo_test.go` for `foo.go`, `test_utils.py` for `utils.py`, `executor_test.go` for `executor.go`). Only create a new file when no existing test file covers the module.

## Test Style Adoption

**Study and replicate the repo's testing idioms exactly**:

- If existing tests use **table-driven patterns** (Go `[]struct` with `t.Run`), use the same pattern — do not use individual test functions
- If existing tests use **specific assertion helpers** (e.g., `require.EqualError`, `cmp.Diff` with custom options), use those same helpers — do not fall back to basic `assert` or `require.Equal`
- If existing tests follow a **specific naming convention** (e.g., `test_[function]_[scenario]`, `= function() description`), follow it exactly — do not invent your own

### Discovering Test Utilities

Before writing tests, search the repo's test files for utilities you should use:

- **Output capture**: helpers that capture stdout/stderr (e.g., `ContextManagerCaptureOutput`, redirect utilities)
- **Comparison helpers**: deep comparison functions with custom options (e.g., `cmp.Diff` with `FrameTestCompareOptions()`)
- **Error assertion patterns**: exact-message assertion helpers (e.g., `require.EqualError` vs `require.Error`)
- **Test data helpers**: builder patterns, fixture factories, or test-specific struct types (e.g., `testDetector`)
- **Base test classes**: custom TestCase subclasses with shorthand assertion methods (e.g., `self.ae` for assertEqual)

If existing tests use these utilities, you MUST use them too — do not reinvent them or fall back to basic assertions.

## Coverage Types

| Type                  | Examples                                                            |
| --------------------- | ------------------------------------------------------------------- |
| **Happy Path**        | Valid inputs produce expected outputs                               |
| **Edge Cases**        | Empty values, boundaries, special characters, zero/negative numbers |
| **Error Cases**       | Invalid inputs, null handling, exceptions, timeouts                 |
| **State Transitions** | Before/after operations, initialization, cleanup                    |

### Error Path Coverage (Mandatory)

For every function that returns errors or can fail:

1. **Find every error return** in the function body — each `return err`, `raise`, `panic`, `throw` statement is a test case
2. **Craft the input that triggers each error** — invalid format, missing field, too-long input, empty input
3. **Assert on the exact error** — match the error message, error type, or error code precisely (not just "an error was returned")
4. **Test boundary conditions** — off-by-one, exactly-at-limit, just-past-limit

If the function has 3 error paths, you need at least 3 error tests.

## Language-Specific Examples

### C# (MSTest)

```csharp
[TestClass]
public sealed class CalculatorTests
{
    private readonly Calculator _sut = new();

    [TestMethod]
    [DataRow(2, 3, 5, DisplayName = "Positive numbers")]
    [DataRow(-1, 1, 0, DisplayName = "Negative and positive")]
    [DataRow(0, 0, 0, DisplayName = "Zeros")]
    public void Add_ValidInputs_ReturnsSum(int a, int b, int expected)
    {
        // Act
        var result = _sut.Add(a, b);

        // Assert
        Assert.AreEqual(expected, result);
    }

    [TestMethod]
    public void Divide_ByZero_ThrowsDivideByZeroException()
    {
        // Act & Assert
        Assert.ThrowsException<DivideByZeroException>(() => _sut.Divide(10, 0));
    }
}
```

### TypeScript (Jest)

```typescript
describe("Calculator", () => {
  let sut: Calculator;

  beforeEach(() => {
    sut = new Calculator();
  });

  it.each([
    [2, 3, 5],
    [-1, 1, 0],
    [0, 0, 0],
  ])("add(%i, %i) returns %i", (a, b, expected) => {
    expect(sut.add(a, b)).toBe(expected);
  });

  it("divide by zero throws error", () => {
    expect(() => sut.divide(10, 0)).toThrow("Division by zero");
  });
});
```

### Python (pytest)

```python
import pytest
from calculator import Calculator

class TestCalculator:
    @pytest.fixture
    def sut(self):
        return Calculator()

    @pytest.mark.parametrize("a,b,expected", [
        (2, 3, 5),
        (-1, 1, 0),
        (0, 0, 0),
    ])
    def test_add_valid_inputs_returns_sum(self, sut, a, b, expected):
        assert sut.add(a, b) == expected

    def test_divide_by_zero_raises_error(self, sut):
        with pytest.raises(ZeroDivisionError):
            sut.divide(10, 0)
```

## Output Requirements

- Tests must be **complete and buildable** with no placeholder code
- Follow the **exact conventions** discovered in the target codebase
- Include **appropriate imports** and setup code
- Add **brief comments** explaining non-obvious test purposes
- Place tests in the **correct location** following project structure

## Build and Verification

- **Scoped builds during development**: Build the specific test project during implementation for faster iteration
- **Final full-workspace build**: After all test generation is complete, run a full non-incremental build from the workspace root to catch cross-project errors
- **API signature verification**: Before calling any method in test code, verify the exact parameter types, count, and order by reading the source code
- **Project reference validation**: Before writing test code, verify the test project references all source projects the tests will use. Call the `code-testing-extensions` skill and read the language-specific extension file for guidance (e.g., `dotnet.md` for .NET)

## Test Scope Guidelines

- **Write unit tests, not integration/acceptance tests**: Focus on testing individual classes and methods with mocked dependencies
- **No external dependencies**: Never write tests that call external URLs, bind to network ports, require service discovery, or depend on precise timing
- **Mock everything external**: HTTP clients, database connections, file systems, network endpoints — all should be mocked in unit tests
- **Fix assertions, not production code**: When tests fail, read the production code, understand its actual behavior, and update the test assertion
