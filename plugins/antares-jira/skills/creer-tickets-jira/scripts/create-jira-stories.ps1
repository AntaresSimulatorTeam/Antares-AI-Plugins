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
throw 'This skill supports Windows and Linux only.'
}

$credentialPath = $null
$secretTool = $null
if ($platform -eq 'Windows') {
$credentialPath = Join-Path $env:LOCALAPPDATA 'AntaresAI\JiraDirectApi\jira-pat.dpapi'
}
else {
$secretTool = Get-Command 'secret-tool' -ErrorAction SilentlyContinue
if ($null -eq $secretTool) {
    throw "Linux PAT storage requires 'secret-tool' (libsecret-tools) and an accessible Secret Service keyring."
}
}
if ($TestConnection) {
    if ($ValidateOnly -or $RepairExisting -or -not [string]::IsNullOrWhiteSpace($InputPath)) {
        throw '-TestConnection cannot be combined with -ValidateOnly, -RepairExisting or InputPath.'
    }
}
else {
    if ($ValidateOnly -and $RepairExisting) {
        throw '-ValidateOnly and -RepairExisting cannot be combined.'
    }
    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        throw 'InputPath is required unless using -TestConnection.'
    }
    if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
        throw "JSON file not found: $InputPath"
    }
}
$nativeBuffer = [IntPtr]::Zero
try {
    if ($platform -eq 'Windows') {
        if (-not (Test-Path -LiteralPath $credentialPath -PathType Leaf)) {
            throw 'Jira PAT missing. Configure it using scripts/configure-jira-pat.ps1; never provide it in chat.'
        }
        $encryptedToken = (Get-Content -LiteralPath $credentialPath -Raw -Encoding ASCII).Trim()
        if ([string]::IsNullOrWhiteSpace($encryptedToken)) {
            throw 'The encrypted PAT file is empty; configure the PAT again.'
        }
        $secureToken = ConvertTo-SecureString -String $encryptedToken
        $nativeBuffer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
        $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($nativeBuffer)
    }
    else {
        $tokenOutput = & $secretTool.Source lookup service AntaresAI account JiraDirectApi 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Jira PAT missing or Secret Service keyring unavailable. Configure the PAT using scripts/configure-jira-pat.ps1."
        }
        $token = (@($tokenOutput) -join "`n").TrimEnd("`r", "`n")
        if ([string]::IsNullOrWhiteSpace($token)) {
            throw 'The Secret Service keyring does not contain a Jira PAT; configure it again.'
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
            if ([string]::IsNullOrWhiteSpace($responseBody) -and
                $_.Exception.Response -is [System.Net.HttpWebResponse]) {
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
        throw 'Jira did not return an identifier for the PAT user.'
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
        throw 'Jira did not return a usable name/key for the reporter in its v2 API.'
    }
    if ($TestConnection) {
        Write-Output 'JIRA CONNECTION OK: PAT accepted by Jira; no tickets created.'
        return
    }

    $inputData = Get-Content -LiteralPath $InputPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $inputData.stories -or @($inputData.stories).Count -eq 0) {
        throw 'The JSON must contain at least one story in the stories property.'
    }

    $requestedIssueTypeNames = [Collections.Generic.List[string]]::new()
    foreach ($story in @($inputData.stories)) {
        $requestedIssueTypeName = [string]$story.issueType
        if ([string]::IsNullOrWhiteSpace($requestedIssueTypeName)) {
            if ($RepairExisting) {
                $requestedIssueTypeName = 'User Story'
            }
            else {
                throw "Each ticket must specify issueType (Anomalie or User Story)."
            }
        }
        if ($supportedIssueTypeNames -cnotcontains $requestedIssueTypeName) {
            throw "Unsupported Jira type '$requestedIssueTypeName'. Accepted values: $($supportedIssueTypeNames -join ', ')."
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
            throw "Issue type '$issueTypeName' is unavailable or ambiguous in $projectKey."
        }

        $issueTypeFields = Invoke-JiraApi -Method GET -Path "/rest/api/2/issue/createmeta/$projectKey/issuetypes/$($issueTypeMeta[0].id)?startAt=0&maxResults=100"
        $fieldMetadata = @{}
        foreach ($field in @($issueTypeFields.values)) {
            if ([string]::IsNullOrWhiteSpace([string]$field.fieldId)) {
                throw "A Jira field metadata entry has no identifier for '$issueTypeName'."
            }
            $fieldMetadata[$field.fieldId] = $field
        }
        foreach ($requiredField in @('project', 'issuetype', 'summary', 'description', 'components', 'labels', 'reporter')) {
            if (-not $fieldMetadata.ContainsKey($requiredField)) {
                throw "Expected Jira field '$requiredField' is not exposed for '$issueTypeName'."
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
            throw "Unable to identify a unique Jira Epic Link field for '$issueTypeName'; no stories will be created."
        }
        if (-not $fieldMetadata.ContainsKey($epicLinkFieldId)) {
            throw "Epic Link field ($epicLinkFieldId) is unavailable when creating '$issueTypeName'."
        }

        $knownFields = @('project', 'issuetype', 'summary', 'description', 'components', 'labels', 'reporter', $epicLinkFieldId)
        $unsupportedRequiredFields = @($fieldMetadata.Keys | Where-Object {
            $knownFields -notcontains $_ -and $fieldMetadata[$_].required
        })
        if ($unsupportedRequiredFields.Count -gt 0) {
            throw "Required fields unsupported by this skill for '$issueTypeName': $($unsupportedRequiredFields -join ', '). No stories will be created."
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
            throw "Jira metadata for type '$issueTypeName' is unavailable for '$($story.summary)'."
        }
        $fieldMetadata = $issueTypeConfig.FieldMetadata

        foreach ($propertyName in @('summary', 'component', 'objective')) {
            if ([string]::IsNullOrWhiteSpace([string]$story.$propertyName)) {
                throw "Each story must have a nonempty value for '$propertyName'."
            }
        }
        $criteria = @($story.acceptanceCriteria |
            ForEach-Object { ([string]$_).Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($criteria.Count -eq 0) {
            throw "Story '$($story.summary)' must have at least one acceptance criterion."
        }
        $epicKey = [string]$story.epicKey
        if ([string]::IsNullOrWhiteSpace($epicKey)) { $epicKey = $defaultEpicKey }
        if ([string]::IsNullOrWhiteSpace($epicKey)) {
            throw "Required Epic missing for '$($story.summary)'; ask the PO before creating any ticket."
        }
        if ($epicKey -notmatch '^[A-Z][A-Z0-9_]*-\d+$') {
            throw "Invalid Epic key for '$($story.summary)': '$epicKey'."
        }

        $componentMatches = @($components | Where-Object { $_.name -ceq [string]$story.component })
        if ($componentMatches.Count -ne 1) {
            throw "Component '$($story.component)' missing or ambiguous in $projectKey for '$($story.summary)'."
        }

        $epicPath = '/rest/api/2/issue/' + [Uri]::EscapeDataString($epicKey) + '?fields=project,issuetype,summary'
        $epic = Invoke-JiraApi -Method GET -Path $epicPath
        if ($epic.fields.project.key -ne $projectKey -or $epic.fields.issuetype.name -ne 'Epic') {
            throw "'$epicKey' is not an Epic in project $projectKey."
        }

        $labels = @()
        if ($null -ne $story.labels) {
            $labels = @($story.labels | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        }
        if ($labels.Count -gt 0 -and -not $fieldMetadata.ContainsKey('labels')) {
            throw "The Labels field is unavailable for '$($story.summary)'."
        }

        $description = "**Objectif / pourquoi**`n$($story.objective.Trim())`n`n**Crit$([char]0x00E8)res d'acceptation**`n"
        $description += (($criteria | ForEach-Object { '- ' + [string]$_ }) -join "`n")

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
        throw 'The batch contains duplicate summaries; correct them before creating tickets.'
    }

    if ($ValidateOnly) {
        $typeSummary = @($plans | Group-Object IssueTypeName | ForEach-Object { "$($_.Name) ($($_.Count))" }) -join ', '
        $epicLinkFields = @($plans | Select-Object -ExpandProperty EpicLinkFieldId -Unique) -join ', '
        Write-Output "PRECHECK OK: $($plans.Count) tickets; project $projectKey; types $typeSummary; Epic Link field(s) $epicLinkFields; PAT account valid."
        return
    }

    if ($RepairExisting) {
        $invalidIssueKeys = @($plans | Where-Object { $_.IssueKey -notmatch '^[A-Z][A-Z0-9_]*-\d+$' })
        if ($invalidIssueKeys.Count -gt 0) {
            throw 'In -RepairExisting mode, each story must contain a valid Jira issueKey.'
        }
        $duplicateIssueKeys = @($plans | Group-Object IssueKey | Where-Object { $_.Count -gt 1 })
        if ($duplicateIssueKeys.Count -gt 0) {
            throw 'The batch contains duplicate issueKeys; correct them before updating.'
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
                throw "Ticket $($plan.IssueKey) does not match the expected project, type or Epic; no update performed."
            }
            $existingComponents = @($fields.components | ForEach-Object { $_.name })
            if ($existingComponents.Count -ne 1 -or $existingComponents[0] -ne $plan.ComponentName) {
                throw "Ticket $($plan.IssueKey) does not match the expected component; no update performed."
            }
            $reporterIds = @($fields.reporter.name, $fields.reporter.key, $fields.reporter.accountId) |
                Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
            if (@($currentUserIds | Where-Object { $reporterIds -contains $_ }).Count -eq 0) {
                throw "Ticket $($plan.IssueKey) does not have the reporter associated with the PAT; no update performed."
            }

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
                throw "Ticket $($plan.IssueKey) text has no detected mojibake and differs from the proposed correction; no update performed."
            }
            $summaryNeedsUpdate = $summaryHasMojibake -and $currentSummary -ne $plan.Summary
            $descriptionNeedsUpdate = $descriptionHasMojibake -and $currentDescription -ne $plan.Description
            $repairPlans.Add([pscustomobject]@{
                Plan                   = $plan
                Issue                  = $issue
                SummaryNeedsUpdate     = $summaryNeedsUpdate
                DescriptionNeedsUpdate = $descriptionNeedsUpdate
                NeedsUpdate            = ($summaryNeedsUpdate -or $descriptionNeedsUpdate)
            })
        }

        foreach ($repair in $repairPlans) {
            $plan = $repair.Plan
            if ($repair.NeedsUpdate) {
                $issuePath = '/rest/api/2/issue/' + [Uri]::EscapeDataString($plan.IssueKey)
                $fieldsToUpdate = @{}
                if ($repair.SummaryNeedsUpdate) { $fieldsToUpdate.summary = $plan.Summary }
                if ($repair.DescriptionNeedsUpdate) { $fieldsToUpdate.description = $plan.Description }
                $updateFields = @{ fields = $fieldsToUpdate }
                Invoke-JiraApi -Method PUT -Path $issuePath -Body $updateFields | Out-Null
                $verificationPath = $issuePath +
                    '?fields=project,issuetype,summary,description,components,reporter,' + $plan.EpicLinkFieldId
                $verifiedIssue = Invoke-JiraApi -Method GET -Path $verificationPath
                if ($verifiedIssue.key -ne $plan.IssueKey -or
                    $verifiedIssue.fields.issuetype.name -ne $plan.IssueTypeName -or
                    ($repair.SummaryNeedsUpdate -and $verifiedIssue.fields.summary -ne $plan.Summary) -or
                    ($repair.DescriptionNeedsUpdate -and $verifiedIssue.fields.description -ne $plan.Description)) {
                    throw "Ticket $($plan.IssueKey) text was updated but verification failed."
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
            $createdList = if ($createdKeys.Count -gt 0) { $createdKeys -join ', ' } else { 'none confirmed' }
            throw "Failure or uncertain result for '$($plan.Summary)'. Details: $($_.Exception.Message) Do not retry before reconciliation. Already confirmed tickets: $createdList."
        }
        if ([string]::IsNullOrWhiteSpace($createResponse.key)) {
            throw "Jira did not return a key for '$($plan.Summary)'; verify the result before retrying."
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
            throw "Ticket $createdKey created but project/type/summary verification failed. Do not retry."
        }
        $createdComponents = @($createdFields.components | ForEach-Object { $_.name })
        if ($createdComponents.Count -ne 1 -or $createdComponents[0] -ne $plan.ComponentName) {
            throw "Ticket $createdKey created but component verification failed. Do not retry."
        }
        $createdLabels = @()
        if ($null -ne $createdFields.labels) { $createdLabels = @($createdFields.labels) }
        $actualLabelsText = (@($createdLabels | Sort-Object) -join '|')
        $expectedLabelsText = (@($plan.Labels | Sort-Object) -join '|')
        if ($actualLabelsText -ne $expectedLabelsText) {
            throw "Ticket $createdKey created but label verification failed. Do not retry."
        }
        if ([string]$createdFields.($plan.EpicLinkFieldId) -ne $plan.EpicKey) {
            throw "Ticket $createdKey created but Epic verification failed. Do not retry."
        }
        $actualDescription = [string]$createdFields.description
        if (-not $actualDescription.Contains($plan.Objective)) {
            throw "Ticket $createdKey created but objective verification failed. Do not retry."
        }
        foreach ($criterion in $plan.AcceptanceCriteria) {
            if (-not $actualDescription.Contains([string]$criterion)) {
                throw "Ticket $createdKey created but acceptance criteria verification failed. Do not retry."
            }
        }
        $reporter = $createdFields.reporter
        if ($null -eq $reporter -or [string]$reporter.$reporterIdentifierProperty -ne $reporterIdentifier) {
            throw "Ticket $createdKey created but verification of the PAT reporter failed. Do not retry."
        }
        $currentUserIds = @($currentUser.name, $currentUser.key, $currentUser.accountId) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
        $reporterIds = @($reporter.name, $reporter.key, $reporter.accountId) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
        if (@($currentUserIds | Where-Object { $reporterIds -contains $_ }).Count -eq 0) {
            throw "Ticket $createdKey created but the reporter does not match the PAT account. Do not retry."
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
