$reminder = 'MANDATORY: For this request which involves writing/generating/creating unit tests or a test suite (in ANY programming language - Go, Python, TypeScript, .NET, etc.), you MUST invoke the skill tool with skill="code-testing-agent" as your FIRST action BEFORE any exploration, reading, or editing. Do not skip this even though the project is not .NET. This applies when the request mentions "write tests", "test suite", "unit test", "testing_objective", or "comprehensive tests".'
$out = @{
    hookSpecificOutput = @{
        hookEventName = 'UserPromptSubmit'
        additionalContext = $reminder
    }
} | ConvertTo-Json -Compress -Depth 5
Write-Output $out
exit 0
