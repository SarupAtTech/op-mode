# op-mode

English | [日本語](README.ja.md)

An Emacs interface to the [1Password CLI](https://developer.1password.com/docs/cli/) (`op`).
Browse and view items, copy passwords / usernames / one-time passwords, and create login items without leaving Emacs.

Items from all of your accounts can be searched together, like 1Password's "All Accounts".

Copied secrets are automatically removed from the kill ring and the clipboard after a while, and session tokens and caches expire when idle.

## Requirements

- Emacs 30.2 or later
- 1Password CLI v2 (`op`)
- Recommended: 1Password desktop app CLI integration (lets you sign in with biometrics)

## Installation

### package-vc (built into Emacs 30)

```elisp
(use-package op-mode
  :vc (:url "https://github.com/SarupAtTech/op-mode" :rev :newest)
  :config
  (op-mode 1))
```

### Manual

Put `op-mode.el` in a directory on your `load-path`.

```elisp
(add-to-list 'load-path "~/.emacs.d/lisp")
(require 'op-mode)
(op-mode 1)
```

## Configuration example

```elisp
;; Search every account, like 1Password's "All Accounts"
;; (setq op-account 'all)

;; Or use a single account. Only needed if you have several accounts
;; (leave it nil for a single account).
;; Use the URL shown by `op account list`, the email address, or the account ID.
;; You can also pick one interactively with M-x op-select-account.
(setq op-account nil)

;; Vault shown at startup (nil means all vaults)
(setq op-default-vault "Private")

;; Use the password method if you don't use the desktop app integration
;; (setq op-signin-method 'password)
```

## Usage

When `op-mode` is enabled, commands are available under `C-c P` (change it with `op-mode-prefix-key`).

| Key | Command | Description |
|---|---|---|
| `C-c P l` | `op-list-items` | Open the item list (also `M-x op`) |
| `C-c P w` | `op-copy-password` | Pick an item with completion and copy its password |
| `C-c P u` | `op-copy-username` | Same, copy the username |
| `C-c P o` | `op-copy-otp` | Same, copy the one-time password |
| `C-c P r` | `op-read` | Read an `op://vault/item/field` reference and copy it |
| `C-c P i` | `op-insert-reference` | Insert an `op://` reference at point (the secret itself is not inserted) |
| `C-c P c` | `op-create-login` | Create a login item with a generated password |
| `C-c P x` | `op-clear-clipboard` | Clear copied secrets immediately |
| `C-c P a` | `op-select-account` | Choose the account to use, or "All accounts" |
| `C-c P s` / `S` | `op-signin` / `op-signout` | Sign in / sign out |
| `C-c P ?` | `op-whoami` | Show the signed-in account |

### Item list (`op-list-mode`)

Items are sorted by account → vault → title when showing all accounts, by vault → title when showing all vaults of one account, and by title for a single vault. An "Account" column appears when showing all accounts.

| Key | Description |
|---|---|
| `RET` | Show item details |
| `w` / `u` / `o` | Copy password / username / OTP |
| `l` / `b` | Copy URL / open it in a browser |
| `r` | Copy an `op://` reference |
| `A` | Switch account (or show all accounts) |
| `v` | Switch vault (with all accounts, picking a vault also narrows to its account) |
| `/` | Filter by regexp on title and additional info (empty clears it) |
| `c` | Create a login item |
| `D` | Archive the item |
| `g` | Refresh |
| `S` | Sort by column |

### Item details (`op-item-mode`)

Secret values such as passwords are hidden by default.

| Key | Description |
|---|---|
| `RET` / `w` | Copy the field at point (for an OTP field, copies the current code) |
| `TAB` | Show / hide secret values |
| `o` | Copy the OTP |
| `b` | Open the URL in a browser |
| `n` / `p` | Move to the next / previous field |
| `g` | Refetch (bypasses the cache) |

## Starting the 1Password app

With the desktop app integration (`op-signin-method` = `app`), op-mode starts the 1Password app if it is not running:

- On the first `op` call in each Emacs session, it checks whether the app is running and, if not, starts it and waits up to `op-app-launch-timeout` seconds (15 by default).
- If `op` later reports that it cannot reach the app (for example, the app was quit), it starts the app and retries once.
- The app is started detached, so it keeps running after Emacs exits.
- Unlocking the app and approving the CLI are still done by you.

Set `op-app-platform` to match your environment (default: `linux`):

| `op-app-platform` | Check | Launch |
|---|---|---|
| `linux` (default) | `pgrep -x 1password` | `1password --silent` (starts minimized to the tray) |
| `macos` | `pgrep -x 1Password` | `open -g -a 1Password` (starts in the background) |
| `windows` / `wsl` | `Get-Process 1Password` via `powershell.exe` | Starts `1Password.exe` from `%LOCALAPPDATA%\1Password\app\8` (or `%ProgramFiles%`) via `powershell.exe` |
| `auto` | Detected from `system-type` (WSL from `$WSL_DISTRO_NAME`) | |

If your installation differs, set the commands yourself:

```elisp
(setq op-app-check-command '("pgrep" "-x" "1password")
      op-app-launch-command '("/opt/1Password/1password" "--silent"))
```

On WSL2, the app integration usually means calling the Windows `op.exe` (e.g. `(setq op-executable "op.exe")`).

To turn this off: `(setq op-app-auto-launch nil)`.

## All accounts

Set `op-account` to `all` (or choose "All accounts" with `M-x op-select-account`) to work with every account known to `op`.

- `op` handles one account per command, so op-mode lists each account (`op item list --account ...`) and merges the results. With `op-parallel-fetch` (on by default), accounts are fetched in parallel.
- Each item remembers its account, so copying, opening, OTP and archiving use the right account automatically.
- If one account fails, items from the other accounts are still shown and the failed accounts are reported in the echo area. An account that is not signed in is retried alone, signing in if needed.
- Commands that act on one account (`op-read`, `op-create-login`, `op-signin`, `op-whoami`) ask which account to use.
- With the password sign-in method, you sign in to each account separately; tokens are kept per account. With the app integration, whether each account needs its own approval depends on 1Password.
- `op-default-vault` is ignored when showing all accounts.

## How secrets are handled

### Clipboard

- When copying, a random marker (`op-mode-marker:<UUID>`) is pushed onto the kill ring first, followed by the actual secret.
- After `op-clipboard-clear-seconds` (45 seconds by default), only the marker and the value pushed right after it are removed from the kill ring, and the string contents are overwritten. Anything else you copied in the meantime is kept.
- The system clipboard is emptied only if it still holds that secret or the marker.
- Entries already captured by an OS clipboard history tool cannot be removed. Configure that tool to exclude them.

### Sessions and caches

Inspired by the password handling of the Emacs mailer [Mew](https://github.com/kazu-yamamoto/Mew).

- With the password sign-in method, the session token is discarded after `op-session-lifetime` minutes of inactivity (30 by default), and the session is also signed out on the 1Password side. Each use extends the lifetime.
- On an authentication error, the stale token is discarded before signing in again.
- Item details are kept in memory only when `op-cache-secrets` is `t`, for `op-secret-cache-lifetime` minutes (5 by default, extended on use). Nothing is cached by default, and OTP codes are never cached.
- On Emacs exit, any remaining secrets, tokens and caches are wiped.
- The account password is passed to `op` via stdin, never as a command-line argument.

## Customization

| Variable | Default | Description |
|---|---|---|
| `op-executable` | `"op"` | Path to the `op` command |
| `op-account` | `nil` | `nil` (default account), an account string, or `all` (all accounts) |
| `op-parallel-fetch` | `t` | Fetch the item lists of all accounts in parallel |
| `op-default-vault` | `nil` | Vault shown at startup (nil means all vaults) |
| `op-list-categories` | `nil` | Categories to list (e.g. `("Login" "Password")`) |
| `op-signin-method` | `app` | `app` (desktop app integration) or `password` |
| `op-app-auto-launch` | `t` | Start the 1Password app if it is not running (app integration only) |
| `op-app-platform` | `linux` | `linux`, `macos`, `windows`, `wsl` or `auto` |
| `op-app-check-command` | `nil` | Command that exits 0 when the app is running (nil = platform default) |
| `op-app-launch-command` | `nil` | Command that starts the app (nil = platform default) |
| `op-app-launch-timeout` | `15` | Seconds to wait for the app to start |
| `op-app-connection-error-regexp` | (see source) | Regexp for op errors meaning the app cannot be reached |
| `op-auto-signin` | `t` | Sign in automatically when not signed in |
| `op-clipboard-clear-seconds` | `45` | Seconds before copied secrets are cleared (nil to never clear) |
| `op-session-lifetime` | `30` | Idle minutes before the session token is discarded |
| `op-cache-secrets` | `nil` | Cache item details in memory |
| `op-secret-cache-lifetime` | `5` | Idle minutes before cached items are wiped |
| `op-generate-password-recipe` | `"letters,digits,symbols,32"` | Recipe for passwords generated by `op-create-login` |
| `op-mode-prefix-key` | `"C-c P"` | Prefix key for `op-mode` (set before loading) |

## Troubleshooting

- **`No account matches op-account`** (op reports `found no accounts for filter "..."`): No account matches `op-account`. Choose one with `M-x op-select-account`, or set it to `nil`.
- **Asked for the app even with `op-signin-method` set to `password`**: op uses the app integration whenever it is enabled in the 1Password app. op-mode therefore runs op with `OP_BIOMETRIC_UNLOCK_ENABLED=false` in password mode. Add each account once with `op account add` in a terminal; otherwise there is no account to sign in to.
- **Emacs seems to hang with the app integration**: `op` is called synchronously, so Emacs waits until you respond to the 1Password authentication prompt.

## License

[MIT License](LICENSE)

This project is not affiliated with or endorsed by 1Password (AgileBits Inc.). 1Password is a trademark of AgileBits Inc.
