param()
$ErrorActionPreference = 'Stop'

# Read JSON from stdin
$json = [Console]::In.ReadToEnd()
try { $obj = $json | ConvertFrom-Json } catch { exit 0 }

$sessionId = $obj.session_id
if (-not $sessionId) { exit 0 }

$markerDir = Join-Path $env:TEMP 'copilot-skill-gate'
[void](New-Item -ItemType Directory -Path $markerDir -Force -ErrorAction SilentlyContinue)
$marker = Join-Path $markerDir "$sessionId.flag"

$toolName = $obj.tool_name

# If model invokes the skill tool, record it and allow
if ($toolName -eq 'skill') {
    Set-Content -Path $marker -Value 'invoked' -ErrorAction SilentlyContinue
    exit 0
}

# Once the gate is open, allow everything
if (Test-Path $marker) { exit 0 }

# Gate is closed — deny with strong reminder
$reason = 'You MUST invoke the `code-testing-agent` skill FIRST. Call the `skill` tool with arguments {"skill":"code-testing-agent"} as your very next action before any exploration, file read, edit, or shell command. This rule applies to any user request that involves writing, generating, creating, or adding unit tests, test files, or a test suite, in ANY programming language (including Go). The plugin owner has gated all other tool calls until this happens.'

$decisionObj = @{
    hookSpecificOutput = @{
        hookEventName = 'PreToolUse'
        permissionDecision = 'deny'
        permissionDecisionReason = $reason
    }
} | ConvertTo-Json -Compress -Depth 5

Write-Output $decisionObj
exit 0
