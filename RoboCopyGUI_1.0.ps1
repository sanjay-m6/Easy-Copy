# ===============================
# RELAUNCH HIDDEN (only when running as .ps1, skipped in EXE)
# ===============================

$isCompiledExe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName -notlike '*powershell*'

if (-not $isCompiledExe -and -not $env:ROBOCOPY_GUI_HIDDEN -and $Host.Name -eq "ConsoleHost") {
    $env:ROBOCOPY_GUI_HIDDEN = "1"

    $scriptPath = (Get-Item -LiteralPath $MyInvocation.MyCommand.Path).FullName

    Start-Process powershell.exe `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`"" `
        -WindowStyle Hidden

    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -AssemblyName PresentationCore

# ===============================
# Save File
# ===============================
$configFile = "$env:APPDATA\RoboCopyProfiles.csv"
if (!(Test-Path $configFile)) { "" | Out-File $configFile }

$global:settingsFile = "$env:APPDATA\RoboCopySettings.ini"
$global:startMinimized = $false
$global:notifyOnComplete = $true
if (Test-Path $global:settingsFile) {
    try {
        $c = (Get-Content $global:settingsFile) -join ""
        if ($c -match "StartMinimized=1") { $global:startMinimized = $true }
        if ($c -match "NotifyOnComplete=0") { $global:notifyOnComplete = $false }
    }
    catch {}
}

# ===============================
# GLOBAL PROCESS CONTROL
# ===============================
$global:RobocopyProcess = $null
$global:StopRequested = $false
$global:AlertSoundPath = $null

# ===============================
# Modern Explorer Picker
# ===============================
function Select-Path {
    param([bool]$Multi = $false)

    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Select File or Folder"
    $dialog.Filter = "All Files (*.*)|*.*"
    $dialog.CheckFileExists = $false
    $dialog.ValidateNames = $false
    $dialog.Multiselect = $Multi

    if ($dialog.ShowDialog() -eq "OK") {
        if ($Multi) {
            return ($dialog.FileNames -join '|')
        }
        else {
            return $dialog.FileName
        }
    }
}

# ===============================
# FORM
# ===============================
$form = New-Object Windows.Forms.Form
try {

    # Get script/exe directory safely
    if ($isCompiledExe) {
        $scriptDir = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
    }
    else {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }

    $iconPath = Join-Path $scriptDir "EasyRoboCopy.ico"
    $global:AlertSoundPath = Join-Path $scriptDir "alert.mp3"

    if (Test-Path $iconPath) {

        $appIcon = New-Object System.Drawing.Icon($iconPath)

        $form.Icon = $appIcon
        $trayIcon.Icon = $appIcon
    }

}
catch {}
$form.Text = "EasyRoboCopy by CjHackerYT"
$form.Size = "1050,750"
$form.MinimumSize = "1000,700"
$form.StartPosition = "CenterScreen"
$form.KeyPreview = $true
$form.AllowDrop = $true

$form.Add_Load({
        if ($global:startMinimized) {
            $form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
            $form.Hide()
            $trayIcon.Visible = $true
        }
    })

# Modern UI - Colors & Fonts
$form.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#F4F7F6")
$global:uiFont = New-Object System.Drawing.Font("Segoe UI", 10)
$global:lblFont = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$global:headerFont = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$global:btnFont = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$global:bgPrimary = [System.Drawing.ColorTranslator]::FromHtml("#4A88F6")
$global:fgPrimary = [System.Drawing.Color]::White
$global:bgDanger = [System.Drawing.ColorTranslator]::FromHtml("#FFEFEF")
$global:fgDanger = [System.Drawing.ColorTranslator]::FromHtml("#D13438")
$global:bgSecondary = [System.Drawing.ColorTranslator]::FromHtml("#F0F2F5")
$global:bgCard = [System.Drawing.Color]::White

$mainPanel = New-Object Windows.Forms.Panel
$mainPanel.Dock = "Fill"
$mainPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#F8FAFC")
$form.Controls.Add($mainPanel)

$headerLbl = New-Object Windows.Forms.Label
$headerLbl.Text = "Active Tasks"
$headerLbl.Font = $global:headerFont
$headerLbl.Location = "30, 20"
$headerLbl.AutoSize = $true
$mainPanel.Controls.Add($headerLbl)

$chkRunMinimized = New-Object Windows.Forms.CheckBox
$chkRunMinimized.Text = "Run Minimized"
$chkRunMinimized.Location = "850,25"
$chkRunMinimized.AutoSize = $true
$chkRunMinimized.Font = $global:uiFont
$chkRunMinimized.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#7A8B9A")
$chkRunMinimized.Anchor = "Top, Right"
$chkRunMinimized.Checked = $global:startMinimized
$mainPanel.Controls.Add($chkRunMinimized)
$chkRunMinimized.Add_CheckedChanged({
        $sm = if ($chkRunMinimized.Checked) { 1 } else { 0 }
        $nc = if ($chkNotify.Checked) { 1 } else { 0 }
        "StartMinimized=$sm`r`nNotifyOnComplete=$nc" | Out-File $global:settingsFile
    })

$chkNotify = New-Object Windows.Forms.CheckBox
$chkNotify.Text = "Notifications"
$chkNotify.Location = "720,25"
$chkNotify.AutoSize = $true
$chkNotify.Font = $global:uiFont
$chkNotify.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#7A8B9A")
$chkNotify.Anchor = "Top, Right"
$chkNotify.Checked = $global:notifyOnComplete
$mainPanel.Controls.Add($chkNotify)
$chkNotify.Add_CheckedChanged({
        $sm = if ($chkRunMinimized.Checked) { 1 } else { 0 }
        $nc = if ($chkNotify.Checked) { 1 } else { 0 }
        "StartMinimized=$sm`r`nNotifyOnComplete=$nc" | Out-File $global:settingsFile
    })

# ===============================
# TRAY ICON SETUP
# ===============================
$trayIcon = New-Object System.Windows.Forms.NotifyIcon
$trayIcon.Icon = [System.Drawing.SystemIcons]::Application
$trayIcon.Text = "EasyRoboCopy"
$trayIcon.Visible = $false

# Tray menu
$trayMenu = New-Object System.Windows.Forms.ContextMenuStrip

$openItem = $trayMenu.Items.Add("Open")
$exitItem = $trayMenu.Items.Add("Exit")

$trayIcon.ContextMenuStrip = $trayMenu

# Restore window
$openItem.Add_Click({
        $form.Show()
        $form.WindowState = "Normal"
        $trayIcon.Visible = $false
    })

$trayIcon.Add_DoubleClick({
        $form.Show()
        $form.WindowState = "Normal"
        $trayIcon.Visible = $false
    })

$exitItem.Add_Click({

        $global:AllowExit = $true
        $trayIcon.Visible = $false
        $hotkeyTimer.Stop()

        $form.Close()
    })

# ===============================
# MINIMIZE TO TRAY
# ===============================
# ===============================
# TRAY MINIMIZE FIX (CORRECT)
# ===============================
$global:AllowExit = $false

$form.Add_FormClosing({

        param($formSender, $e)

        # Prevent real closing
        if (-not $global:AllowExit) {
            $e.Cancel = $true
            $form.Hide()

            $trayIcon.Visible = $true
            $trayIcon.ShowBalloonTip(
                2000,
                "EasyRoboCopy-cjhackeryt",
                "Running in background (Tray Mode)",
                [System.Windows.Forms.ToolTipIcon]::Info
            )
        }
    })

$form.Add_Resize({

        if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) {
            $form.Hide()
            $trayIcon.Visible = $true
        }
    })

# ===============================
# CREATE NEW TASK CARD
# ===============================
$taskCard = New-Object Windows.Forms.Panel
$taskCard.Location = "30,70"
$taskCard.Size = "970,260"
$taskCard.Anchor = "Top, Left, Right"
$taskCard.BackColor = $global:bgCard
$mainPanel.Controls.Add($taskCard)

$taskCardTitle = New-Object Windows.Forms.Label
$taskCardTitle.Text = "CREATE NEW TASK"
$taskCardTitle.Font = $global:lblFont
$taskCardTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#7A8B9A")
$taskCardTitle.Location = "20,15"
$taskCardTitle.AutoSize = $true
$taskCard.Controls.Add($taskCardTitle)

# ---------- Source Path ----------
$srcLbl = New-Object Windows.Forms.Label
$srcLbl.Text = "Source Path"
$srcLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$srcLbl.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#7A8B9A")
$srcLbl.Location = "20,45"
$srcLbl.AutoSize = $true
$taskCard.Controls.Add($srcLbl)

$srcBox = New-Object Windows.Forms.TextBox
$srcBox.Text = "C:\Users\Documents\Work"
$srcBox.ForeColor = "Gray"
$srcBox.Size = "880,35"
$srcBox.Location = "20,68"
$srcBox.Font = $global:uiFont
$srcBox.BorderStyle = "FixedSingle"
$srcBox.Anchor = "Top, Left, Right"
$srcBox.AllowDrop = $true
$taskCard.Controls.Add($srcBox)

$srcBox.Add_GotFocus({ if ($srcBox.ForeColor -eq [System.Drawing.Color]::Gray) { $srcBox.Text = ""; $srcBox.ForeColor = "Black" } })
$srcBox.Add_LostFocus({ if (!$srcBox.Text) { $srcBox.Text = "Source path..."; $srcBox.ForeColor = "Gray" } })

# Auto-fill source from command-line args (drag file onto EXE)
$cmdArgs = [System.Environment]::GetCommandLineArgs()
if ($cmdArgs.Count -gt 1) {
    $droppedPath = $cmdArgs[1]
    if (Test-Path $droppedPath) {
        $srcBox.Text = $droppedPath
        $srcBox.ForeColor = "Black"
    }
}

$srcBox.Add_DragEnter({
        if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) {
            $_.Effect = [Windows.Forms.DragDropEffects]::Copy
        }
    })
$srcBox.Add_DragDrop({
        $files = $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)
        if ($files.Count -gt 0) {
            $srcBox.Text = ($files -join '|')
            $srcBox.ForeColor = "Black"
        }
    })

$srcBrowse = New-Object Windows.Forms.Button
$srcBrowse.Text = "..."
$srcBrowse.Size = "40,35"
$srcBrowse.Location = "910,68"
$srcBrowse.Anchor = "Top, Right"
$srcBrowse.BackColor = $global:bgSecondary
$srcBrowse.ForeColor = [System.Drawing.Color]::DimGray
$srcBrowse.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$srcBrowse.FlatStyle = "Flat"
$srcBrowse.FlatAppearance.BorderSize = 0
$srcBrowse.Cursor = [System.Windows.Forms.Cursors]::Hand
$taskCard.Controls.Add($srcBrowse)

$srcBrowse.Add_Click({
        $p = Select-Path -Multi $true
        if ($p) { $srcBox.Text = $p; $srcBox.ForeColor = "Black" }
    })

# ---------- Destination Path ----------
$destLbl = New-Object Windows.Forms.Label
$destLbl.Text = "Destination Path"
$destLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$destLbl.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#0d8effff")
$destLbl.Location = "20,115"
$destLbl.AutoSize = $true
$taskCard.Controls.Add($destLbl)

$destBox = New-Object Windows.Forms.TextBox
$destBox.Text = "D:\Backups\Daily"
$destBox.ForeColor = "Gray"
$destBox.Location = "20,138"
$destBox.Size = "880,35"
$destBox.Font = $global:uiFont
$destBox.BorderStyle = "FixedSingle"
$destBox.Anchor = "Top, Left, Right"
$destBox.AllowDrop = $true
$taskCard.Controls.Add($destBox)

$destBox.Add_GotFocus({ if ($destBox.ForeColor -eq [System.Drawing.Color]::Gray) { $destBox.Text = ""; $destBox.ForeColor = "Black" } })
$destBox.Add_LostFocus({ if (!$destBox.Text) { $destBox.Text = "Destination path..."; $destBox.ForeColor = "Gray" } })

$destBox.Add_DragEnter({
        if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) {
            $_.Effect = [Windows.Forms.DragDropEffects]::Copy
        }
    })
$destBox.Add_DragDrop({
        $files = $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)
        if ($files.Count -gt 0) {
            $destBox.Text = $files[0]
            $destBox.ForeColor = "Black"
        }
    })

$destBrowse = New-Object Windows.Forms.Button
$destBrowse.Text = "..."
$destBrowse.Size = "40,35"
$destBrowse.Location = "910,138"
$destBrowse.Anchor = "Top, Right"
$destBrowse.BackColor = $global:bgSecondary
$destBrowse.ForeColor = [System.Drawing.Color]::DimGray
$destBrowse.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$destBrowse.FlatStyle = "Flat"
$destBrowse.FlatAppearance.BorderSize = 0
$destBrowse.Cursor = [System.Windows.Forms.Cursors]::Hand
$taskCard.Controls.Add($destBrowse)

$destBrowse.Add_Click({
        $p = Select-Path
        if ($p) { $destBox.Text = $p; $destBox.ForeColor = "Black" }
    })

# ---------- Task Label ----------
$nameLbl = New-Object Windows.Forms.Label
$nameLbl.Text = "Task Label"
$nameLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$nameLbl.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#7A8B9A")
$nameLbl.Location = "20,185"
$nameLbl.AutoSize = $true
$taskCard.Controls.Add($nameLbl)

$nameBox = New-Object Windows.Forms.TextBox
$nameBox.Text = "e.g., Weekly Backup"
$nameBox.ForeColor = "Gray"
$nameBox.Location = "20,208"
$nameBox.Size = "300,35"
$nameBox.Font = $global:uiFont
$nameBox.BorderStyle = "FixedSingle"
$nameBox.Anchor = "Top, Left"
$taskCard.Controls.Add($nameBox)

$nameBox.Add_GotFocus({ if ($nameBox.ForeColor -eq [System.Drawing.Color]::Gray) { $nameBox.Text = ""; $nameBox.ForeColor = "Black" } })
$nameBox.Add_LostFocus({ if (!$nameBox.Text) { $nameBox.Text = "e.g., Weekly Backup"; $nameBox.ForeColor = "Gray" } })

# ---------- Options ----------
$optsLbl = New-Object Windows.Forms.Label
$optsLbl.Text = "Global Options"
$optsLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$optsLbl.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#7A8B9A")
$optsLbl.Location = "340,185"
$optsLbl.AutoSize = $true
$optsLbl.Anchor = "Top, Left"
$taskCard.Controls.Add($optsLbl)

$chkE = New-Object Windows.Forms.CheckBox
$chkE.Text = "/E (Subdirs)"
$chkE.Location = "340,210"
$chkE.AutoSize = $true
$chkE.Checked = $true
$chkE.Font = $global:uiFont
$chkE.Anchor = "Top, Left"
$taskCard.Controls.Add($chkE)

$chkMir = New-Object Windows.Forms.CheckBox
$chkMir.Text = "/MIR (Mirror)"
$chkMir.Location = "450,210"
$chkMir.AutoSize = $true
$chkMir.Font = $global:uiFont
$chkMir.Anchor = "Top, Left"
$taskCard.Controls.Add($chkMir)

$chkMove = New-Object Windows.Forms.CheckBox
$chkMove.Text = "/MOVE (Del Src)"
$chkMove.Location = "570,210"
$chkMove.AutoSize = $true
$chkMove.Font = $global:uiFont
$chkMove.Anchor = "Top, Left"
$taskCard.Controls.Add($chkMove)

# ---------- Add Task Button ----------
$addBtn = New-Object Windows.Forms.Button
$addBtn.Text = "+ Add Task"
$addBtn.Location = "720,205"
$addBtn.Size = "120,40"
$addBtn.Anchor = "Top, Right"
$addBtn.BackColor = $global:bgPrimary
$addBtn.ForeColor = $global:fgPrimary
$addBtn.Font = $global:btnFont
$addBtn.FlatStyle = "Flat"
$addBtn.FlatAppearance.BorderSize = 0
$addBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
$taskCard.Controls.Add($addBtn)

# ---------- Delete Button ----------
$removeBtn = New-Object Windows.Forms.Button
$removeBtn.Text = "DELETE SELECTED"
$removeBtn.Location = "850,205"
$removeBtn.Size = "100,40"
$removeBtn.Anchor = "Top, Right"
$removeBtn.BackColor = $global:bgDanger
$removeBtn.ForeColor = $global:fgDanger
$removeBtn.Font = $global:btnFont
$removeBtn.FlatStyle = "Flat"
$removeBtn.FlatAppearance.BorderSize = 0
$removeBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
$taskCard.Controls.Add($removeBtn)

# ===============================
# TASKS LIST CARD
# ===============================
$listCard = New-Object Windows.Forms.Panel
$listCard.Location = "30,350"
$listCard.Size = "970,230"
$listCard.Anchor = "Top, Bottom, Left, Right"
$listCard.BackColor = $global:bgCard
$listCard.Padding = New-Object System.Windows.Forms.Padding(10, 10, 10, 10)
$mainPanel.Controls.Add($listCard)

$listView = New-Object Windows.Forms.ListView
$listView.Dock = "Fill"
$listView.View = "Details"
$listView.FullRowSelect = $true
$listView.CheckBoxes = $true
$listView.GridLines = $false
$listView.BorderStyle = "None"
$listView.Font = $global:uiFont
$listView.BackColor = $global:bgCard

[void]$listView.Columns.Add("Label", 150)
[void]$listView.Columns.Add("Source", 200)
[void]$listView.Columns.Add("Destination", 250)
[void]$listView.Columns.Add("Hotkey", 100)
[void]$listView.Columns.Add("Status", 80)

$listCard.Controls.Add($listView)

# Load profiles
Import-Csv $configFile -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Label) {
        $item = New-Object Windows.Forms.ListViewItem($_.Label)
        [void]$item.SubItems.Add($_.Source)
        [void]$item.SubItems.Add($_.Destination)
        [void]$item.SubItems.Add($_.Hotkey)
        [void]$item.SubItems.Add("Idle")
        [void]$listView.Items.Add($item)
    }
}

# Double click to edit hotkey
$listView.Add_DoubleClick({
        if ($listView.SelectedItems.Count -eq 0) { return }
        $item = $listView.SelectedItems[0]
        $hotkey = Read-Hotkey
        if ($hotkey) {
            $item.SubItems[3].Text = $hotkey.ToUpper()
            Save-Profiles
        }
    })

# ===============================
# BOTTOM PANEL - Progress & Actions
# ===============================
$bottomPanel = New-Object Windows.Forms.Panel
$bottomPanel.Height = 110
$bottomPanel.Dock = "Bottom"
$bottomPanel.BackColor = $global:bgCard
$mainPanel.Controls.Add($bottomPanel)

$progressLblTitle = New-Object Windows.Forms.Label
$progressLblTitle.Text = "Copy Progress"
$progressLblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$progressLblTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#7A8B9A")
$progressLblTitle.Location = "30,15"
$progressLblTitle.AutoSize = $true
$bottomPanel.Controls.Add($progressLblTitle)

$progressLabel = New-Object Windows.Forms.Label
$progressLabel.Text = "0% Complete"
$progressLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$progressLabel.ForeColor = $global:bgPrimary
$progressLabel.Anchor = "Top, Right"
$progressLabel.Location = "680,15"
$progressLabel.AutoSize = $true
$bottomPanel.Controls.Add($progressLabel)

$progressBar = New-Object Windows.Forms.ProgressBar
$progressBar.Location = "30,40"
$progressBar.Size = "970,10"
$progressBar.Anchor = "Top, Left, Right"
$progressBar.Style = "Continuous"
$bottomPanel.Controls.Add($progressBar)

$copyBtn = New-Object Windows.Forms.Button
$copyBtn.Text = "Start All Tasks"
$copyBtn.Location = "240,65"
$copyBtn.Size = "160,40"
$copyBtn.Anchor = "Bottom"
$copyBtn.BackColor = $global:bgPrimary
$copyBtn.ForeColor = $global:fgPrimary
$copyBtn.Font = $global:btnFont
$copyBtn.FlatStyle = "Flat"
$copyBtn.FlatAppearance.BorderSize = 0
$copyBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
$bottomPanel.Controls.Add($copyBtn)

$stopBtn = New-Object Windows.Forms.Button
$stopBtn.Text = "Stop Processing"
$stopBtn.Location = "420,65"
$stopBtn.Size = "160,40"
$stopBtn.Anchor = "Bottom"
$stopBtn.BackColor = $global:bgCard
$stopBtn.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#404040")
$stopBtn.Font = $global:btnFont
$stopBtn.FlatStyle = "Flat"
$stopBtn.FlatAppearance.BorderSize = 1
$stopBtn.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml("#D0D0D0")
$stopBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
$bottomPanel.Controls.Add($stopBtn)

# ===============================
# CAPTURE HOTKEY
# ===============================
function ConvertTo-NormalizedKey($key) {

    switch ($key) {
        "D0" { "0" }
        "D1" { "1" }
        "D2" { "2" }
        "D3" { "3" }
        "D4" { "4" }
        "D5" { "5" }
        "D6" { "6" }
        "D7" { "7" }
        "D8" { "8" }
        "D9" { "9" }
        default { $key }
    }
}

function Read-Hotkey {

    $captureForm = New-Object Windows.Forms.Form
    $captureForm.Text = "Press Hotkey"
    $captureForm.Size = "300,120"
    $captureForm.StartPosition = "CenterParent"
    $captureForm.KeyPreview = $true

    # store result on form object
    $captureForm.Tag = $null

    $label = New-Object Windows.Forms.Label
    $label.Text = "Press desired key combination..."
    $label.AutoSize = $true
    $label.Location = "20,20"
    $captureForm.Controls.Add($label)

    $captureForm.Add_KeyDown({

            $mods = @()

            if ($_.Control) { $mods += "CTRL" }
            if ($_.Alt) { $mods += "ALT" }
            if ($_.Shift) { $mods += "SHIFT" }

            $key = ConvertTo-NormalizedKey($_.KeyCode.ToString())

            # ignore modifier-only keys
            if ($key -in @("ControlKey", "Menu", "ShiftKey")) { return }

            # save result INTO FORM (important fix)
            $this.Tag = ($mods + $key) -join "+"

            $this.Close()
        })

    $captureForm.ShowDialog() | Out-Null

    return $captureForm.Tag
}

# ===============================
# SAVE FUNCTION
# ===============================
function Save-Profiles {
    $data = foreach ($row in $listView.Items) {
        [PSCustomObject]@{
            Label       = $row.Text
            Source      = $row.SubItems[1].Text
            Destination = $row.SubItems[2].Text
            Hotkey      = $row.SubItems[3].Text
        }
    }
    $data | Export-Csv $configFile -NoTypeInformation
}

# ADD PROFILE
$addBtn.Add_Click({

        # Prevent placeholder values
        if (
            $nameBox.Text -eq "Label" -or
            $srcBox.Text -eq "Choose files" -or
            $destBox.Text -eq "Destination" -or
            [string]::IsNullOrWhiteSpace($nameBox.Text) -or
            [string]::IsNullOrWhiteSpace($srcBox.Text) -or
            [string]::IsNullOrWhiteSpace($destBox.Text)
        ) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please enter valid Label, Source and Destination.",
                "Invalid Profile"
            )
            return
        }

        # Validate paths exist
        $sources = $srcBox.Text -split '\|'
        foreach ($s in $sources) {
            if (!(Test-Path $s)) {
                [System.Windows.Forms.MessageBox]::Show("Invalid Source Path: $s")
                return
            }
        }

        if (!(Test-Path $destBox.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Invalid Destination Path")
            return
        }

        # Add profile
        $item = New-Object Windows.Forms.ListViewItem($nameBox.Text)
        [void]$item.SubItems.Add($srcBox.Text)
        [void]$item.SubItems.Add($destBox.Text)
        [void]$item.SubItems.Add("")

        [void]$listView.Items.Add($item)
        Save-Profiles
    })

# REMOVE
$removeBtn.Add_Click({
        $toRemove = @($listView.CheckedItems)
        foreach ($i in $toRemove) { $listView.Items.Remove($i) }
        Save-Profiles
    })

# ===============================
# COMPLETION ALERT SOUND
# ===============================
function Invoke-CompletionAlert {
    param([bool]$Success = $true)
    
    if ($chkNotify.Checked) {
        $trayIcon.Visible = $true
        if ($Success) {
            $trayIcon.ShowBalloonTip(3000, "EasyRoboCopy", "Task(s) Completed Successfully!", [System.Windows.Forms.ToolTipIcon]::Info)
        }
        else {
            $trayIcon.ShowBalloonTip(3000, "EasyRoboCopy", "Task(s) Completed with Errors!", [System.Windows.Forms.ToolTipIcon]::Error)
        }
    }

    if ($Success) {
        if (-not $global:AlertSoundPath -or -not (Test-Path $global:AlertSoundPath)) { return }
        try {
            $player = New-Object System.Windows.Media.MediaPlayer
            $player.Open([Uri]::new($global:AlertSoundPath))
            $player.Play()
        }
        catch {}
    }
}

# ===============================
# ROBOCOPY ENGINE (NON-BLOCKING)
# ===============================
function Start-RobocopyJob($source, $dest) {

    $global:StopRequested = $false
    $progressBar.Value = 0
    $jobSuccess = $true

    $opts = ""
    if ($chkE.Checked) { $opts += " /E" }
    if ($chkMir.Checked) { $opts += " /MIR" }
    if ($chkMove.Checked) { $opts += " /MOVE" }

    $sources = $source -split '\|'

    foreach ($s in $sources) {
        if ($global:StopRequested) { $jobSuccess = $false; break }

        if (Test-Path $s -PathType Leaf) {
            $srcDir = Split-Path $s
            $file = Split-Path $s -Leaf
            $robocopyArgs = "`"$srcDir`" `"$dest`" `"$file`" /MT:16 /R:2 /W:2$opts"
        }
        else {
            $robocopyArgs = "`"$s`" `"$dest`" /MT:16 /R:2 /W:2$opts"
        }

        $proc = New-Object System.Diagnostics.Process
        $global:RobocopyProcess = $proc
        $proc.StartInfo.FileName = "robocopy.exe"
        $proc.StartInfo.Arguments = $robocopyArgs
        $proc.StartInfo.RedirectStandardOutput = $true
        $proc.StartInfo.UseShellExecute = $false
        $proc.StartInfo.CreateNoWindow = $true
        $proc.Start() | Out-Null

        while (-not $proc.HasExited) {

            if ($global:StopRequested) { $jobSuccess = $false; break }

            if (!$proc.StandardOutput.EndOfStream) {
                $line = $proc.StandardOutput.ReadLine()

                if ($line -match "(\d+)%") {
                    $p = [int]$matches[1]
                    $progressBar.Value = $p
                    $progressLabel.Text = "$p %"
                }
            }

            [System.Windows.Forms.Application]::DoEvents()
        }

        # Robocopy exit codes: 0-7 = success, 8+ = failure
        if (-not $global:StopRequested) {
            $proc.WaitForExit()
            if ($proc.ExitCode -ge 8) { $jobSuccess = $false }
        }
    }

    return $jobSuccess
}

