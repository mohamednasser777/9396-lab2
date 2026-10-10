# OS Lab 2 - Antivirus

`antivirusd.sh` watches a directory and, when it changes, scans the files in it,
quarantines the malicious ones and deletes them from the watched directory.
`restore.sh` lets a user review the quarantine and restore or delete each file.
The `Makefile` runs both with short commands.

## Folder hierarchy

```
.
├── antivirusd.sh        # antivirus daemon (polling loop + scanner)
├── restore.sh           # interactive restore / delete tool
├── Makefile             # targets: antivirus, restore, prepare
├── README.md
├── .gitignore
│
│   Created at runtime (not committed):
├── dir/                 # monitored directory (files only)
├── malicious_dir/       # quarantine directory
├── whitelist.txt        # names of restored (safe) files
└── directory-info.last / directory-info.new   # directory snapshots
```

## Prerequisites

Bash, `make` and `git`. Bash and the standard tools (`ls`, `cmp`, `cp`, `rm`,
`grep`, `basename`, `sleep`) come with Ubuntu. Install the rest with:

```bash
sudo apt update && sudo apt install -y make git
```

## Running

Run everything from the project folder, because the snapshot files and the
whitelist are created in the current directory.

```bash
git clone <repository-url> && cd <repository-folder>
chmod +x antivirusd.sh restore.sh
mkdir -p dir
```

1. **Terminal 1:** start the daemon. `make` creates `malicious_dir` if it is missing.

   ```bash
   make antivirus
   ```

   (Same as `./antivirusd.sh dir malicious_dir 5`.)

2. **Terminal 2:** create some files.

   ```bash
   echo "hello" > dir/clean.txt            # not flagged
   echo "hello" > dir/setup.exe            # flagged by extension
   echo "a TROJAN inside" > dir/notes.txt  # flagged by content
   ```

   Within one interval, Terminal 1 prints `setup.exe is malicious and it is DELETED`
   and `notes.txt is malicious and it is DELETED`. Both files are now in
   `malicious_dir`.

3. Stop the daemon with `Ctrl+C`.

4. With the daemon stopped, review the quarantine:

   ```bash
   make restore
   ```

Arguments can be overridden: `make antivirus DIR=<dir> MALICIOUS_DIR=<quarantine> TIME_INTERVAL=<secs>`
(defaults: `dir`, `malicious_dir`, `5`). `make restore` takes `DIR` and `MALICIOUS_DIR`.

## How it works

**antivirusd.sh `<dir> <malicious_dir> <interval-secs>`**

1. Checks the arguments (three, both directories exist, interval is a positive
   integer) and exits with a message to stderr otherwise.
2. Every cycle it writes `ls -l <dir>` to `directory-info.new` and compares it with
   `directory-info.last` using `cmp -s`. If `directory-info.last` does not exist
   (first run) it scans immediately; if the files are identical it sleeps and
   checks again.
3. A scan looks at every regular file directly inside `<dir>`. Files whose names
   are in `whitelist.txt` are skipped. For each malicious file it prints
   `<file> is malicious and it is DELETED`, copies it into `<malicious_dir>`, and
   deletes the original only if the copy succeeded.
4. After the scan, `directory-info.last` is regenerated with
   `ls -l <dir> > directory-info.last`, so it reflects the directory after the
   removals.

**restore.sh `<dir> <malicious_dir>`**

- Prints `No malicious files to review.` and exits if the quarantine is empty.
- Otherwise shows a numbered list `N: name` and asks for a number (invalid input
  is asked again), then offers: `1` restore to `<dir>`
  (`Restored <file> to <dir>.`), `2` delete permanently
  (`<file> permanently deleted.`), `3` go back to the list. `Ctrl+D` exits at any
  prompt.
- A restored file is added to the whitelist (see below).
- The daemon and the restore tool must not run at the same time.

## Where the flagged lists are defined

Both are hardcoded in `antivirusd.sh`, inside the scan loop. Find them with
`grep -n 'is_malicious=1\|grep -iaEq' antivirusd.sh`.

- **Extensions** (`.exe`, `.bat`, `.vbs`, `.scr`, `.ps1`): the patterns in the `case`
  statement. Only the final extension counts and it is matched exactly:
  `file.txt.scr` is flagged; `file.scr.txt`, `file.exec` and `description.txt` are not.
- **Keywords** (`virus`, `trojan`, `malware`, `worm`, `ransomware`): the pattern in
  the `grep -iaEq` command. Matching is case-insensitive and anywhere in the file's
  contents, even inside a longer word (`wormhole` matches).

## Bonus 2: Whitelist

When a file is restored with `restore.sh` (option 1) and the copy succeeds, its
file name is appended to `whitelist.txt` in the project folder, one name per
line. A name that is already listed is not added again. During every scan,
`antivirusd.sh` checks each file's name against `whitelist.txt` (`grep -qxF`, an
exact whole-line match) before applying the extension and keyword rules, and
skips the file if it is listed. The file stays on disk, so the whitelist survives
stopping and restarting the daemon. Matching is by file name only, so a different
file with the same name is also skipped. To remove a file from the whitelist,
delete its line from `whitelist.txt`.

## Limitations

- `ls -l` shows modification time only to the minute, so two same-size edits
  within one minute give identical listings and go unnoticed until the next change.
- A file that arrives between the scan's file listing and the snapshot is recorded
  as already seen and is not scanned until the directory changes again.
- Only regular files directly inside `<dir>` are handled; subdirectories and files
  whose names start with a dot are ignored.
- Bonus 1 (cron job) is not implemented.
