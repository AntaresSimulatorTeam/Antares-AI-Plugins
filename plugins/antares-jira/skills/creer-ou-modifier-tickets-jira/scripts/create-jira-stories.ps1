[CmdletBinding()]
param(
    [string] $InputPath,

    [switch] $ValidateOnly,

    [switch] $TestConnection,

    [switch] $RepairExisting,

    [switch] $UpdateExisting
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'jira-skill-config.ps1')
$baseUrl = (Get-JiraSkillConfig).JiraBaseUrl
$projectKey = 'ANT'
$supportedIssueTypeNames = @('Anomalie', 'User Story', 'Technical Stories')
if ($env:OS -eq 'Windows_NT') {
$platform = 'Windows'
}
elseif ($PSVersionTable.PSEdition -eq 'Core' -and $IsLinux) {
if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'Linux requires PowerShell 7 (pwsh) or later.'
}
$platform = 'Linux'
}
else {
throw 'Cette skill prend en charge Windows et Linux uniquement.'
}

$credentialPath = $null
$secretTool = $null
if ($platform -eq 'Windows') {
$credentialPath = Join-Path $env:LOCALAPPDATA 'AntaresAI\JiraDirectApi\jira-pat.dpapi'
}
else {
$secretTool = Get-Command 'secret-tool' -ErrorAction SilentlyContinue
if ($null -eq $secretTool) {
    throw "Le stockage Linux du PAT requiert 'secret-tool' (libsecret-tools) et un trousseau Secret Service accessible."
}
}
if ($TestConnection) {
    if ($ValidateOnly -or $RepairExisting -or $UpdateExisting -or -not [string]::IsNullOrWhiteSpace($InputPath)) {
        throw '-TestConnection ne peut pas etre combine avec -ValidateOnly, -RepairExisting, -UpdateExisting ou InputPath.'
    }
}
else {
    if ($RepairExisting -and $UpdateExisting) {
        throw '-RepairExisting et -UpdateExisting ne peuvent pas etre combines.'
    }
    if ($ValidateOnly -and $RepairExisting) {
        throw '-ValidateOnly et -RepairExisting ne peuvent pas etre combines.'
    }
    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        throw 'InputPath est requis sauf en mode -TestConnection.'
    }
    if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
        throw "Fichier JSON introuvable: $InputPath"
    }
}
$nativeBuffer = [IntPtr]::Zero
try {
    if ($platform -eq 'Windows') {
        if (-not (Test-Path -LiteralPath $credentialPath -PathType Leaf)) {
            throw 'PAT Jira absent. Configurer le PAT avec scripts/configure-jira-pat.ps1; ne jamais le fournir dans le chat.'
        }
        $encryptedToken = (Get-Content -LiteralPath $credentialPath -Raw -Encoding ASCII).Trim()
        if ([string]::IsNullOrWhiteSpace($encryptedToken)) {
            throw 'Le fichier PAT chiffre est vide; reconfigurer le PAT.'
        }
        $secureToken = ConvertTo-SecureString -String $encryptedToken
        $nativeBuffer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
        $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($nativeBuffer)
    }
    else {
        $tokenOutput = & $secretTool.Source lookup service AntaresAI account JiraDirectApi 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "PAT Jira absent ou trousseau Secret Service inaccessible. Configurer le PAT avec scripts/configure-jira-pat.ps1."
        }
        $token = (@($tokenOutput) -join "`n").TrimEnd("`r", "`n")
        if ([string]::IsNullOrWhiteSpace($token)) {
            throw 'Le trousseau Secret Service ne contient pas de PAT Jira; le reconfigurer.'
        }
    }
    $headers = @{
        Authorization = "Bearer $token"
        Accept        = 'application/json'
    }

    function Invoke-JiraApi {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateSet('GET', 'POST', 'PUT')]
            [string] $Method,

            [Parameter(Mandatory = $true)]
            [string] $Path,

            [hashtable] $Body
        )

        $request = @{
            Uri         = "$baseUrl$Path"
            Method      = $Method
            Headers     = $headers
            TimeoutSec  = 45
            ErrorAction = 'Stop'
        }
        if ($Method -in @('POST', 'PUT')) {
            $request.ContentType = 'application/json; charset=utf-8'
            $jsonBody = ConvertTo-Json -InputObject $Body -Depth 30 -Compress
            $request.Body = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
        }

        try {
            return Invoke-RestMethod @request
        }
        catch {
            $statusCode = $null
            $responseBody = [string]$_.ErrorDetails.Message
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }
            if ([string]::IsNullOrWhiteSpace($responseBody) -and $_.Exception.Response) {
                $response = $_.Exception.Response
                if ($response -is [System.Net.Http.HttpResponseMessage]) {
                    if ($response.Content) {
                        $responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                    }
                }
                elseif ($response -is [System.Net.HttpWebResponse]) {
                    $responseStream = $response.GetResponseStream()
                    if ($responseStream) {
                        $reader = New-Object System.IO.StreamReader($responseStream)
                        try {
                            $responseBody = $reader.ReadToEnd()
                        }
                        finally {
                            $reader.Dispose()
                        }
                    }
                }
            }
            if ($responseBody.Length -gt 1000) {
                $responseBody = $responseBody.Substring(0, 1000)
            }
            if ($statusCode) {
                if (-not [string]::IsNullOrWhiteSpace($responseBody)) {
                    throw "Jira API $Method failed at $Path (HTTP $statusCode): $responseBody"
                }
                throw "Jira API $Method failed at $Path (HTTP $statusCode)."
            }
            if (-not [string]::IsNullOrWhiteSpace($responseBody)) {
                throw "Jira API $Method failed at $Path (connection or response error): $responseBody"
            }
            throw "Jira API $Method failed at $Path (connection or response error)."
        }
    }

    function Get-VerifiedExistingIssue {
        param(
            [Parameter(Mandatory = $true)]
            $Plan,

            [Parameter(Mandatory = $true)]
            [string[]] $CurrentUserIds,

            [bool] $RequireOwnReporter = $true
        )

        $issuePath = '/rest/api/2/issue/' + [Uri]::EscapeDataString($Plan.IssueKey) +
            '?fields=project,issuetype,summary,description,components,labels,reporter,updated,' + $Plan.EpicLinkFieldId
        $issue = Invoke-JiraApi -Method GET -Path $issuePath
        $fields = $issue.fields
        $epicMismatch = (-not [string]::IsNullOrWhiteSpace($Plan.EpicKey)) -and ([string]$fields.($Plan.EpicLinkFieldId) -ne $Plan.EpicKey)
        $typeMismatch = (-not [string]::IsNullOrWhiteSpace($Plan.IssueTypeName)) -and ($fields.issuetype.name -ne $Plan.IssueTypeName)
        if ($issue.key -ne $Plan.IssueKey -or
            $fields.project.key -ne $projectKey -or
            $typeMismatch -or
            $epicMismatch) {
            throw "Le ticket $($Plan.IssueKey) ne correspond pas au projet, type ou Epic attendu; aucune mise a jour effectuee."
        }
        $existingComponents = @($fields.components | ForEach-Object { $_.name })
        if ($existingComponents.Count -ne 1 -or $existingComponents[0] -ne $Plan.ComponentName) {
            throw "Le ticket $($Plan.IssueKey) ne correspond pas au composant attendu; aucune mise a jour effectuee."
        }
        $reporterIds = @($fields.reporter.name, $fields.reporter.key, $fields.reporter.accountId) |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
        if ($RequireOwnReporter -and @($CurrentUserIds | Where-Object { $reporterIds -contains $_ }).Count -eq 0) {
            throw "Le ticket $($Plan.IssueKey) n'a pas le reporter associe au PAT; aucune mise a jour effectuee."
        }
        return $issue
    }

    function Get-TextSha256 {
        param(
            [Parameter(Mandatory = $true)]
            [AllowEmptyString()]
            [string] $Value
        )

        $sha256 = [Security.Cryptography.SHA256]::Create()
        try {
            $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
            return [Convert]::ToBase64String($sha256.ComputeHash($bytes))
        }
        finally {
            $sha256.Dispose()
        }
    }

    function Get-IssueUpdateBaseline {
        param(
            [Parameter(Mandatory = $true)]
            $Issue
        )

        $currentLabels = @($Issue.fields.labels | ForEach-Object { [string]$_ } | Sort-Object)
        $labelsJson = ConvertTo-Json -InputObject $currentLabels -Compress
        $updated = [DateTimeOffset]::Parse(
            [string]$Issue.fields.updated,
            [Globalization.CultureInfo]::InvariantCulture
        ).ToUniversalTime().ToString('o')
        return [pscustomobject]@{
            IssueKey          = [string]$Issue.key
            UpdatedSha256     = Get-TextSha256 -Value $updated
            SummarySha256     = Get-TextSha256 -Value ([string]$Issue.fields.summary)
            DescriptionSha256 = Get-TextSha256 -Value ([string]$Issue.fields.description)
            LabelsSha256      = Get-TextSha256 -Value $labelsJson
        }
    }

    function Test-IssueMatchesApprovedBaseline {
        param(
            [Parameter(Mandatory = $true)]
            $Issue,

            [Parameter(Mandatory = $true)]
            $Baseline
        )

        $currentBaseline = Get-IssueUpdateBaseline -Issue $Issue
        return $currentBaseline.IssueKey -ceq $Baseline.IssueKey -and
            $currentBaseline.UpdatedSha256 -ceq $Baseline.UpdatedSha256 -and
            $currentBaseline.SummarySha256 -ceq $Baseline.SummarySha256 -and
            $currentBaseline.DescriptionSha256 -ceq $Baseline.DescriptionSha256 -and
            $currentBaseline.LabelsSha256 -ceq $Baseline.LabelsSha256
    }

    $currentUser = Invoke-JiraApi -Method GET -Path '/rest/api/2/myself'
    if ([string]::IsNullOrWhiteSpace($currentUser.name) -and
        [string]::IsNullOrWhiteSpace($currentUser.key) -and
        [string]::IsNullOrWhiteSpace($currentUser.accountId)) {
        throw 'Jira n''a pas retourne d''identifiant pour l''utilisateur du PAT.'
    }
    if (-not [string]::IsNullOrWhiteSpace($currentUser.name)) {
        $reporterIdentifierProperty = 'name'
        $reporterIdentifier = [string]$currentUser.name
    }
    elseif (-not [string]::IsNullOrWhiteSpace($currentUser.key)) {
        $reporterIdentifierProperty = 'key'
        $reporterIdentifier = [string]$currentUser.key
    }
    else {
        throw 'Jira ne retourne pas de name/key utilisable pour definir le reporter avec son API v2.'
    }
    if ($TestConnection) {
        Write-Output 'JIRA CONNECTION OK: PAT accepte par Jira; aucun ticket cree.'
        return
    }

    $inputData = Get-Content -LiteralPath $InputPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $inputData.stories -or @($inputData.stories).Count -eq 0) {
        throw 'Le JSON doit contenir au moins une story dans la propriete stories.'
    }
    $resolvedInputPath = (Resolve-Path -LiteralPath $InputPath).Path
    $inputHash = (Get-FileHash -LiteralPath $resolvedInputPath -Algorithm SHA256).Hash
    $approvedPreviewPath = "$resolvedInputPath.approved-preview.json"
    $approvedPreview = $null
    if ($UpdateExisting -and -not $ValidateOnly) {
        if (-not (Test-Path -LiteralPath $approvedPreviewPath -PathType Leaf)) {
            throw "Aucun apercu approuve trouve. Relancer -UpdateExisting -ValidateOnly, presenter le nouvel apercu et demander confirmation avant toute ecriture."
        }
        try {
            $approvedPreview = Get-Content -LiteralPath $approvedPreviewPath -Raw -Encoding UTF8 | ConvertFrom-Json
        }
        catch {
            throw "Apercu approuve invalide; relancer -UpdateExisting -ValidateOnly et demander une nouvelle confirmation."
        }
        if ($approvedPreview.InputSha256 -cne $inputHash) {
            throw "La proposition a change depuis l'apercu approuve. Relancer -UpdateExisting -ValidateOnly, presenter le nouvel apercu et demander une nouvelle confirmation."
        }
    }

    $requestedIssueTypeNames = [Collections.Generic.List[string]]::new()
    foreach ($story in @($inputData.stories)) {
        if ($UpdateExisting) {
            continue
        }
        $requestedIssueTypeName = [string]$story.issueType
        if ([string]::IsNullOrWhiteSpace($requestedIssueTypeName)) {
            if ($RepairExisting) {
                $requestedIssueTypeName = 'User Story'
            }
            else {
                throw "Chaque ticket doit preciser issueType (Anomalie, User Story ou Technical Stories)."
            }
        }
        if ($supportedIssueTypeNames -cnotcontains $requestedIssueTypeName) {
            throw "Type Jira non pris en charge '$requestedIssueTypeName'. Valeurs acceptees: $($supportedIssueTypeNames -join ', ')."
        }
        if (-not $requestedIssueTypeNames.Contains($requestedIssueTypeName)) {
            $requestedIssueTypeNames.Add($requestedIssueTypeName)
        }
    }

    $issueTypeList = Invoke-JiraApi -Method GET -Path "/rest/api/2/issue/createmeta/$projectKey/issuetypes?startAt=0&maxResults=100"
    $issueTypeMetadataByName = @{}
    $allFields = $null
    foreach ($issueTypeName in $requestedIssueTypeNames) {
        $issueTypeMeta = @($issueTypeList.values | Where-Object { $_.name -ceq $issueTypeName })
        if ($issueTypeMeta.Count -ne 1) {
            throw "Le type '$issueTypeName' n''est pas disponible sans ambiguite dans $projectKey."
        }

        $issueTypeFields = Invoke-JiraApi -Method GET -Path "/rest/api/2/issue/createmeta/$projectKey/issuetypes/$($issueTypeMeta[0].id)?startAt=0&maxResults=100"
        $fieldMetadata = @{}
        foreach ($field in @($issueTypeFields.values)) {
            if ([string]::IsNullOrWhiteSpace([string]$field.fieldId)) {
                throw "Une metadonnee de champ Jira n''a pas d''identifiant pour '$issueTypeName'."
            }
            $fieldMetadata[$field.fieldId] = $field
        }
        foreach ($requiredField in @('project', 'issuetype', 'summary', 'description', 'components', 'labels', 'reporter')) {
            if (-not $fieldMetadata.ContainsKey($requiredField)) {
                throw "Le champ Jira attendu '$requiredField' n''est pas expose pour '$issueTypeName'."
            }
        }

        $epicLinkCandidates = @($issueTypeFields.values | Where-Object {
            $_.schema -and $_.schema.custom -eq 'com.pyxis.greenhopper.jira:gh-epic-link'
        })
        if ($epicLinkCandidates.Count -eq 0) {
            $epicLinkCandidates = @($issueTypeFields.values | Where-Object { $_.name -eq 'Epic Link' })
        }
        $epicLinkFieldId = $null
        if ($epicLinkCandidates.Count -eq 1 -and
            -not [string]::IsNullOrWhiteSpace([string]$epicLinkCandidates[0].fieldId)) {
            $epicLinkFieldId = [string]$epicLinkCandidates[0].fieldId
        }
        else {
            if ($null -eq $allFields) {
                $allFields = @(Invoke-JiraApi -Method GET -Path '/rest/api/2/field')
                if ($allFields.Count -eq 1 -and $allFields[0] -is [System.Array]) {
                    $allFields = @($allFields[0])
                }
            }
            $epicLinkCandidates = @($allFields | Where-Object {
                $_.schema -and $_.schema.custom -eq 'com.pyxis.greenhopper.jira:gh-epic-link'
            })
            if ($epicLinkCandidates.Count -eq 0) {
                $epicLinkCandidates = @($allFields | Where-Object { $_.name -eq 'Epic Link' })
            }
            if ($epicLinkCandidates.Count -eq 1) {
                $epicLinkFieldId = [string]$epicLinkCandidates[0].id
            }
        }
        if ([string]::IsNullOrWhiteSpace($epicLinkFieldId)) {
            throw "Impossible d''identifier un champ Epic Link Jira unique pour '$issueTypeName'; aucune story ne sera creee."
        }
        if (-not $fieldMetadata.ContainsKey($epicLinkFieldId)) {
            throw "Le champ Epic Link ($epicLinkFieldId) n''est pas disponible a la creation de '$issueTypeName'."
        }

        $knownFields = @('project', 'issuetype', 'summary', 'description', 'components', 'labels', 'reporter', $epicLinkFieldId)
        $unsupportedRequiredFields = @($fieldMetadata.Keys | Where-Object {
            $knownFields -notcontains $_ -and $fieldMetadata[$_].required
        })
        if ($unsupportedRequiredFields.Count -gt 0) {
            throw "Champs requis non pris en charge par cette skill pour '$issueTypeName': $($unsupportedRequiredFields -join ', '). Aucune story ne sera creee."
        }
        $issueTypeMetadataByName[$issueTypeName] = [pscustomobject]@{
            Id              = [string]$issueTypeMeta[0].id
            FieldMetadata   = $fieldMetadata
            EpicLinkFieldId = $epicLinkFieldId
        }
    }

    $updateEpicLinkFieldId = $null
    if ($UpdateExisting) {
        $allFieldsForUpdate = @(Invoke-JiraApi -Method GET -Path '/rest/api/2/field')
        if ($allFieldsForUpdate.Count -eq 1 -and $allFieldsForUpdate[0] -is [System.Array]) {
            $allFieldsForUpdate = @($allFieldsForUpdate[0])
        }
        $epicLinkFieldCandidates = @($allFieldsForUpdate | Where-Object {
            $_.schema -and $_.schema.custom -eq 'com.pyxis.greenhopper.jira:gh-epic-link'
        })
        if ($epicLinkFieldCandidates.Count -ne 1) {
            throw 'Impossible d''identifier un champ Epic Link Jira unique; aucune mise a jour effectuee.'
        }
        $updateEpicLinkFieldId = [string]$epicLinkFieldCandidates[0].id
    }

    $components = @(Invoke-JiraApi -Method GET -Path "/rest/api/2/project/$projectKey/components")
    if ($components.Count -eq 1 -and $components[0] -is [System.Array]) {
        $components = @($components[0])
    }
    $plans = [Collections.Generic.List[object]]::new()
    $defaultEpicKey = [string]$inputData.epicKey

    foreach ($story in @($inputData.stories)) {
        $issueTypeName = [string]$story.issueType
        if ([string]::IsNullOrWhiteSpace($issueTypeName) -and $RepairExisting) {
            $issueTypeName = 'User Story'
        }
        if ($UpdateExisting) {
            $issueTypeConfig = [pscustomobject]@{ Id = $null; FieldMetadata = @{}; EpicLinkFieldId = $updateEpicLinkFieldId }
        }
        else {
            $issueTypeConfig = $issueTypeMetadataByName[$issueTypeName]
            if ($null -eq $issueTypeConfig) {
                throw "Les metadonnees Jira du type '$issueTypeName' sont indisponibles pour '$($story.summary)'."
            }
        }
        $fieldMetadata = $issueTypeConfig.FieldMetadata

        $requiredProperties = if ($UpdateExisting) { @('component', 'objective') } else { @('summary', 'component', 'objective') }
        foreach ($propertyName in $requiredProperties) {
            if ([string]::IsNullOrWhiteSpace([string]$story.$propertyName)) {
                throw "Chaque story doit avoir une valeur non vide pour '$propertyName'."
            }
        }
        $criteria = @($story.acceptanceCriteria |
            ForEach-Object { ([string]$_).Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($criteria.Count -eq 0) {
            throw "La story '$($story.summary)' doit avoir au moins un critere d''acceptation."
        }
        $epicKey = [string]$story.epicKey
        if ([string]::IsNullOrWhiteSpace($epicKey)) { $epicKey = $defaultEpicKey }
        if ([string]::IsNullOrWhiteSpace($epicKey) -and -not $UpdateExisting) {
            throw "Epic obligatoire manquante pour '$($story.summary)'; la skill doit la demander au PO avant toute creation."
        }
        if (-not [string]::IsNullOrWhiteSpace($epicKey) -and $epicKey -notmatch '^[A-Z][A-Z0-9_]*-\d+$') {
            throw "Cle Epic invalide pour '$($story.summary)': '$epicKey'."
        }

        $componentMatches = @($components | Where-Object { $_.name -ceq [string]$story.component })
        if ($componentMatches.Count -ne 1) {
            throw "Composant '$($story.component)' introuvable ou ambigu dans $projectKey pour '$($story.summary)'."
        }

        if (-not [string]::IsNullOrWhiteSpace($epicKey)) {
            $epicPath = '/rest/api/2/issue/' + [Uri]::EscapeDataString($epicKey) + '?fields=project,issuetype,summary'
            $epic = Invoke-JiraApi -Method GET -Path $epicPath
            if ($epic.fields.project.key -ne $projectKey -or $epic.fields.issuetype.name -ne 'Epic') {
                throw "'$epicKey' n''est pas une Epic du projet $projectKey."
            }
        }

        $labelsProvided = $null -ne $story.labels
        $labels = @()
        if ($labelsProvided) {
            $labels = @($story.labels | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        }
        if (-not $UpdateExisting -and $labels.Count -gt 0 -and -not $fieldMetadata.ContainsKey('labels')) {
            throw "Le champ Labels n''est pas disponible pour '$($story.summary)'."
        }

        $description = "**Objectif / pourquoi**`n$($story.objective.Trim())`n`n**Crit$([char]0x00E8)res d'acceptation**`n"
        $description += (($criteria | ForEach-Object { '- ' + ([string]$_).Trim() }) -join "`n")

        $plans.Add([pscustomobject]@{
            IssueKey           = [string]$story.issueKey
            IssueTypeName      = $issueTypeName
            IssueTypeId        = $issueTypeConfig.Id
            EpicLinkFieldId    = $issueTypeConfig.EpicLinkFieldId
            Summary            = if ($UpdateExisting -and [string]::IsNullOrWhiteSpace([string]$story.summary)) { $null } else { ([string]$story.summary).Trim() }
            ComponentName      = [string]$componentMatches[0].name
            ComponentId        = [string]$componentMatches[0].id
            EpicKey            = $epicKey
            LabelsProvided     = $labelsProvided
            Labels             = $labels
            Objective          = ([string]$story.objective).Trim()
            Description        = $description
            AcceptanceCriteria = $criteria
        })
    }

    $duplicateSummaries = @($plans | Group-Object Summary | Where-Object { $_.Count -gt 1 })
    if (-not $UpdateExisting -and $duplicateSummaries.Count -gt 0) {
        throw 'Le lot contient des resumes en doublon; corriger avant toute creation.'
    }

    $updatePlans = [Collections.Generic.List[object]]::new()
    if ($UpdateExisting) {
        $invalidIssueKeys = @($plans | Where-Object { $_.IssueKey -notmatch '^[A-Z][A-Z0-9_]*-\d+$' })
        if ($invalidIssueKeys.Count -gt 0) {
            throw 'En mode -UpdateExisting, chaque story doit contenir une issueKey Jira valide.'
        }
        $duplicateIssueKeys = @($plans | Group-Object IssueKey | Where-Object { $_.Count -gt 1 })
        if ($duplicateIssueKeys.Count -gt 0) {
            throw 'Le lot contient des issueKey en doublon; corriger avant toute mise a jour.'
        }

        $currentUserIds = @($currentUser.name, $currentUser.key, $currentUser.accountId) |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
        foreach ($plan in $plans) {
            $issue = Get-VerifiedExistingIssue -Plan $plan -CurrentUserIds @($currentUserIds) -RequireOwnReporter $false
            if ([string]::IsNullOrWhiteSpace($plan.IssueTypeName)) {
                $plan.IssueTypeName = [string]$issue.fields.issuetype.name
            }
            $currentSummary = [string]$issue.fields.summary
            $currentDescription = [string]$issue.fields.description
            $currentLabels = @($issue.fields.labels | ForEach-Object { [string]$_ } | Sort-Object)
            $baseline = Get-IssueUpdateBaseline -Issue $issue
            $newSummary = if ($null -ne $plan.Summary) { $plan.Summary } else { $currentSummary }
            $newLabels = if ($plan.LabelsProvided) { @($plan.Labels | Sort-Object) } else { $currentLabels }

            $updatePlans.Add([pscustomobject]@{
                Plan           = $plan
                Issue          = $issue
                Baseline       = $baseline
                ApprovedBaseline = $null
                CurrentSummary = $currentSummary
                NewSummary     = $newSummary
                CurrentDescription = $currentDescription
                CurrentLabels  = $currentLabels
                NewLabels      = $newLabels
                NeedsSummary   = ($newSummary -cne $currentSummary)
                NeedsDescription = ($plan.Description -cne $currentDescription)
                NeedsLabels    = (($newLabels -join '|') -cne ($currentLabels -join '|'))
            })
        }

        if (-not $ValidateOnly) {
            $approvedByIssueKey = @{}
            foreach ($approvedIssue in @($approvedPreview.Issues)) {
                if ($approvedByIssueKey.ContainsKey([string]$approvedIssue.IssueKey)) {
                    throw 'L''apercu approuve contient des issueKey en doublon; relancer le precheck et demander une nouvelle confirmation.'
                }
                $approvedByIssueKey[[string]$approvedIssue.IssueKey] = $approvedIssue
            }
            if ($approvedByIssueKey.Count -ne $updatePlans.Count) {
                throw 'La liste de tickets differe de l''apercu approuve. Relancer le precheck et demander une nouvelle confirmation.'
            }
            foreach ($update in $updatePlans) {
                $approvedIssue = $approvedByIssueKey[[string]$update.Plan.IssueKey]
                if ($null -eq $approvedIssue -or -not (Test-IssueMatchesApprovedBaseline -Issue $update.Issue -Baseline $approvedIssue)) {
                    throw "Conflit Jira pour $($update.Plan.IssueKey) depuis l'apercu approuve. Relancer -UpdateExisting -ValidateOnly, presenter l'etat actuel et demander une nouvelle confirmation."
                }
                $update.ApprovedBaseline = $approvedIssue
            }
        }
    }

    if ($ValidateOnly) {
        if ($UpdateExisting) {
            foreach ($update in $updatePlans) {
                $changes = @()
                if ($update.NeedsSummary) { $changes += 'resume' }
                if ($update.NeedsDescription) { $changes += 'description' }
                if ($update.NeedsLabels) { $changes += 'labels' }
                $changeText = if ($changes.Count -gt 0) { $changes -join ', ' } else { 'aucun changement' }
                Write-Output "=== $($update.Plan.IssueKey) | $($update.Plan.IssueTypeName) | composant $($update.Plan.ComponentName) | epic $($update.Plan.EpicKey) | modifications: $changeText"
                Write-Output "Resume actuel : $($update.CurrentSummary)"
                Write-Output "Resume propose : $($update.NewSummary)"
                if ($update.NeedsLabels) {
                    Write-Output "Labels actuels : $($update.CurrentLabels -join ', ')"
                    Write-Output "Labels proposes : $($update.NewLabels -join ', ')"
                }
                Write-Output '--- Description actuelle ---'
                Write-Output $update.CurrentDescription
                Write-Output '--- Description proposee ---'
                Write-Output $update.Plan.Description
            }
            $changedCount = @($updatePlans | Where-Object { $_.NeedsSummary -or $_.NeedsDescription -or $_.NeedsLabels }).Count
            $preview = [pscustomobject]@{
                InputSha256 = $inputHash
                Issues      = @($updatePlans | ForEach-Object { $_.Baseline })
            }
            [IO.File]::WriteAllText(
                $approvedPreviewPath,
                (ConvertTo-Json -InputObject $preview -Depth 10),
                [Text.UTF8Encoding]::new($false)
            )
            Write-Output "PRECHECK OK (mise a jour): $($updatePlans.Count) ticket(s) controles, $changedCount a modifier; projet $projectKey; compte PAT valide. Aucune ecriture effectuee."
            Write-Output "Apercu approuve enregistre : $approvedPreviewPath"
            return
        }
        $typeSummary = @($plans | Group-Object IssueTypeName | ForEach-Object { "$($_.Name) ($($_.Count))" }) -join ', '
        $epicLinkFields = @($plans | Select-Object -ExpandProperty EpicLinkFieldId -Unique) -join ', '
        Write-Output "PRECHECK OK: $($plans.Count) tickets; projet $projectKey; types $typeSummary; champ(s) Epic Link $epicLinkFields; compte PAT valide."
        return
    }

    if ($UpdateExisting) {
        $updatedKeys = [Collections.Generic.List[string]]::new()
        foreach ($update in $updatePlans) {
            $plan = $update.Plan
            $issuePath = '/rest/api/2/issue/' + [Uri]::EscapeDataString($plan.IssueKey)
            if (-not ($update.NeedsSummary -or $update.NeedsDescription -or $update.NeedsLabels)) {
                Write-Output "UNCHANGED: $($plan.IssueKey) | aucun champ a modifier"
                continue
            }

            $updateFields = @{}
            if ($update.NeedsSummary) { $updateFields.summary = $update.NewSummary }
            if ($update.NeedsDescription) { $updateFields.description = $plan.Description }
            if ($update.NeedsLabels) { $updateFields.labels = @($update.NewLabels) }
            try {
                $currentIssue = Invoke-JiraApi -Method GET -Path ($issuePath + '?fields=summary,description,labels,updated')
                if (-not (Test-IssueMatchesApprovedBaseline -Issue $currentIssue -Baseline $update.ApprovedBaseline)) {
                    throw "Conflit Jira pour $($plan.IssueKey) depuis l'apercu approuve. Aucune mise a jour effectuee pour ce ticket; relancer le precheck et demander une nouvelle confirmation."
                }
                Invoke-JiraApi -Method PUT -Path $issuePath -Body @{ fields = $updateFields } | Out-Null
                $verificationFields = 'summary,description,labels,issuetype'
                $verifiedIssue = Invoke-JiraApi -Method GET -Path ($issuePath + '?fields=' + $verificationFields)
                $verifiedLabels = @($verifiedIssue.fields.labels | ForEach-Object { [string]$_ } | Sort-Object) -join '|'
                if ($verifiedIssue.key -ne $plan.IssueKey -or
                    $verifiedIssue.fields.issuetype.name -ne $plan.IssueTypeName -or
                    ($update.NeedsSummary -and [string]$verifiedIssue.fields.summary -cne $update.NewSummary) -or
                    ($update.NeedsDescription -and [string]$verifiedIssue.fields.description -cne $plan.Description) -or
                    ($update.NeedsLabels -and $verifiedLabels -cne ($update.NewLabels -join '|'))) {
                    throw "Verification en echec pour $($plan.IssueKey)."
                }
            }
            catch {
                $doneList = if ($updatedKeys.Count -gt 0) { $updatedKeys -join ', ' } else { 'aucun' }
                throw "Mise a jour de $($plan.IssueKey) en echec ou non verifiee: $($_.Exception.Message) Ne pas relancer sans verification. Tickets deja mis a jour: $doneList."
            }
            $updatedKeys.Add($plan.IssueKey)
            $changedFields = @()
            if ($update.NeedsSummary) { $changedFields += 'resume' }
            if ($update.NeedsDescription) { $changedFields += 'description' }
            if ($update.NeedsLabels) { $changedFields += 'labels' }
            Write-Output "UPDATED AND VERIFIED: $($plan.IssueKey) | $($plan.IssueTypeName) | modifies: $($changedFields -join ', ')"
        }
        return
    }

    if ($RepairExisting) {
        $invalidIssueKeys = @($plans | Where-Object { $_.IssueKey -notmatch '^[A-Z][A-Z0-9_]*-\d+$' })
        if ($invalidIssueKeys.Count -gt 0) {
            throw 'En mode -RepairExisting, chaque story doit contenir une issueKey Jira valide.'
        }
        $duplicateIssueKeys = @($plans | Group-Object IssueKey | Where-Object { $_.Count -gt 1 })
        if ($duplicateIssueKeys.Count -gt 0) {
            throw 'Le lot contient des issueKey en doublon; corriger avant toute mise a jour.'
        }

        $mojibakeMarkers = @([string][char]0x00C3, [string][char]0x00C2, [string][char]0xFFFD)
        $currentUserIds = @($currentUser.name, $currentUser.key, $currentUser.accountId) |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
        $repairPlans = [Collections.Generic.List[object]]::new()
        foreach ($plan in $plans) {
            $issue = Get-VerifiedExistingIssue -Plan $plan -CurrentUserIds @($currentUserIds)
            $fields = $issue.fields

            $currentSummary = [string]$fields.summary
            $currentDescription = [string]$fields.description
            $summaryHasMojibake = $false
            $descriptionHasMojibake = $false
            foreach ($marker in $mojibakeMarkers) {
                if ($currentSummary.Contains($marker)) { $summaryHasMojibake = $true }
                if ($currentDescription.Contains($marker)) { $descriptionHasMojibake = $true }
            }
            if (-not $summaryHasMojibake -and -not $descriptionHasMojibake -and
                ($currentSummary -ne $plan.Summary -or $currentDescription -ne $plan.Description)) {
                throw "Le texte du ticket $($plan.IssueKey) n'a pas de mojibake detecte et differe de la correction proposee; aucune mise a jour effectuee."
            }
            $repairPlans.Add([pscustomobject]@{
                Plan            = $plan
                Issue           = $issue
                NeedsSummary    = $summaryHasMojibake -and $currentSummary -ne $plan.Summary
                NeedsDescription = $descriptionHasMojibake -and $currentDescription -ne $plan.Description
            })
        }

        foreach ($repair in $repairPlans) {
            $plan = $repair.Plan
            if ($repair.NeedsSummary -or $repair.NeedsDescription) {
                $issuePath = '/rest/api/2/issue/' + [Uri]::EscapeDataString($plan.IssueKey)
                $fieldsToUpdate = @{}
                if ($repair.NeedsSummary) { $fieldsToUpdate.summary = $plan.Summary }
                if ($repair.NeedsDescription) { $fieldsToUpdate.description = $plan.Description }
                $updateFields = @{ fields = $fieldsToUpdate }
                Invoke-JiraApi -Method PUT -Path $issuePath -Body $updateFields | Out-Null
                $verificationPath = $issuePath +
                    '?fields=project,issuetype,summary,description,components,reporter,' + $plan.EpicLinkFieldId
                $verifiedIssue = Invoke-JiraApi -Method GET -Path $verificationPath
                if ($verifiedIssue.key -ne $plan.IssueKey -or
                    $verifiedIssue.fields.issuetype.name -ne $plan.IssueTypeName -or
                    ($repair.NeedsSummary -and $verifiedIssue.fields.summary -ne $plan.Summary) -or
                    ($repair.NeedsDescription -and $verifiedIssue.fields.description -ne $plan.Description)) {
                    throw "Le texte du ticket $($plan.IssueKey) a ete mis a jour mais la verification a echoue."
                }
            }
            Write-Output "UPDATED AND VERIFIED: $($plan.IssueKey) | $($plan.IssueTypeName) | $($plan.Summary)"
        }
        return
    }

    $createdKeys = [Collections.Generic.List[string]]::new()
    foreach ($plan in $plans) {
        $issueFields = @{
            project     = @{ key = $projectKey }
            issuetype   = @{ id = $plan.IssueTypeId }
            summary     = $plan.Summary
            description = $plan.Description
            components  = @(@{ id = $plan.ComponentId })
            labels      = @($plan.Labels)
            reporter    = @{ $reporterIdentifierProperty = $reporterIdentifier }
        }
        $issueFields[$plan.EpicLinkFieldId] = $plan.EpicKey

        $createResponse = $null
        try {
            $createResponse = Invoke-JiraApi -Method POST -Path '/rest/api/2/issue' -Body @{ fields = $issueFields }
        }
        catch {
            $createdList = if ($createdKeys.Count -gt 0) { $createdKeys -join ', ' } else { 'aucun confirme' }
            throw "Echec ou resultat incertain pour '$($plan.Summary)'. Detail: $($_.Exception.Message) Ne pas relancer avant reconciliation. Tickets deja confirmes: $createdList."
        }
        if ([string]::IsNullOrWhiteSpace($createResponse.key)) {
            throw "Jira n'a pas retourne de cle pour '$($plan.Summary)'; verifier le resultat avant toute nouvelle tentative."
        }

        $createdKey = [string]$createResponse.key
        $createdKeys.Add($createdKey)
        $verificationPath = '/rest/api/2/issue/' + [Uri]::EscapeDataString($createdKey) +
            '?fields=project,issuetype,summary,description,components,labels,reporter,' + $plan.EpicLinkFieldId
        $createdIssue = Invoke-JiraApi -Method GET -Path $verificationPath
        $createdFields = $createdIssue.fields

        if ($createdIssue.key -ne $createdKey -or
            $createdFields.project.key -ne $projectKey -or
            $createdFields.issuetype.name -ne $plan.IssueTypeName -or
            $createdFields.summary -ne $plan.Summary) {
            throw "Ticket $createdKey cree mais verification projet/type/resume en echec. Ne pas relancer."
        }
        $createdComponents = @($createdFields.components | ForEach-Object { $_.name })
        if ($createdComponents.Count -ne 1 -or $createdComponents[0] -ne $plan.ComponentName) {
            throw "Ticket $createdKey cree mais verification du composant en echec. Ne pas relancer."
        }
        $createdLabels = @()
        if ($null -ne $createdFields.labels) { $createdLabels = @($createdFields.labels) }
        $actualLabelsText = (@($createdLabels | Sort-Object) -join '|')
        $expectedLabelsText = (@($plan.Labels | Sort-Object) -join '|')
        if ($actualLabelsText -ne $expectedLabelsText) {
            throw "Ticket $createdKey cree mais verification des labels en echec. Ne pas relancer."
        }
        if ([string]$createdFields.($plan.EpicLinkFieldId) -ne $plan.EpicKey) {
            throw "Ticket $createdKey cree mais verification de l'Epic en echec. Ne pas relancer."
        }
        $actualDescription = [string]$createdFields.description
        if (-not $actualDescription.Contains($plan.Objective)) {
            throw "Ticket $createdKey cree mais verification de l'objectif en echec. Ne pas relancer."
        }
        foreach ($criterion in $plan.AcceptanceCriteria) {
            if (-not $actualDescription.Contains([string]$criterion)) {
                throw "Ticket $createdKey cree mais verification des criteres d'acceptation en echec. Ne pas relancer."
            }
        }
        $reporter = $createdFields.reporter
        if ($null -eq $reporter -or [string]$reporter.$reporterIdentifierProperty -ne $reporterIdentifier) {
            throw "Ticket $createdKey cree mais la verification du reporter associe au PAT a echoue. Ne pas relancer."
        }
        $currentUserIds = @($currentUser.name, $currentUser.key, $currentUser.accountId) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
        $reporterIds = @($reporter.name, $reporter.key, $reporter.accountId) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
        if (@($currentUserIds | Where-Object { $reporterIds -contains $_ }).Count -eq 0) {
            throw "Ticket $createdKey cree mais le reporter ne correspond pas au compte du PAT. Ne pas relancer."
        }

        Write-Output "CREATED AND VERIFIED: $createdKey | $($plan.IssueTypeName) | $($plan.Summary) | component=$($plan.ComponentName) | epic=$($plan.EpicKey)"
    }
}
finally {
    if ($nativeBuffer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($nativeBuffer)
    }
    if ($headers) { $headers.Authorization = $null }
    Remove-Variable token, secureToken, encryptedToken, headers, currentUser -ErrorAction SilentlyContinue
}