# ===============================
# START COPY
# ===============================
$copyBtn.Add_Click({

        $checked = $listView.CheckedItems
        $allSuccess = $true

        if ($checked.Count -gt 0) {
            foreach ($row in $checked) {
                $result = Start-RobocopyJob $row.SubItems[1].Text $row.SubItems[2].Text
                if (-not $result) { $allSuccess = $false }
            }
        }
        else {
            $allSuccess = Start-RobocopyJob $srcBox.Text $destBox.Text
        }

        Invoke-CompletionAlert -Success $allSuccess
    })

# ===============================
# STOP BUTTON
# ===============================
$stopBtn.Add_Click({
        $global:StopRequested = $true
        if ($global:RobocopyProcess) {
            try { $global:RobocopyProcess.Kill() }catch {}
            $progressLabel.Text = "Stopped"
        }
    })

# ===============================
# HOTKEY POLLER (FIXED & CLEAN)
# ===============================

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class KeyState {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);
}
"@

function Test-KeyPressed($keyCode) {
    return ([KeyState]::GetAsyncKeyState($keyCode) -band 0x8000) -ne 0
}

$global:LastHotkeyTime = 0

$hotkeyTimer = New-Object Windows.Forms.Timer
$hotkeyTimer.Interval = 120

$hotkeyTimer.Add_Tick({

        foreach ($row in $listView.Items) {

            $hk = $row.SubItems[3].Text
            if ([string]::IsNullOrWhiteSpace($hk)) { continue }

            $parts = $hk.ToUpper().Split("+")
            $ctrl = $parts -contains "CTRL"
            $alt = $parts -contains "ALT"
            $shift = $parts -contains "SHIFT"
            $key = $parts[-1]

            # modifier checks
            if ($ctrl -and !(Test-KeyPressed 0x11)) { continue }
            if ($alt -and !(Test-KeyPressed 0x12)) { continue }
            if ($shift -and !(Test-KeyPressed 0x10)) { continue }

            try {
                $vk = [System.Windows.Forms.Keys]::$key
            }
            catch { continue }

            if (Test-KeyPressed([int]$vk)) {

                $now = [Environment]::TickCount
                if (($now - $global:LastHotkeyTime) -lt 700) { continue }

                $global:LastHotkeyTime = $now

                $result = Start-RobocopyJob $row.SubItems[1].Text $row.SubItems[2].Text
                Invoke-CompletionAlert -Success $result
                break
            }
        }
    })

$hotkeyTimer.Start()

# ===============================
# START APPLICATION LOOP (FIX)
# ===============================
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::Run($form)