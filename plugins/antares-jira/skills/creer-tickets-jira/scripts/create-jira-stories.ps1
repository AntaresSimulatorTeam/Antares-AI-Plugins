[CmdletBinding()]
param(
    [string] $InputPath,

    [switch] $ValidateOnly,

    [switch] $TestConnection,

    [switch] $RepairExisting
)

$ErrorActionPreference = 'Stop'
$baseUrl = 'https://gopro-tickets.rte-france.com'
$projectKey = 'ANT'
$supportedIssueTypeNames = @('Anomalie', 'User Story')
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
    if ($ValidateOnly -or $RepairExisting -or -not [string]::IsNullOrWhiteSpace($InputPath)) {
        throw '-TestConnection ne peut pas etre combine avec -ValidateOnly, -RepairExisting ou InputPath.'
    }
}
else {
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
                $responseStream = $_.Exception.Response.GetResponseStream()
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

    $requestedIssueTypeNames = [Collections.Generic.List[string]]::new()
    foreach ($story in @($inputData.stories)) {
        $requestedIssueTypeName = [string]$story.issueType
        if ([string]::IsNullOrWhiteSpace($requestedIssueTypeName)) {
            if ($RepairExisting) {
                $requestedIssueTypeName = 'User Story'
            }
            else {
                throw "Chaque ticket doit preciser issueType (Anomalie ou User Story)."
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
        $issueTypeConfig = $issueTypeMetadataByName[$issueTypeName]
        if ($null -eq $issueTypeConfig) {
            throw "Les metadonnees Jira du type '$issueTypeName' sont indisponibles pour '$($story.summary)'."
        }
        $fieldMetadata = $issueTypeConfig.FieldMetadata

        foreach ($propertyName in @('summary', 'component', 'objective')) {
            if ([string]::IsNullOrWhiteSpace([string]$story.$propertyName)) {
                throw "Chaque story doit avoir une valeur non vide pour '$propertyName'."
            }
        }
        $criteria = @($story.acceptanceCriteria | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        if ($criteria.Count -eq 0) {
            throw "La story '$($story.summary)' doit avoir au moins un critere d''acceptation."
        }
        $epicKey = [string]$story.epicKey
        if ([string]::IsNullOrWhiteSpace($epicKey)) { $epicKey = $defaultEpicKey }
        if ([string]::IsNullOrWhiteSpace($epicKey)) {
            throw "Epic obligatoire manquante pour '$($story.summary)'; la skill doit la demander au PO avant toute creation."
        }
        if ($epicKey -notmatch '^[A-Z][A-Z0-9_]*-\d+$') {
            throw "Cle Epic invalide pour '$($story.summary)': '$epicKey'."
        }

        $componentMatches = @($components | Where-Object { $_.name -ceq [string]$story.component })
        if ($componentMatches.Count -ne 1) {
            throw "Composant '$($story.component)' introuvable ou ambigu dans $projectKey pour '$($story.summary)'."
        }

        $epicPath = '/rest/api/2/issue/' + [Uri]::EscapeDataString($epicKey) + '?fields=project,issuetype,summary'
        $epic = Invoke-JiraApi -Method GET -Path $epicPath
        if ($epic.fields.project.key -ne $projectKey -or $epic.fields.issuetype.name -ne 'Epic') {
            throw "'$epicKey' n''est pas une Epic du projet $projectKey."
        }

        $labels = @()
        if ($null -ne $story.labels) {
            $labels = @($story.labels | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        }
        if ($labels.Count -gt 0 -and -not $fieldMetadata.ContainsKey('labels')) {
            throw "Le champ Labels n''est pas disponible pour '$($story.summary)'."
        }

        $description = "**Objectif / pourquoi**`n$($story.objective.Trim())`n`n**Crit$([char]0x00E8)res d'acceptation**`n"
        $description += (($criteria | ForEach-Object { '- ' + ([string]$_).Trim() }) -join "`n")

        $plans.Add([pscustomobject]@{
            IssueKey           = [string]$story.issueKey
            IssueTypeName      = $issueTypeName
            IssueTypeId        = $issueTypeConfig.Id
            EpicLinkFieldId    = $issueTypeConfig.EpicLinkFieldId
            Summary            = ([string]$story.summary).Trim()
            ComponentName      = [string]$componentMatches[0].name
            ComponentId        = [string]$componentMatches[0].id
            EpicKey            = $epicKey
            Labels             = $labels
            Objective          = ([string]$story.objective).Trim()
            Description        = $description
            AcceptanceCriteria = $criteria
        })
    }

    $duplicateSummaries = @($plans | Group-Object Summary | Where-Object { $_.Count -gt 1 })
    if ($duplicateSummaries.Count -gt 0) {
        throw 'Le lot contient des resumes en doublon; corriger avant toute creation.'
    }

    if ($ValidateOnly) {
        $typeSummary = @($plans | Group-Object IssueTypeName | ForEach-Object { "$($_.Name) ($($_.Count))" }) -join ', '
        $epicLinkFields = @($plans | Select-Object -ExpandProperty EpicLinkFieldId -Unique) -join ', '
        Write-Output "PRECHECK OK: $($plans.Count) tickets; projet $projectKey; types $typeSummary; champ(s) Epic Link $epicLinkFields; compte PAT valide."
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
            $issuePath = '/rest/api/2/issue/' + [Uri]::EscapeDataString($plan.IssueKey) +
                '?fields=project,issuetype,summary,description,components,reporter,' + $plan.EpicLinkFieldId
            $issue = Invoke-JiraApi -Method GET -Path $issuePath
            $fields = $issue.fields
            if ($issue.key -ne $plan.IssueKey -or
                $fields.project.key -ne $projectKey -or
                $fields.issuetype.name -ne $plan.IssueTypeName -or
                [string]$fields.($plan.EpicLinkFieldId) -ne $plan.EpicKey) {
                throw "Le ticket $($plan.IssueKey) ne correspond pas au projet, type ou Epic attendu; aucune mise a jour effectuee."
            }
            $existingComponents = @($fields.components | ForEach-Object { $_.name })
            if ($existingComponents.Count -ne 1 -or $existingComponents[0] -ne $plan.ComponentName) {
                throw "Le ticket $($plan.IssueKey) ne correspond pas au composant attendu; aucune mise a jour effectuee."
            }
            $reporterIds = @($fields.reporter.name, $fields.reporter.key, $fields.reporter.accountId) |
                Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
            if (@($currentUserIds | Where-Object { $reporterIds -contains $_ }).Count -eq 0) {
                throw "Le ticket $($plan.IssueKey) n'a pas le reporter associe au PAT; aucune mise a jour effectuee."
            }

            $currentSummary = [string]$fields.summary
            $currentDescription = [string]$fields.description
            $hasMojibake = $false
            foreach ($marker in $mojibakeMarkers) {
                if ($currentSummary.Contains($marker) -or $currentDescription.Contains($marker)) {
                    $hasMojibake = $true
                    break
                }
            }
            if (-not $hasMojibake -and
                ($currentSummary -ne $plan.Summary -or $currentDescription -ne $plan.Description)) {
                throw "Le texte du ticket $($plan.IssueKey) n'a pas de mojibake detecte et differe de la correction proposee; aucune mise a jour effectuee."
            }
            $repairPlans.Add([pscustomobject]@{
                Plan          = $plan
                Issue         = $issue
                NeedsUpdate   = ($currentSummary -ne $plan.Summary -or $currentDescription -ne $plan.Description)
            })
        }

        foreach ($repair in $repairPlans) {
            $plan = $repair.Plan
            if ($repair.NeedsUpdate) {
                $issuePath = '/rest/api/2/issue/' + [Uri]::EscapeDataString($plan.IssueKey)
                $updateFields = @{ fields = @{ summary = $plan.Summary; description = $plan.Description } }
                Invoke-JiraApi -Method PUT -Path $issuePath -Body $updateFields | Out-Null
                $verificationPath = $issuePath +
                    '?fields=project,issuetype,summary,description,components,reporter,' + $plan.EpicLinkFieldId
                $verifiedIssue = Invoke-JiraApi -Method GET -Path $verificationPath
                if ($verifiedIssue.key -ne $plan.IssueKey -or
                    $verifiedIssue.fields.issuetype.name -ne $plan.IssueTypeName -or
                    $verifiedIssue.fields.summary -ne $plan.Summary -or
                    $verifiedIssue.fields.description -ne $plan.Description) {
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
