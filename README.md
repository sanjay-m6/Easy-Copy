# EasyRoboCopy

EasyRoboCopy is a modern, graphical user interface (GUI) wrapper for the powerful Windows `robocopy.exe` command-line utility. It simplifies the process of creating, managing, and executing complex file copy and backup tasks without needing to remember complex command-line arguments.

## Features

- **Modern UI:** A clean, responsive, card-based interface built with Windows Forms.
- **Task Management:** Save frequently used copy operations as profiles (tasks) with individual Hotkeys for quick execution.
- **Drag and Drop:** Easily drag and drop single or multiple files directly from Windows Explorer into the Source and Destination fields.
- **Multi-File Selection:** Select multiple discrete files using the Browse button.
- **Global Options:** Easily toggle advanced `robocopy` flags:
  - `/E (Subdirs)`: Copies subdirectories, including empty ones.
  - `/MIR (Mirror)`: Mirrors a directory tree (equivalent to `/E` plus `/PURGE`). **Warning:** This will delete files in the destination that no longer exist in the source!
  - `/MOVE (Del Src)`: Moves files and directories (deletes them from the source after they are copied).
- **Global Hotkeys:** Assign a global keyboard shortcut (e.g., `CTRL+NUMPAD1`) to a task to trigger it instantly from anywhere in Windows.
- **System Tray Integration:** App minimizing neatly minimizes into the System Tray to stay out of the way while running background copies.
- **Standalone Executable:** Compiled using PS2EXE so it can be run on any Windows system without needing to invoke traditional PowerShell script execution policies.

## Installation & Compilation

EasyRoboCopy is written as a PowerShell script (`RoboCopyGUI_1.0.ps1`). To turn it into a standalone Windows executable (`.exe`), you will need to compile it using the `PS2EXE` module.

### Prerequisites
You need the `PS2EXE` module installed in PowerShell.
```powershell
Install-Module PS2EXE -Scope CurrentUser
```

### Compiling to EXE
Run the following command in PowerShell in the same directory as the script. This will compile it into an executable and hide the default console window:

```powershell
Invoke-PS2EXE -InputFile "RoboCopyGUI_1.0.ps1" -OutputFile "EasyRoboCopy.exe" -NoConsole -STA -IconFile "EasyRoboCopy.ico" -Title "EasyRoboCopy" -Description "RoboCopy GUI Tool"
```

## How to Use

1. **Launch `EasyRoboCopy.exe`.**
2. **Create a Task:**
   - Define a **Task Label** (e.g., "Daily Work Backup").
   - Set the **Source Path** (use the `...` button or drag & drop files).
   - Set the **Destination Path**.
   - Select your preferred Options (`/E`, `/MIR`, `/MOVE`).
   - Click **+ Add Task**.
3. **Set a Hotkey (Optional):**
   - Double-click a task in the "Tasks List" under the "Hotkey" column.
   - Press the key combination you want to use (e.g., `CTRL + SHIFT + B`).
4. **Execute:**
   - Select one or more tasks in the Tasks List and click **Start All Tasks**.
   - Or, simply press the assigned Hotkey from anywhere in Windows.

## Common Use Cases

Here are some everyday scenarios where EasyRoboCopy shines:

### 1. The "End of Day" Backup (Mirroring)
**Scenario:** You have a working folder on your laptop (`C:\Work\Projects`) and you want an exact, up-to-date copy on your external hard drive (`E:\Backups\Projects`) at the end of every day.
**How to set it up:**
- **Source:** `C:\Work\Projects`
- **Destination:** `E:\Backups\Projects`
- **Options:** Check `/MIR (Mirror)`
- **Why it's great:** Unlike a normal copy that just piles up files, `/MIR` makes the destination look *exactly* like the source. If you deleted a temporary file from your laptop today, EasyRoboCopy will delete it from the backup too, saving space and preventing clutter.

### 2. Moving Large Media Files (Freeing up space)
**Scenario:** Your computer's hard drive is running out of space because of your `C:\Downloads\Videos` folder. You want to move them all to your massive NAS or external drive (`Z:\Archive\Videos`) and delete the originals so you have space again.
**How to set it up:**
- **Source:** `C:\Downloads\Videos`
- **Destination:** `Z:\Archive\Videos`
- **Options:** Check `/MOVE (Del Src)` and `/E (Subdirs)`
- **Why it's great:** Moving gigabytes of data using standard Windows cut-and-paste can crash or freeze. EasyRoboCopy uses the robust Robocopy engine which handles massive transfers perfectly. Once a file is safely copied and verified, it deletes the original for you automatically.

### 3. The "One-Click Deploy" (Using Hotkeys)
**Scenario:** You are a developer or designer who frequently updates a website folder (`C:\Dev\MyWebsite`) and needs to copy those changes over to a local testing server (`\\Server\wwwroot\MyWebsite`). Doing this 30 times a day manually is tedious.
**How to set it up:**
- Set up the Source and Destination as usual.
- Save the task as "Deploy to Test Server".
- In the Tasks List, double-click the "Hotkey" column for this task and press `CTRL + SHIFT + D`.
**Why it's great:** Now, no matter what app you are currently working in, simply hitting `CTRL + SHIFT + D` will instantly trigger the copy process in the background. Note: The EasyRoboCopy app must be running (it can be minimized to your system tray).

### 4. Consolidating Multiple Folders into One
**Scenario:** You have photos scattered across `C:\CameraRoll`, `D:\OldPhonePhotos`, and `E:\Vacation2023` and want to dump them all into a master `F:\All_Photos` drive.
**How to set it up:**
- Click the `...` Browse button next to Source, hold `CTRL`, and click all three of those source folders to select them at once.
- **Destination:** `F:\All_Photos`
- **Options:** Check `/E (Subdirs)` 
- **Why it's great:** Instead of opening three different windows and babysitting three different copy jobs, you build the queue once. The app will smoothly process each source folder one after the other into your master destination.

## Where is Data Saved?
Your task profiles and hotkeys are saved locally in a CSV file located at:
`%APPDATA%\RoboCopyProfiles.csv`
