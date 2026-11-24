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
    throw 'Cette skill prend en charge Windows et Linux uniquement.'
}

$secretTool = $null
if ($platform -eq 'Linux') {
    $secretTool = Get-Command 'secret-tool' -ErrorAction SilentlyContinue
    if ($null -eq $secretTool) {
        throw "Le stockage Linux du PAT requiert 'secret-tool' (libsecret-tools) et un trousseau Secret Service accessible."
    }
}

function Get-SecurePat {
    param([switch] $UseTerminal)

    if ($UseTerminal -or $platform -eq 'Linux') {
        return (Read-Host 'Jira RTE PAT (saisie masquee; ne pas le coller dans le chat)' -AsSecureString)
    }
    if (-not [Environment]::UserInteractive) {
        throw 'Aucune session graphique interactive. Relancer avec -TerminalPrompt depuis le terminal integre.'
    }
    if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne [Threading.ApartmentState]::STA) {
        throw 'Le dialogue securise requiert un processus STA. Relancer avec -TerminalPrompt depuis le terminal integre.'
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $tokenBox = New-Object System.Windows.Forms.TextBox
    $plainToken = $null
    try {
        $form.Text = 'Configurer le PAT Jira RTE'
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
        $label.Text = 'Creez un PAT personnel dans Jira, puis collez-le ici. Il ne sera pas transmis dans le chat.'
        $form.Controls.Add($label)

        $tokenBox.Location = New-Object System.Drawing.Point(18, 62)
        $tokenBox.Size = New-Object System.Drawing.Size(464, 24)
        $tokenBox.UseSystemPasswordChar = $true
        $tokenBox.ShortcutsEnabled = $true
        $form.Controls.Add($tokenBox)

        $okButton = New-Object System.Windows.Forms.Button
        $okButton.Location = New-Object System.Drawing.Point(286, 108)
        $okButton.Size = New-Object System.Drawing.Size(105, 30)
        $okButton.Text = 'Valider'
        $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Controls.Add($okButton)

        $cancelButton = New-Object System.Windows.Forms.Button
        $cancelButton.Location = New-Object System.Drawing.Point(395, 108)
        $cancelButton.Size = New-Object System.Drawing.Size(87, 30)
        $cancelButton.Text = 'Annuler'
        $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $form.Controls.Add($cancelButton)
        $form.AcceptButton = $okButton
        $form.CancelButton = $cancelButton
        $form.Add_Shown({ $tokenBox.Focus() })

        if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
            throw 'Configuration du PAT annulee; aucun nouveau PAT n''a ete enregistre.'
        }
        $plainToken = $tokenBox.Text
        if ([string]::IsNullOrWhiteSpace($plainToken)) {
            throw 'Le PAT ne peut pas etre vide.'
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
    throw 'Le PAT ne peut pas etre vide.'
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
        throw 'Jira n''a pas retourne d''identifiant utilisateur.'
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
        Write-Output 'PAT valide; stockage chiffre DPAPI dans le profil Windows courant.'
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
                throw 'Impossible de demarrer secret-tool.'
            }
            $storeProcess.StandardInput.Write($token)
            $storeProcess.StandardInput.Close()
            $storeError = $storeProcess.StandardError.ReadToEnd()
            $storeProcess.WaitForExit()
            if ($storeProcess.ExitCode -ne 0) {
                throw "Impossible de stocker le PAT dans le trousseau Secret Service Linux: $storeError"
            }
        }
        finally {
            $storeProcess.Dispose()
        }
        $storedToken = & $secretTool.Source lookup service AntaresAI account JiraDirectApi 2>$null
        if ($LASTEXITCODE -ne 0 -or
            ((@($storedToken) -join "`n").TrimEnd("`r", "`n") -cne $token)) {
            throw 'Le PAT a ete transmis au trousseau Linux mais sa relecture de verification a echoue.'
        }
        Write-Output 'PAT valide; stockage dans le trousseau Secret Service Linux.'
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
        throw "Echec de validation du PAT (HTTP $statusCode). Aucun nouveau PAT n'a ete enregistre."
    }
    throw "Echec de validation ou de stockage du PAT. Aucun nouveau PAT n'a ete enregistre."
}
finally {
    if ($nativeBuffer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($nativeBuffer)
    }
    if ($secureToken) { $secureToken.Dispose() }
    Remove-Variable token, storedToken, storeOutput, secureToken, encryptedToken, headers, user -ErrorAction SilentlyContinue
}
