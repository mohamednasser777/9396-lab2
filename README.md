# OS Lab 2 - Antivirus
A shell-based antivirus. A daemon (`antivirusd.sh`) watches a directory, and when
something changes it scans the files, quarantines the malicious ones, and
deletes them from the watched directory. A second script (`restore.sh`) lets a
user review the quarantine and either restore or permanently delete each file.
A `Makefile` runs everything with short commands.

## Folder hierarchy

```
os_lab2_antivirus/
├── antivirusd.sh        # the antivirus daemon (polling loop + scanner)
├── restore.sh           # interactive restore / delete tool
├── Makefile             # targets: antivirus, restore, prepare
├── README.md            # this file
├── .gitignore           # keeps generated files out of git
│
│   Created at runtime (not committed):
├── dir/                 # the monitored directory (files only, no subdirectories)
├── malicious_dir/       # quarantine directory (created by `make prepare`)
├── directory-info.last  # snapshot taken at the last scan
└── directory-info.new   # snapshot taken on the current check
```

## How it works

### antivirusd.sh

```
./antivirusd.sh <dir> <malicious_dir> <interval-secs>
```

1. **Argument checks.** It needs exactly three arguments, both directories must
   exist, and the interval must be a positive integer. Otherwise it prints a
   usage or error message to stderr and exits with status 1.
2. **Change detection.** Every cycle it runs `ls -l <dir> > directory-info.new`
   and compares it with `directory-info.last` using `cmp -s`.
   - If `directory-info.last` does not exist (first run), it scans immediately.
   - If the two files are identical, it sleeps for the interval and checks
     again. No scan happens.
   - If they differ, it copies `directory-info.new` to `directory-info.last`
     and scans.
3. **Scan.** For every regular file directly inside `<dir>`, the file is
   malicious if either rule matches (see the next section). For each malicious
   file the daemon:
   1. prints `<file> is malicious and it is DELETED` (the file's base name),
   2. copies the file into `<malicious_dir>`,
   3. deletes the original only if the copy succeeded.

### What counts as malicious, and where the lists are defined

Both lists are hardcoded in `antivirusd.sh`, inside the scan loop:

- **Flagged extensions** (`.exe`, `.bat`, `.vbs`, `.scr`, `.ps1`): the patterns in the
  `case` statement that sets `is_malicious=1`.
- **Flagged keywords** (`virus`, `trojan`, `malware`, `worm`, `ransomware`): the
  pattern in the `grep -iaEq "..."` command that is only run when the
  extension did not already match.

To find them quickly: `grep -n 'is_malicious=1\|grep -iaEq' antivirusd.sh`

Rules in detail:

- Extensions are matched exactly as written, so `.EXE` is not flagged.
- Keywords are matched as case-insensitive substrings of the file's contents
  (so "earworm" matches "worm"). Binary files are searched as text.
- A file matching both rules is handled once.

### restore.sh

```
./restore.sh <dir> <malicious_dir>
```

1. Same style of argument checks (exactly two existing directories).
2. If `<malicious_dir>` is empty it prints `No malicious files to review.` and exits.
3. Otherwise it shows a numbered list of the quarantined files and asks for a
   number. Non-numeric or out-of-range input is rejected and asked again.
4. For the chosen file it offers:
   - **1** restore it to `<dir>`, printing `Restored <file> to <dir>.`
   - **2** delete it permanently, printing `<file> permanently deleted.`
   - **3** leave it as-is and go back to the list
   - **4** quit (an addition, so the user always has a way out)
5. The list is shown again until the quarantine is empty or the user quits.
   End of input (Ctrl+D) also exits cleanly.

The daemon and the restore tool must not run at the same time.

## Prerequisites

- Linux with **bash** (the scripts use bash features such as arrays).
- **make**
- **git** (to clone the repository)
- Standard tools: `ls`, `cmp`, `cp`, `rm`, `grep`, `basename`, `sleep`.

On Ubuntu, bash and the standard tools come preinstalled. Install the rest with:

```bash
sudo apt update
sudo apt install -y make git
```

## Running it

1. Get the code and enter the project folder. **Always run from this folder**,
   because the snapshot files are created in the current directory:

   ```bash
   git clone <repository-url>
   cd <repository-folder>
   chmod +x antivirusd.sh restore.sh
   ```

2. Create the folder to monitor:

   ```bash
   mkdir -p dir
   ```

3. **Terminal 1:** start the daemon. `make` creates `malicious_dir` first if it
   is missing, then runs `antivirusd.sh` with the default arguments:

   ```bash
   make antivirus
   ```

   Equivalent direct command:

   ```bash
   ./antivirusd.sh dir malicious_dir 5
   ```

   The first start scans immediately. After that it checks every 5 seconds.

4. **Terminal 2:** create some files and watch Terminal 1:

   ```bash
   echo "hello" > dir/clean.txt             # not flagged
   echo "hello" > dir/setup.exe             # flagged by extension
   echo "a TROJAN inside" > dir/notes.txt   # flagged by content
   ```

   Within one interval Terminal 1 prints
   `setup.exe is malicious and it is DELETED` and
   `notes.txt is malicious and it is DELETED`. Both files are now in
   `malicious_dir` and gone from `dir`; `clean.txt` is untouched.

5. **Stop the daemon** with `Ctrl+C` in Terminal 1 (or `pkill -f antivirusd.sh`
   from another terminal).

6. Run the restore tool (with the daemon stopped):

   ```bash
   make restore
   ```

   Pick a file by its number, then choose 1, 2 or 3. Restoring a file puts it
   back into `dir`.

### Changing the arguments

The Makefile uses variables that can be overridden on the command line:

| Variable        | Default         | Meaning                          |
|-----------------|-----------------|----------------------------------|
| `DIR`           | `dir`           | directory being monitored        |
| `MALICIOUS_DIR` | `malicious_dir` | quarantine directory             |
| `TIME_INTERVAL` | `5`             | seconds between checks           |

```bash
make antivirus DIR=/tmp/watched MALICIOUS_DIR=/tmp/quarantine TIME_INTERVAL=2
make restore   DIR=/tmp/watched MALICIOUS_DIR=/tmp/quarantine
```

| Target      | What it does                                                |
|-------------|-------------------------------------------------------------|
| `antivirus` | (default) runs `prepare`, then starts the daemon            |
| `restore`   | runs `prepare`, then starts the restore tool                |
| `prepare`   | creates the quarantine directory if it does not exist       |

## Design decisions and limitations

- **Snapshots live in the current directory**, not inside the monitored folder,
  so they are never scanned or listed as changes. Run everything from the
  project folder so the daemon and the tools agree on where they are.
- **`ls -l` shows modification time only to the minute.** Two edits within the
  same minute that leave the file size unchanged produce identical listings and
  go undetected until the next real change.
- **The snapshot is updated before the scan.** Files that arrive during a scan
  show up as a change on the next cycle, so nothing is silently skipped. The
  trade-off: if the daemon is killed mid-scan, the unscanned files are not
  rescanned after a restart until the directory changes again. Deleting
  `directory-info.last` forces a full scan on the next start.
- After a scan deletes files, the next cycle sees the listing changed and runs
  one more scan that finds nothing. This is harmless and prints nothing.
- Only regular files directly inside the monitored directory are handled.
  Subdirectories are ignored, as are files whose names start with a dot.
- A file restored with `restore.sh` is flagged again on the next scan if it
  still matches a rule. A whitelist is not implemented in this version.
- The bonus tasks (cron job and whitelist) are not implemented in this version.
