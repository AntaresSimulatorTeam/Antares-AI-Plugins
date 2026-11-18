[CmdletBinding()]
param(
    [switch] $TerminalPrompt
)

$ErrorActionPreference = 'Stop'

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

$secretTool = $null
if ($platform -eq 'Linux') {
    $secretTool = Get-Command 'secret-tool' -ErrorAction SilentlyContinue
    if ($null -eq $secretTool) {
        throw "Linux PAT storage requires 'secret-tool' (libsecret-tools) and an accessible Secret Service keyring."
    }
}

function Get-SecurePat {
    param([switch] $UseTerminal)

    if ($UseTerminal -or $platform -eq 'Linux') {
        return (Read-Host 'Jira RTE PAT (masked input; do not paste it in chat)' -AsSecureString)
    }
    if (-not [Environment]::UserInteractive) {
        throw 'No interactive graphical session. Run again with -TerminalPrompt in the integrated terminal.'
    }
    if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne [Threading.ApartmentState]::STA) {
        throw 'The secure dialog requires an STA process. Run again with -TerminalPrompt in the integrated terminal.'
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $tokenBox = New-Object System.Windows.Forms.TextBox
    $plainToken = $null
    try {
        $form.Text = 'Configure the Jira RTE PAT'
        $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
        $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $form.MaximizeBox = $false
        $form.MinimizeBox = $false
        $form.ShowInTaskbar = $true
        $form.TopMost = $true
        $form.ClientSize = New-Object System.Drawing.Size(500, 155)

        $label = New-Object System.Windows.Forms.Label
        $label.Location = New-Object System.Drawing.Point(16, 14)
        $label.Size = New-Object System.Drawing.Size(468, 43)
        $label.Text = 'Create a personal PAT in Jira, then paste it here. It will not be sent in chat.'
        $form.Controls.Add($label)

        $tokenBox.Location = New-Object System.Drawing.Point(18, 62)
        $tokenBox.Size = New-Object System.Drawing.Size(464, 24)
        $tokenBox.UseSystemPasswordChar = $true
        $tokenBox.ShortcutsEnabled = $true
        $form.Controls.Add($tokenBox)

        $okButton = New-Object System.Windows.Forms.Button
        $okButton.Location = New-Object System.Drawing.Point(286, 108)
        $okButton.Size = New-Object System.Drawing.Size(105, 30)
        $okButton.Text = 'Confirm'
        $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Controls.Add($okButton)

        $cancelButton = New-Object System.Windows.Forms.Button
        $cancelButton.Location = New-Object System.Drawing.Point(395, 108)
        $cancelButton.Size = New-Object System.Drawing.Size(87, 30)
        $cancelButton.Text = 'Cancel'
        $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $form.Controls.Add($cancelButton)
        $form.AcceptButton = $okButton
        $form.CancelButton = $cancelButton
        $form.Add_Shown({ $tokenBox.Focus() })

        if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
            throw 'PAT configuration cancelled; no new PAT was saved.'
        }
        $plainToken = $tokenBox.Text
        if ([string]::IsNullOrWhiteSpace($plainToken)) {
            throw 'The PAT cannot be empty.'
        }

        $secureToken = New-Object System.Security.SecureString
        foreach ($character in $plainToken.ToCharArray()) {
            $secureToken.AppendChar($character)
        }
        $secureToken.MakeReadOnly()
        return $secureToken
    }
    finally {
        $tokenBox.Clear()
        $form.Dispose()
        $plainToken = $null
    }
}

$secureToken = Get-SecurePat -UseTerminal:$TerminalPrompt
if ($null -eq $secureToken -or $secureToken.Length -eq 0) {
    if ($secureToken) { $secureToken.Dispose() }
    throw 'The PAT cannot be empty.'
}

$nativeBuffer = [IntPtr]::Zero
$temporaryPath = $null
try {
    $nativeBuffer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($nativeBuffer)
    $headers = @{
        Authorization = "Bearer $token"
        Accept        = 'application/json'
    }
    $user = Invoke-RestMethod `
        -Uri 'https://gopro-tickets.rte-france.com/rest/api/2/myself' `
        -Method Get `
        -Headers $headers `
        -TimeoutSec 30 `
        -ErrorAction Stop

    if ([string]::IsNullOrWhiteSpace($user.name) -and
        [string]::IsNullOrWhiteSpace($user.key) -and
        [string]::IsNullOrWhiteSpace($user.accountId)) {
        throw 'Jira did not return a user identifier.'
    }

    if ($platform -eq 'Windows') {
        $encryptedToken = ConvertFrom-SecureString -SecureString $secureToken
        $credentialDirectory = Join-Path $env:LOCALAPPDATA 'AntaresAI\JiraDirectApi'
        New-Item -ItemType Directory -Path $credentialDirectory -Force | Out-Null
        $credentialPath = Join-Path $credentialDirectory 'jira-pat.dpapi'
        $temporaryPath = "$credentialPath.$PID.tmp"
        Set-Content -LiteralPath $temporaryPath -Value $encryptedToken -Encoding ASCII -NoNewline
        Move-Item -LiteralPath $temporaryPath -Destination $credentialPath -Force
        $temporaryPath = $null
        Write-Output 'PAT valid; stored with DPAPI encryption in the current Windows profile.'
    }
    else {
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $secretTool.Source
        $processInfo.Arguments = 'store --label=AntaresAI-Jira service AntaresAI account JiraDirectApi'
        $processInfo.UseShellExecute = $false
        $processInfo.RedirectStandardInput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.CreateNoWindow = $true
        $storeProcess = New-Object System.Diagnostics.Process
        try {
            $storeProcess.StartInfo = $processInfo
            if (-not $storeProcess.Start()) {
                throw 'Unable to start secret-tool.'
            }
            $storeProcess.StandardInput.Write($token)
            $storeProcess.StandardInput.Close()
            $storeError = $storeProcess.StandardError.ReadToEnd()
            $storeProcess.WaitForExit()
            if ($storeProcess.ExitCode -ne 0) {
                throw "Unable to store the PAT in the Linux Secret Service keyring: $storeError"
            }
        }
        finally {
            $storeProcess.Dispose()
        }
        $storedToken = & $secretTool.Source lookup service AntaresAI account JiraDirectApi 2>$null
        if ($LASTEXITCODE -ne 0 -or
            ((@($storedToken) -join "`n").TrimEnd("`r", "`n") -cne $token)) {
            throw 'The PAT was sent to the Linux keyring but verification failed when reading it back.'
        }
        Write-Output 'PAT valid; stored in the Linux Secret Service keyring.'
    }
}
catch {
    if ($temporaryPath -and (Test-Path -LiteralPath $temporaryPath)) {
        Remove-Item -LiteralPath $temporaryPath -Force
    }

    $statusCode = $null
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
        $statusCode = [int]$_.Exception.Response.StatusCode
    }
    if ($statusCode) {
        throw "PAT validation failed (HTTP $statusCode). No new PAT was saved."
    }
    throw "PAT validation or storage failed. No new PAT was saved."
}
finally {
    if ($nativeBuffer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($nativeBuffer)
    }
    if ($secureToken) { $secureToken.Dispose() }
    Remove-Variable token, storedToken, storeOutput, secureToken, encryptedToken, headers, user -ErrorAction SilentlyContinue
}
