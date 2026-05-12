---
name: code-testing-agent
description: >-
  Generates comprehensive, workable unit tests for any programming language.
  Use when asked to generate tests, write unit tests, improve test coverage,
  add test coverage, or create test files. Supports C#, TypeScript, JavaScript,
  Python, Go, Rust, Java, and more. Produces tests that compile, pass, and
  follow project conventions.
  DO NOT USE FOR: running existing tests, executing dotnet test, applying
  test filters, detecting test platforms, or troubleshooting test execution
  (use run-tests for all of these).
license: MIT
---

# Code Testing Generation Skill

Generates comprehensive, workable unit tests for any programming language. This skill consolidates testing guidance — convention discovery, dependency analysis, test design, build/verify cycles, and failure-fix strategy — into one place. It does not prescribe an orchestration pipeline; you handle sequencing yourself, optionally delegating subtasks to generic subagents when the scope is large.

## When to Use This Skill

- Generate unit tests for an entire project or specific files
- Improve test coverage for existing codebases
- Create test files that follow project conventions
- Write tests that actually compile and pass
- Add tests for new features or untested code

## When Not to Use

- Running or executing existing tests (use the `run-tests` skill)
- Migrating between test frameworks (use migration skills)
- Writing tests specifically for MSTest patterns (use `writing-mstest-tests`)
- Debugging failing test logic in pre-existing tests

## Default Conventions

When the user does not express strong requirements for test style, coverage goals, or conventions, source the guidelines from [unit-test-generation.prompt.md](unit-test-generation.prompt.md). It covers: convention discovery, parameterization strategies, the 80% coverage target, Arrange/Act/Assert pattern, and language-specific patterns.

## Language-Specific Guidance

Read the relevant file from `extensions/` next to this skill **before writing any test code**. These files contain critical build commands, project registration steps, error-code references, and language templates:

