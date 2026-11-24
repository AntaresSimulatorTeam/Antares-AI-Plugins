[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Url,

    [Parameter(Mandatory = $true)]
    [string] $OutputPath
)

$ErrorActionPreference = 'Stop'
$confluenceHost = 'gopro-collaboratif.rte-france.com'
$confluenceBaseUrl = "https://$confluenceHost"

if ($env:OS -eq 'Windows_NT') {
    $platform = 'Windows'
}
elseif ($PSVersionTable.PSEdition -eq 'Core' -and $IsLinux) {
    $platform = 'Linux'
}
else {
    throw 'Cette skill prend en charge Windows et Linux uniquement.'
}

$uri = $null
if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri) -or
    $uri.Scheme -ne 'https' -or $uri.Host -ne $confluenceHost) {
    throw "URL refusee: seules les pages https://$confluenceHost sont lues, pour ne pas envoyer le PAT ailleurs."
}

$queryParams = @{}
foreach ($pair in $uri.Query.TrimStart('?').Split('&', [StringSplitOptions]::RemoveEmptyEntries)) {
    $parts = $pair.Split('=', 2)
    $queryParams[[Net.WebUtility]::UrlDecode($parts[0])] = if ($parts.Count -gt 1) { [Net.WebUtility]::UrlDecode($parts[1]) } else { '' }
}

$pageId = $null
$spaceKey = $null
$pageTitle = $null
if ($queryParams.ContainsKey('pageId')) {
    $pageId = $queryParams['pageId']
}
elseif ($uri.AbsolutePath -match '/pages/(\d+)') {
    $pageId = $Matches[1]
}
elseif ($uri.AbsolutePath -match '^/display/([^/]+)/([^/]+)$') {
    $spaceKey = [Net.WebUtility]::UrlDecode($Matches[1])
    $pageTitle = [Net.WebUtility]::UrlDecode($Matches[2].Replace('+', ' '))
}
if ([string]::IsNullOrWhiteSpace($pageId) -and [string]::IsNullOrWhiteSpace($spaceKey)) {
    throw 'URL Confluence non reconnue: attendu pageId=<id>, /pages/<id>/... ou /display/<ESPACE>/<Titre>.'
}

$token = $null
$nativeBuffer = [IntPtr]::Zero
try {
    if ($platform -eq 'Windows') {
        $credentialPath = Join-Path $env:LOCALAPPDATA 'AntaresAI\JiraDirectApi\jira-pat.dpapi'
        if (-not (Test-Path -LiteralPath $credentialPath -PathType Leaf)) {
            throw 'PAT absent. Configurer le PAT avec scripts/configure-jira-pat.ps1; ne jamais le fournir dans le chat.'
        }
        $encryptedToken = (Get-Content -LiteralPath $credentialPath -Raw -Encoding ASCII).Trim()
        $secureToken = ConvertTo-SecureString -String $encryptedToken
        $nativeBuffer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
        $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($nativeBuffer)
    }
    else {
        $secretTool = Get-Command 'secret-tool' -ErrorAction SilentlyContinue
        if ($null -eq $secretTool) {
            throw "Le stockage Linux du PAT requiert 'secret-tool' (libsecret-tools) et un trousseau Secret Service accessible."
        }
        $tokenOutput = & $secretTool.Source lookup service AntaresAI account JiraDirectApi 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw 'PAT absent ou trousseau Secret Service inaccessible. Configurer le PAT avec scripts/configure-jira-pat.ps1.'
        }
        $token = (@($tokenOutput) -join "`n").TrimEnd("`r", "`n")
    }
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw 'PAT vide; le reconfigurer avec scripts/configure-jira-pat.ps1.'
    }

    $headers = @{
        Authorization = "Bearer $token"
        Accept        = 'application/json'
    }
    $expand = 'expand=body.storage,version'
    # Windows PowerShell 5.1 decodes JSON responses as Latin-1 when no charset is sent: decode the raw bytes as UTF-8 instead.
    function Invoke-ConfluenceGet([string] $requestUri) {
        $response = Invoke-WebRequest -Uri $requestUri -Headers $headers -UseBasicParsing -TimeoutSec 45
        $json = [Text.Encoding]::UTF8.GetString($response.RawContentStream.ToArray())
        return ($json | ConvertFrom-Json)
    }
    try {
        if (-not [string]::IsNullOrWhiteSpace($pageId)) {
            $page = Invoke-ConfluenceGet "$confluenceBaseUrl/rest/api/content/$([uri]::EscapeDataString($pageId))?$expand"
        }
        else {
            $query = "spaceKey=$([uri]::EscapeDataString($spaceKey))&title=$([uri]::EscapeDataString($pageTitle))&$expand&limit=2"
            $search = Invoke-ConfluenceGet "$confluenceBaseUrl/rest/api/content?$query"
            $results = @($search.results)
            if ($results.Count -ne 1) {
                throw "Page introuvable ou ambigue pour l'espace '$spaceKey' et le titre '$pageTitle' ($($results.Count) resultat(s))."
            }
            $page = $results[0]
        }
    }
    catch {
        $statusCode = $null
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        if ($statusCode) {
            throw "Lecture Confluence refusee ou page introuvable (HTTP $statusCode). Verifier l'URL et que le compte du PAT peut voir la page."
        }
        throw "Lecture Confluence en echec: $($_.Exception.Message)"
    }

    $html = [string]$page.body.storage.value
    $text = $html -replace '(?i)<br\s*/?>', "`n"
    $text = $text -replace '(?i)<li[^>]*>', '- '
    $text = $text -replace '(?i)</(p|h[1-6]|li|tr|div|ul|ol|table)>', "`n"
    $text = $text -replace '(?i)</t[dh]>', ' | '
    $text = $text -replace '<[^>]+>', ''
    $text = [Net.WebUtility]::HtmlDecode($text)
    $lines = @($text -split "`n" | ForEach-Object { $_.Trim() })
    $text = (($lines -join "`n") -replace "(`n){3,}", "`n`n").Trim()

    $content = "Titre : $($page.title)`nSource : $Url`nVersion : $($page.version.number)`n`n$text"
    $outputDirectory = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
        New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
    }
    [IO.File]::WriteAllText($OutputPath, $content, [Text.UTF8Encoding]::new($false))
    Write-Output "CONFLUENCE PAGE OK: $($page.title) | id=$($page.id) | version=$($page.version.number) | sortie=$OutputPath | caracteres=$($content.Length)"
}
finally {
    if ($nativeBuffer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($nativeBuffer)
    }
    $token = $null
    $headers = $null
}
