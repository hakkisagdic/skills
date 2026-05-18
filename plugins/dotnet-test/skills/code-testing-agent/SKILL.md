---
name: code-testing-agent
description: >-
  USE THIS SKILL FIRST whenever the user asks to write, generate, author, create, or add
  unit tests, test files, a test suite, or comprehensive tests in ANY programming language
  (Go, C#, Python, TypeScript, JavaScript, Java, Rust, C++, F#, VB, and more).
  Strong triggers: "write tests", "generate tests", "create a test suite", "write comprehensive tests",
  "unit test", "testing objective", "test coverage", "add tests", "Write N unit tests".
  Also applies to SWE-bench / benchmark-style tasks that include a <testing_objective> block,
  a run_script, or instructions to write a TEST_MANIFEST. The skill is language-agnostic — do not
  skip it because the project is Go, Python, or anything other than .NET; the underlying
  pipeline supports every language.
  DO NOT USE FOR: only running existing tests (use run-tests); only fixing MSTest-specific
  assertions or modernising MSTest patterns (use writing-mstest-tests); migrating between
  test frameworks (use migration skills).
license: MIT
---

# Code Testing Generation Skill

An AI-powered skill that generates comprehensive, workable unit tests for any programming language using a coordinated multi-agent pipeline.

## When to Use This Skill

Use this skill when you need to:

- Generate unit tests for an entire project or specific files or functions
- Improve test coverage for existing codebases
- Create test files that follow project conventions
- Write tests that actually compile and pass
- Add tests for new features or untested code

## When Not to Use

- Running or executing existing tests (use the `run-tests` skill)
- Migrating between test frameworks (use migration skills)
- Writing tests specifically for MSTest patterns (use `writing-mstest-tests`)
- Debugging failing test logic

## Step-by-Step Instructions

### Step 1: Determine the user request

Make sure you understand what user is asking and for what scope.
When the user does not express strong requirements for test style, coverage goals, or conventions, source the guidelines from [unit-test-generation.prompt.md](unit-test-generation.prompt.md). This prompt provides best practices for discovering conventions, parameterization strategies, coverage goals (aim for 80%), and language-specific patterns.

### Step 2: Determine scope and strategy

A small, self-contained request (e.g., tests for a single function or class) that you can complete without sub-agents should use the **Direct** strategy:

 - Follow the codebase conventions on test file structure, naming, style and testing approaches.
 - Reuse existing test projects and test files when possible. If the code under test already has tests, add new tests to the same file or test project. Only create a new test file when no canonical file is named or discoverable for the symbol under test.
 - Write the tests directly, then run them right away. If any test fails, read the production code, fix the assertion, and re-run before writing more tests.

You can skip rest of this skill for the Direct strategy.

For moderate or large scopes (you need to author tests for more than a single file, module, or class) proceed by calling the `code-testing-generator` agent with your test generation request:

```
task({ agent_type: "dotnet-test:code-testing-generator", name: "generator", prompt: "..." })
```

Sample prompt (make sure to pass full path to 'unit-test-generation.prompt.md' if you want to pass it as part of the prompt - as agent doesn't have access to your referencess and will not know how to find it otherwise):

```text
Generate unit tests for [path or description of what to test], following the [unit-test-generation.prompt.md](unit-test-generation.prompt.md) guidelines
```

The Test Generator will manage the entire pipeline automatically.

### Note on calling the code-testing subagents

The `code-testing` agents is a cascade of agents that will direct you to call each other. Make sure to call them as subagents (`task({ agent_type: "dotnet-test:code-testing...", ... })`)