- [extensions/dotnet.md](extensions/dotnet.md) — .NET (C#/F#/VB): build/test commands, project reference validation, CS error codes, MSTest template, solution registration, coverage tool guidance
- [extensions/dotnet-examples.md](extensions/dotnet-examples.md) — .NET concrete examples: sample research output, sample plan, generated test file, fix cycle walkthrough, final report
- [extensions/cpp.md](extensions/cpp.md) — C++: testing internals via friend declarations

If no extension exists for the target language, use your best judgement and knowledge.

## Scope Size and Subagent Delegation

Pick an execution approach based on scope.

| Scope | Approach |
|-------|----------|
| **Small** — single function, class, or file | Write tests directly. Read the source, write tests, build, run, fix. No delegation needed. |
| **Moderate** — a handful of related files in one module | Delegate codebase exploration (locating files, finding existing test patterns) to a subagent to keep your context lean. |
| **Large** — whole project, many modules, or coverage target across a solution | Decompose into independent subtasks. Delegate read-only research and discrete per-module test generation to subagents, then integrate their results. See below. |

In general - whenever you find yourself filling your context (due to need to process larger amount of code, larger build or test outputs etc.) or you suspect it might be happening - opt for delegation to a subagent. You can always reintegrate results in the main thread and run a final validation pass to ensure quality and consistency.

Suitable subtasks for delegation include:

- **Discovery** (read-only) — "Locate all public types in `src/Foo` and return a prioritized list of files needing tests, with their dependencies." Run in parallel for independent areas.
- **Per-module test generation** — "Generate MSTest tests for every public method in `Bar.Service`, following patterns in `tests/Bar.Tests`. Build and run the test project. Report which tests pass/fail."
- **Targeted fix passes** — "Build `Foo.Tests.csproj` and fix any CS-error compilation failures in the test files only."

Keep delegations independent so they can run without coordination. Reintegrate results in the main thread: run a final full-workspace build and test pass yourself (see [Final Validation](#final-validation)) — never delegate that step.

## Test Generation Workflow

Follow these steps in order. For small scopes most steps collapse into "read code, write tests, run them."

### 1. Understand the Request

Clarify scope (single file, module, full project), priority areas, and framework preferences. If the user gave a basic prompt like "generate tests", default to the conventions in [unit-test-generation.prompt.md](unit-test-generation.prompt.md).

### 2. Discover Conventions and Commands

Search the codebase for:

- **Project files** identifying the language and build system: `*.csproj`, `*.sln`, `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `*.vcxproj`
- **Existing tests** showing the testing framework, assertion style, naming conventions, mocking library, and base classes: `*Test*`, `*Tests*`, `*spec*`
- **Build/test commands** in `README.md`, `Makefile`, `package.json` scripts, and CI config
- **Project conventions** in `.editorconfig`, instruction files, and surrounding code

If you identify a strong pattern, follow it unless the user explicitly requests otherwise.

### 3. Analyze the Code Under Test

For each file in scope:

- **Read the entire source file** — never write tests based on function names or signatures alone
- Identify public classes, methods, and their exact parameter types, count, return types, and **actual return values for representative inputs**
- Trace each code path you plan to test — understand what the function actually does, not what you assume it should do
- Note dependencies and how to mock them

#### Build a Dependency Graph

- **Find interfaces and implementations** in scope
- **Identify leaf types** — classes whose only dependencies are external/framework types
- **Test leaves first** — they need no mocking
- **Layer up with mocks** — for types above leaves, mock their leaf dependencies and test the layer's own logic in isolation

#### Estimate Existing Coverage

For each source file in scope, estimate coverage based on: presence of a matching test file, number of test methods vs. public methods, and whether tests cover only happy paths or also edge/error cases. Use this to prioritize: prefer completely untested files, then partially tested files with complex logic.

### 4. Choose a Test Design Strategy

| Existing coverage | Strategy |
|-------------------|----------|
| Most files untested or unknown | **Broad**: generate tests for every public class/method, organized by dependency-graph layer (leaves first), simple files first |
| Most files well tested | **Targeted**: focus on untested and partially tested files with complex logic |

For each file, plan the specific test cases up front:

- **Happy path** — valid inputs produce expected outputs
- **Edge cases** — empty values, boundaries, special characters, zero/negative numbers
- **Error cases** — invalid inputs, null handling, exceptions
- **State transitions** — before/after operations where relevant

### 5. Set Up the Test Project

- **Reuse existing test projects** — new tests for code X go into the existing test project that covers X. Do not create a parallel test project.
- **Create a test project only if none exists** for the target code
- **Create necessary directories and files if none exists** for the target code
- **Validate project references** — read the test `.csproj` (or equivalent) and verify it references the source projects you'll test; add missing references before writing test code
- **Register new test projects** with the solution/build system so the test runner can discover them — see the language extension file (e.g., [extensions/dotnet.md](extensions/dotnet.md) "Registering a new test project")

### 6. Write the Tests

- Follow the project's discovered patterns (file location, namespace, class naming, test naming `Method_Condition_ExpectedResult`)
- Use the framework's parameterization features (`[DataRow]`, `[Theory]`, `@pytest.mark.parametrize`, `it.each`) instead of duplicating test methods
- **Mock everything external** — HTTP clients, databases, file systems, network endpoints, timing-dependent code
- **Never write environment-dependent tests** — no external URLs, port bindings, real network calls, or wall-clock dependencies
- **Assert on concrete values** — each test should assert specific return values or observable state; a test that would still pass if the function body were empty does not earn its place

### 7. Build, Run, and Fix

Use **scoped builds and test runs** during development for speed: build the specific test project, run only the tests you added.

When the build fails:

- Read the error code (CS####, TS####, etc.) — the language extension lists common ones with fixes
- Common patterns:
  - Missing namespace/import: add `using`/`import` or add a missing `<ProjectReference>`
  - Missing member (CS1061, TS2339): re-read the source to verify the exact name
  - Type mismatch: re-read the source to verify the exact signature
  - Missing required parameter (CS7036): re-read the constructor/method signature and pass all required args
- Fix one issue at a time, rebuild, repeat (up to ~3 cycles before reassessing the approach)

When tests fail:

- Read the actual output (expected vs. actual), then read the production code to determine correct behavior, then fix the assertion
- For async/event-driven tests, add explicit waits before asserting
- Never mark a test `[Ignore]`, `[Skip]`, `[Inconclusive]`, `it.skip`, `@pytest.mark.skip`, etc. to make a suite "pass"
- Retry the fix-test cycle up to ~5 times per test before escalating

### 8. Final Validation

After all tests are written and passing in scoped runs, do **not** skip final validation — even for small scopes:

- **Full-workspace build, non-incremental.** This catches cross-project errors invisible to scoped builds (including multi-target framework issues):
  - .NET: `dotnet build MySolution.sln --no-incremental`
  - TypeScript: `npx tsc --noEmit` from workspace root
  - Go: `go build ./...`
  - Rust: `cargo build`
- **Full-workspace test run** with a fresh build (never `--no-build` for final validation)
- **Pre-existing failing tests**: note them in the report but do not let them block; only newly-generated test failures must be fixed
- **Do not collect coverage** — coverage measurement is not the agent's responsibility and the tools have inconsistent behavior across configurations
- **Format**: run the project's formatter if available (e.g., `dotnet format --include path/to/file.cs`, `prettier --write`, `black`, `gofmt`)

### 9. Coverage Gap Check

List all source files in scope, list all test files now present, and identify any source files still uncovered. Generate tests for those, repeat the build/run/fix cycle, and stop when every non-trivial public surface area is covered or all reasonable targets are exhausted.

### 10. Report

Summarize:

- Tests created (count)
- Tests passing / failing
- Files created
- Build validation result (scoped + full-solution)
- Any unresolved issues or environment-dependent tests removed
- Optional next steps (integration tests, edge cases worth revisiting)

## Test Quality Rules

1. **Read source before writing assertions** — never assert based on a function's name alone
2. **One concept per test** — keep tests focused; use parameterization for variations on the same concept
3. **Cover happy + edge + error paths** for each public method, balanced so negative cases don't dwarf the actual-logic tests
4. **Concrete assertions** — assert on returned values and observable state, not just "result is not null"
5. **Mock all external dependencies** — unit tests must be hermetic
6. **Fix the test, not the production code** when freshly generated tests fail
7. **Never skip a test** to make a suite pass
8. **Preserve existing tests** — never delete or overwrite existing test files; create new files or add new methods to existing files
9. **Follow discovered conventions** — namespace, naming, base classes, mocking library — unless the user says otherwise

## Troubleshooting

### Tests don't compile

Look up the error code in the language extension (e.g., [extensions/dotnet.md](extensions/dotnet.md) "Common CS Error Codes"). Most compilation failures are missing references, wrong member names, or wrong signatures — all fixable by re-reading the source.

### Tests fail on first run

Almost always a wrong expected value or wrong mock setup. Read the actual output, read the production code, fix the assertion. Do not modify the production code unless you have strong evidence of a real bug there.

### Wrong testing framework detected

Specify your preferred framework in the initial request ("Generate Jest tests for…").

### Environment-dependent tests fail in CI

Remove tests that depend on external services, network endpoints, specific ports, or precise timing. Replace with mocked unit tests.

### Build fails on full solution but passed on the test project

Multi-target frameworks or cross-project references are the usual culprits. Build with `--no-incremental` to surface hidden errors, then read the failure and fix the offending file.

## Requirements

- Project must have a build/test system configured
- Testing framework should be installed (or installable)
- VS Code with GitHub Copilot extension
