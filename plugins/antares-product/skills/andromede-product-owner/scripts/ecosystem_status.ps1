# This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
# If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
# Show freshness of the local Andromede ecosystem clones and their doc entry points.
# PowerShell port of ecosystem_status.sh, same output; runs on Windows PowerShell 5.1 and PowerShell 7 (Windows/Linux/macOS).
# Usage: ecosystem_status.ps1 [-Fetch] [[-Root] ROOT]
#   -Fetch  run `git fetch` (read-only for the working tree) before computing commits behind origin's default branch
#   ROOT    directory holding the clones (default: $env:ANDROMEDE_ROOT or the current directory)
[CmdletBinding()]
param(
    [switch] $Fetch,

    [Parameter(Position = 0)]
    [string] $Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Root) { $Root = if ($env:ANDROMEDE_ROOT) { $env:ANDROMEDE_ROOT } else { (Get-Location).Path } }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'git not found in PATH' }

$repos = @(
    'GEMS', 'GemsPy', 'GEMS-ViewsBuilder', 'Antares_Simulator', 'antares-xpansion', 'antares_craft', 'AntaREST',
    'antares-launcher', 'antares-doc', 'antares-datamanager-front', 'antares-datamanager-back',
    'antares-datamanager-generator', 'AntaresLegacyModels-to-GEMS-Converter', 'PyPSA-to-GEMS-Converter'
)

# Run git in a repo and return its non-empty stdout lines (empty array on failure).
# ErrorActionPreference is relaxed locally: Windows PowerShell 5.1 turns native stderr into terminating errors under 'Stop'.
function Invoke-Git {
    param([string] $Repo, [string[]] $GitArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & git -C $Repo @GitArgs 2>$null
        if ($LASTEXITCODE -ne 0) { return , @() }
        return , @($out | Where-Object { $_ })
    }
    finally { $ErrorActionPreference = $prev }
}

function Get-FirstLine([string[]] $Lines) { if ($Lines.Count -gt 0) { $Lines[0] } else { '' } }

$fmt = '{0,-38} {1,-26} {2,-11} {3,-8} {4,-6} {5}'
Write-Output ($fmt -f 'REPO', 'BRANCH', 'LAST_COMMIT', 'BEHIND', 'DIRTY', 'DOCS')
foreach ($r in $repos) {
    $d = Join-Path $Root $r
    # Test-Path, not a directory test: .git is a file in worktrees and submodules.
    if (-not (Test-Path -LiteralPath (Join-Path $d '.git'))) {
        Write-Output ('{0,-38} {1}' -f $r, "NOT CLONED -> git clone https://github.com/AntaresSimulatorTeam/$r.git $d")
        continue
    }
    $branch = Get-FirstLine (Invoke-Git $d @('rev-parse', '--abbrev-ref', 'HEAD'))
    $last = Get-FirstLine (Invoke-Git $d @('log', '-1', '--format=%cs'))
    if ($Fetch) { $null = Invoke-Git $d @('fetch', '--quiet', 'origin') }
    # "behind" is measured against the remote DEFAULT branch (origin/HEAD), not the checked-out branch's upstream,
    # so a clone sitting on a feature branch is still reported correctly and flagged with a leading '*'.
    $default = Get-FirstLine (Invoke-Git $d @('symbolic-ref', '--quiet', '--short', 'refs/remotes/origin/HEAD'))
    $behind = '-'
    if ($default) {
        $behind = Get-FirstLine (Invoke-Git $d @('rev-list', '--count', "HEAD..$default"))
        if ("origin/$branch" -ne $default) { $branch = "*$branch" }
    }
    $dirty = (Invoke-Git $d @('status', '--porcelain')).Count
    # Markdown files tracked under docs/ or doc/ (git pathspec '*' also matches subfolders), as in the bash version.
    $docs = ''
    foreach ($p in 'docs', 'doc') {
        if (Test-Path -LiteralPath (Join-Path $d $p) -PathType Container) {
            $docs = "$p/ ($((Invoke-Git $d @('ls-files', '--', "$p/*.md")).Count) md)"
        }
    }
    if (-not $docs) { $docs = 'none' }
    Write-Output ($fmt -f $r, $branch, $last, $behind, $dirty, $docs)
}
Write-Output ''
Write-Output "'*' = not on the remote default branch: read files with 'git -C <repo> show <default>:<path>' and say so."
Write-Output 'BEHIND = commits on the remote default branch missing from HEAD (run with -Fetch for fresh numbers).'
