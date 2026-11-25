# Helper partage: configuration locale des URL Jira et Confluence (dot-source uniquement).
# Le fichier config.json vit dans le profil utilisateur, a cote du PAT sous Windows, et n'est jamais versionne.

function Get-JiraSkillConfigDirectory {
    if ($env:OS -eq 'Windows_NT') {
        return Join-Path $env:LOCALAPPDATA 'AntaresAI\JiraDirectApi'
    }
    $configHome = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME '.config' }
    return Join-Path $configHome 'AntaresAI/JiraDirectApi'
}

function ConvertTo-RteBaseUrl {
    param(
        [Parameter(Mandatory = $true)] [string] $Value,
        [Parameter(Mandatory = $true)] [string] $Label
    )

    $uri = $null
    if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -ne 'https' -or
        -not ($uri.Host -eq 'rte-france.com' -or $uri.Host.EndsWith('.rte-france.com')) -or
        $uri.UserInfo -or $uri.Query -or $uri.Fragment -or $uri.AbsolutePath -ne '/') {
        throw "$Label refusee: attendu une URL https://<hote>.rte-france.com, sans chemin ni identifiants. Le PAT ne sera jamais envoye hors de rte-france.com."
    }
    return $uri.GetLeftPart([UriPartial]::Authority)
}

function Save-JiraSkillConfig {
    param(
        [Parameter(Mandatory = $true)] [string] $JiraBaseUrl,
        [Parameter(Mandatory = $true)] [string] $ConfluenceBaseUrl
    )

    $directory = Get-JiraSkillConfigDirectory
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $json = [pscustomobject]@{
        jiraBaseUrl       = $JiraBaseUrl
        confluenceBaseUrl = $ConfluenceBaseUrl
    } | ConvertTo-Json
    [IO.File]::WriteAllText((Join-Path $directory 'config.json'), $json, [Text.UTF8Encoding]::new($false))
}

function Get-JiraSkillConfig {
    $path = Join-Path (Get-JiraSkillConfigDirectory) 'config.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Configuration des URL absente. Lancer scripts/configure-jira-pat.ps1 -JiraUrl <url-jira> -ConfluenceUrl <url-confluence> (les URL sont demandees au PO, sans secret)."
    }
    $config = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    return [pscustomobject]@{
        JiraBaseUrl       = ConvertTo-RteBaseUrl -Value ([string]$config.jiraBaseUrl) -Label 'URL Jira de config.json'
        ConfluenceBaseUrl = ConvertTo-RteBaseUrl -Value ([string]$config.confluenceBaseUrl) -Label 'URL Confluence de config.json'
    }
}
