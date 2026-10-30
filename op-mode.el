;;; op-mode.el --- 1Password CLI (op) interface for Emacs -*- lexical-binding: t; -*-

;; Copyright (C) 2026 SarupAtTech

;; Author: SarupAtTech
;; URL: https://github.com/SarupAtTech/op-mode
;; Version: 0.4.1
;; Package-Requires: ((emacs "30.2"))
;; Keywords: tools, convenience, password
;; SPDX-License-Identifier: MIT

;; This file is not part of GNU Emacs.

;;; License:

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:
;;
;; The above copyright notice and this permission notice shall be included in
;; all copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;; Commentary:

;; [English]
;;
;; An Emacs interface to the 1Password CLI v2 (`op').
;;
;; Main commands:
;;   M-x op-list-items     Item list buffer (tabulated-list)
;;   M-x op-copy-password  Pick an item with completion and copy its password
;;   M-x op-copy-username  Same, for the username
;;   M-x op-copy-otp       Same, for the one-time password (TOTP)
;;   M-x op-read           Read an op://vault/item/field reference and copy it
;;   M-x op-create-login   Create a Login item with a generated password
;;   M-x op-signin / op-signout
;;   M-x op-mode           Global minor mode (prefix key C-c P)
;;
;; Copied secrets are removed from the kill ring and the clipboard after
;; `op-clipboard-clear-seconds' seconds (M-x op-clear-clipboard clears them
;; immediately).  A random marker is pushed just before each secret; on
;; clearing, only the marker and the value pushed right after it are
;; removed, so anything else you copied in the meantime is kept.
;;
;; Session and cache lifetime (inspired by Mew's mew-passwd):
;;   - With the password sign-in method, the session token is discarded
;;     (and signed out on the server) after `op-session-lifetime' minutes
;;     of inactivity.  Each use extends the lifetime.
;;   - On an authentication error, the stale token is discarded before
;;     signing in again.
;;   - When `op-cache-secrets' is t, fetched item details are kept in memory
;;     for `op-secret-cache-lifetime' minutes (not cached by default).
;;   - Secrets on the clipboard, tokens and caches are wiped on Emacs exit.
;;
;; All accounts:
;;   Set `op-account' to `all' (or choose "All accounts" with
;;   M-x op-select-account) to search every account known to op, like
;;   1Password's "All Accounts".  Item lists are fetched per account (in
;;   parallel when `op-parallel-fetch' is non-nil) and merged; each item
;;   remembers its account, so copying or opening it uses that account.
;;   Commands that act on one account (op-read, op-create-login,
;;   op-signin, op-whoami) ask which account to use.
;;
;; Starting the 1Password app:
;;   With the app integration, op-mode starts the 1Password app if it is not
;;   running, on the first op call in each Emacs session and whenever op
;;   cannot reach the app.  `op-app-platform' (default `linux') selects the
;;   check / launch commands; override them with `op-app-check-command' and
;;   `op-app-launch-command'.  Unlocking the app is still up to you.
;;
;; Sign-in methods (`op-signin-method'):
;;   app      1Password desktop app integration (biometric / system auth).
;;            Recommended.
;;   password Read the account password with `read-passwd' and pass it to
;;            op via stdin.  The session token is kept only as an
;;            environment variable inside Emacs.
;;
;; Example configuration:
;;   (require 'op-mode)
;;   ;; Set op-account only if you have several accounts (nil is fine for one).
;;   ;; Use the URL shown by `op account list' (e.g. "example.1password.com"),
;;   ;; the email address, or the account ID.  M-x op-select-account also works.
;;   (setq op-account nil
;;         op-default-vault "Private")
;;   (op-mode 1)

;; [日本語]
;;
;; 1Password CLI v2 (`op') を Emacs から操作するためのパッケージ。
;;
;; 主な機能:
;;   M-x op-list-items     アイテム一覧バッファ (tabulated-list)
;;   M-x op-copy-password  補完でアイテムを選んでパスワードをコピー
;;   M-x op-copy-username  同ユーザー名
;;   M-x op-copy-otp       同ワンタイムパスワード (TOTP)
;;   M-x op-read           op://vault/item/field 参照を読んでコピー
;;   M-x op-create-login   パスワードを生成してログインアイテムを作成
;;   M-x op-signin / op-signout
;;   M-x op-mode           グローバルマイナーモード (プレフィックスキー C-c P)
;;
;; コピーしたシークレットは `op-clipboard-clear-seconds' 秒後に
;; kill-ring とクリップボードから消去される (M-x op-clear-clipboard で即時消去)。
;; コピー時に識別用マーカーを直前に積み、消去時はマーカーとその次の値だけを
;; 削除するので、その間にユーザーがコピーした別の内容は消さない。
;;
;; セッションとキャッシュの寿命 (Mew の mew-passwd を参考):
;;   - パスワード方式のセッショントークンは `op-session-lifetime' 分使わなければ
;;     破棄し、サーバー側もサインアウトする。使うたびに期限が延びる。
;;   - 認証エラー時は古いトークンを捨ててからサインインし直す。
;;   - `op-cache-secrets' を t にすると、取得したアイテム詳細を
;;     `op-secret-cache-lifetime' 分だけメモリに保持する (既定は保持しない)。
;;   - Emacs 終了時にクリップボード上の秘密の値・トークン・キャッシュを消去する。
;;
;; 全アカウント:
;;   `op-account' を `all' にする (または M-x op-select-account で
;;   "All accounts" を選ぶ) と、1Password の「すべてのアカウント」のように
;;   op に登録された全アカウントを対象にする。一覧はアカウントごとに取得して
;;   (`op-parallel-fetch' が non-nil なら並列で) まとめる。各アイテムは自分の
;;   アカウントを覚えているので、コピーや詳細表示はそのアカウントで実行する。
;;   1つのアカウントに対して動くコマンド (op-read, op-create-login,
;;   op-signin, op-whoami) は、どのアカウントで実行するかを尋ねる。
;;
;; 1Password アプリの起動:
;;   アプリ連携のとき、Emacs で最初に op を呼ぶときと、op がアプリに
;;   つながらないときに、1Password アプリが起動していなければ起動する。
;;   確認・起動のコマンドは `op-app-platform' (既定 `linux') で選び、
;;   `op-app-check-command' と `op-app-launch-command' で差し替えられる。
;;   アプリのロック解除はこれまでどおり手で行う。
;;
;; サインイン方式 (`op-signin-method'):
;;   app      1Password デスクトップアプリ連携 (生体認証/システム認証)。推奨。
;;   password マスターパスワードを read-passwd で入力し、stdin 経由で op に渡す。
;;            取得したセッショントークンは Emacs 内の環境変数としてのみ保持する。
;;
;; 設定例:
;;   (require 'op-mode)
;;   ;; op-account はアカウントが複数ある場合のみ設定する (1つなら nil のままでよい)。
;;   ;; 値は `op account list' に出る URL (例: "example.1password.com")、
;;   ;; メールアドレス、またはアカウント ID。M-x op-select-account でも選べる。
;;   (setq op-account nil
;;         op-default-vault "Private")
;;   (op-mode 1)

;;; Code:

(when (version< emacs-version "30.2")
  (error "op-mode requires Emacs 30.2 or later (this is %s)" emacs-version))

(require 'json)
(require 'seq)
(require 'subr-x)
(require 'tabulated-list)
(require 'browse-url)

;;;; Customization / カスタマイズ

(defgroup op nil
  "Interface to the 1Password CLI."
  :group 'tools
  :prefix "op-")

(defcustom op-executable "op"
  "Path to the 1Password CLI executable."
  :type 'string)

(defcustom op-account nil
  "Account to use.
nil means op's default account.  A string is passed to `--account'
\(shorthand, sign-in address, account ID or user ID).  The symbol `all'
searches every account known to op, like 1Password's \"All Accounts\"."
  :type '(choice (const :tag "Default" nil)
                 (const :tag "All accounts" all)
                 string))

(defcustom op-parallel-fetch t
  "When non-nil, fetch the item lists of all accounts in parallel.
Only used when listing all accounts."
  :type 'boolean)

(defcustom op-default-vault nil
  "Vault to show by default.  nil means all vaults."
  :type '(choice (const :tag "All vaults" nil) string))

(defcustom op-list-categories nil
  "Categories to list, e.g. (\"Login\" \"Password\").  nil means all."
  :type '(repeat string))

(defcustom op-signin-method 'app
  "How to sign in.
`app' uses 1Password desktop app integration.
`password' prompts for the account password."
  :type '(choice (const :tag "Desktop app integration" app)
                 (const :tag "Account password" password)))

(defcustom op-app-auto-launch t
  "When non-nil, start the 1Password app if it is not running.
Checked on the first op call in each Emacs session, and again when op
reports that it cannot reach the app.  Only used when
`op-signin-method' is `app'."
  :type 'boolean)

(defcustom op-app-platform 'linux
  "Platform used to choose the default app check / launch commands.
`auto' detects it from `system-type' (and WSL from $WSL_DISTRO_NAME)."
  :type '(choice (const :tag "Linux" linux)
                 (const :tag "macOS" macos)
                 (const :tag "Windows" windows)
                 (const :tag "WSL (Windows app from WSL2)" wsl)
                 (const :tag "Detect automatically" auto)))

(defcustom op-app-check-command nil
  "Command that exits with status 0 when the 1Password app is running.
A list of program and arguments.  nil uses the default for
`op-app-platform'."
  :type '(choice (const :tag "Platform default" nil) (repeat string)))

(defcustom op-app-launch-command nil
  "Command that starts the 1Password app.
A list of program and arguments.  It is started detached, so the app
keeps running after Emacs exits.  nil uses the default for
`op-app-platform'."
  :type '(choice (const :tag "Platform default" nil) (repeat string)))

(defcustom op-app-launch-timeout 15
  "Seconds to wait for the 1Password app to start."
  :type 'number)

(defcustom op-app-connection-error-regexp
  (regexp-opt '("connecting to desktop app" "connect to the 1Password app"
                "cannot connect to 1Password" "1Password app is not running"
                "desktop app is not running"))
  "Regexp matching op errors that mean the 1Password app cannot be reached."
  :type 'regexp)

(defcustom op-clipboard-clear-seconds 45
  "Seconds after which copied secrets are cleared.  nil disables clearing."
  :type '(choice (const :tag "Never" nil) integer))

(defcustom op-session-lifetime 30
  "Minutes of inactivity after which the session token is discarded.
Each use of op extends the lifetime (like Mew's password cache).
Only applies to `op-signin-method' `password'.  nil keeps it until signout."
  :type '(choice (const :tag "Until signout" nil) integer))

(defcustom op-cache-secrets nil
  "When non-nil, keep fetched item details (including secrets) in memory.
Cached entries expire after `op-secret-cache-lifetime' minutes of
inactivity and are wiped on expiry, signout and Emacs exit.
OTP codes are never cached."
  :type 'boolean)

(defcustom op-secret-cache-lifetime 5
  "Minutes of inactivity after which a cached item is wiped."
  :type 'integer)

(defcustom op-auto-signin t
  "When non-nil, sign in automatically when op reports no session."
  :type 'boolean)

(defcustom op-generate-password-recipe "letters,digits,symbols,32"
  "Recipe passed to `--generate-password' by `op-create-login'."
  :type 'string)

(defcustom op-mode-prefix-key "C-c P"
  "Prefix key for `op-command-map' in `op-mode'.
Set this before loading op-mode.el."
  :type 'string)

(defface op-label-face '((t :inherit font-lock-keyword-face))
  "Face for field labels in item buffers.")

(defface op-section-face '((t :inherit font-lock-function-name-face :weight bold))
  "Face for section headings in item buffers.")

(defface op-concealed-face '((t :inherit shadow))
  "Face for concealed values.")

;;;; Internal state / 内部状態

(define-error 'op-error "1Password CLI error")

(defvar op--session-env nil
  "List of \"OP_SESSION_xxx=TOKEN\" strings obtained by `op-signin'.")

(defvar op--items-cache nil
  "Cached item list used for completion, as (SCOPE . ITEMS).")

(defvar op--current-account nil
  "Account (a string) for the op command being run.
Bound dynamically; overrides `op-account'.")

(defvar op--accounts-cache nil
  "Cached result of `op account list'.")

(defvar op--session-accounts nil
  "Alist of (ACCOUNT . OP_SESSION_VAR) for tokens obtained by `op-signin'.")

(defvar op--session-timer nil
  "Timer that discards the session token after `op-session-lifetime'.")

(defvar op--secret-cache nil
  "List of (KEY DATA TIMER) when `op-cache-secrets' is non-nil.
KEY is \"ACCOUNT/ITEM-ID\".")

(defvar op--pending-markers nil
  "Alist of (MARKER . TIMER) for copied secrets waiting to be cleared.")

(defconst op--marker-prefix "op-mode-marker:"
  "Prefix of the marker string pushed before each secret.")

(defconst op--auth-error-regexp
  (regexp-opt '("not currently signed in" "session expired" "not signed in"
                "authorization prompt dismissed" "You are not currently"
                "account is not signed in" "no active session"))
  "Regexp matching op errors that indicate a missing session.")

;;;; Desktop app / デスクトップアプリ

(defvar op--app-checked nil
  "Non-nil once the app has been checked in this Emacs session.")

(defconst op--windows-app-check
  '("powershell.exe" "-NoProfile" "-NonInteractive" "-Command"
    "if (Get-Process 1Password -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }")
  "Check whether 1Password.exe is running (Windows / WSL).")

(defconst op--windows-app-launch
  '("powershell.exe" "-NoProfile" "-NonInteractive" "-Command"
    "$p = Join-Path $env:LOCALAPPDATA '1Password\\app\\8\\1Password.exe'; \
if (-not (Test-Path $p)) { $p = Join-Path $env:ProgramFiles '1Password\\app\\8\\1Password.exe' }; \
Start-Process $p")
  "Start 1Password.exe from its usual install locations (Windows / WSL).")

(defun op--app-platform ()
  "Return the platform symbol for the app commands."
  (if (eq op-app-platform 'auto)
      (cond ((eq system-type 'darwin) 'macos)
            ((memq system-type '(windows-nt cygwin ms-dos)) 'windows)
            ((getenv "WSL_DISTRO_NAME") 'wsl)
            (t 'linux))
    op-app-platform))

(defun op--app-default-commands ()
  "Return (CHECK . LAUNCH) commands for the current platform."
  (pcase (op--app-platform)
    ('macos (cons '("pgrep" "-x" "1Password") '("open" "-g" "-a" "1Password")))
    ((or 'windows 'wsl) (cons op--windows-app-check op--windows-app-launch))
    (_ (cons '("pgrep" "-x" "1password") '("1password" "--silent")))))

(defun op--app-check-command ()
  (or op-app-check-command (car (op--app-default-commands))))

(defun op--app-launch-command ()
  (or op-app-launch-command (cdr (op--app-default-commands))))

(defun op--app-running-p ()
  "Return t if the app is running, nil if not, `unknown' if it cannot be told."
  (let ((cmd (op--app-check-command)))
    (condition-case nil
        (eq 0 (apply #'call-process (car cmd) nil nil nil (cdr cmd)))
      (error 'unknown))))

(defun op--launch-app ()
  "Start the 1Password app detached from Emacs."
  (let ((cmd (op--app-launch-command)))
    (message "1Password: starting the 1Password app...")
    (condition-case err
        ;; BUFFER 0: do not wait, and do not kill the app when Emacs exits.
        ;; BUFFER に 0 を渡すと待たずに戻り、Emacs 終了時にもアプリを終了しない。
        (apply #'call-process (car cmd) nil 0 nil (cdr cmd))
      (error
       (user-error "1Password: could not start the app with %S (%s); \
set `op-app-launch-command' or `op-app-platform'"
                   cmd (error-message-string err))))))

(defun op--wait-for-app ()
  "Wait up to `op-app-launch-timeout' seconds for the app to start."
  (let ((deadline (+ (float-time) op-app-launch-timeout))
        state)
    (while (and (not (eq (setq state (op--app-running-p)) t))
                (not (eq state 'unknown))
                (< (float-time) deadline))
      (sleep-for 0.5))
    (pcase state
      ('t (sleep-for 1)                 ; let the app finish starting
          (message "1Password: app started"))
      ('unknown (sleep-for 3))
      (_ (message "1Password: the app did not start within %s seconds"
                  op-app-launch-timeout)))))

(defun op--ensure-app (&optional force)
  "Start the 1Password app if needed (desktop app integration only).
Normally checks once per Emacs session; FORCE checks again.  If the
running state cannot be told, the app is started only when FORCE."
  (when (and op-app-auto-launch
             (eq op-signin-method 'app)
             (or force (not op--app-checked)))
    (setq op--app-checked t)
    (let ((state (op--app-running-p)))
      (when (or (null state) (and force (eq state 'unknown)))
        (op--launch-app)
        (op--wait-for-app)))))

;;;; Process helpers / プロセス呼び出し

(defun op--process-environment ()
  "Return `process-environment' for running op.
Adds session tokens, and with the `password' sign-in method disables
the desktop app integration so op asks for the account password."
  (append op--session-env
          ;; Without this, op uses the app integration whenever it is
          ;; enabled in the 1Password app, regardless of `op-signin-method'.
          ;; これがないと、アプリ側で CLI 連携が有効なら
          ;; `op-signin-method' に関係なく op はアプリ連携を使う。
          (when (eq op-signin-method 'password)
            (list "OP_BIOMETRIC_UNLOCK_ENABLED=false"))
          process-environment))

(defun op--effective-account ()
  "Return the account in effect: a string, nil (default) or `all'."
  (or op--current-account op-account))

(defun op--account-string ()
  "Return the effective account if it is a single account string."
  (let ((a (op--effective-account))) (and (stringp a) a)))

(defmacro op--with-account (account &rest body)
  "Run BODY with ACCOUNT (a string or nil) as the current account.
A nil ACCOUNT keeps the account already in effect."
  (declare (indent 1) (debug t))
  `(let ((op--current-account (or ,account op--current-account)))
     ,@body))

(defun op--global-args ()
  (when-let* ((a (op--account-string))) (list "--account" a)))

(defun op--parse-json (out)
  (unless (string-empty-p (string-trim out))
    (json-parse-string out :object-type 'alist :array-type 'list
                       :null-object nil :false-object nil)))

(defun op--call-raw (args &optional input)
  "Run op with ARGS and return stdout.  Feed INPUT to stdin if non-nil.
Signal `op-error' with stderr content on failure."
  (op--ensure-app)
  (op--touch-session)
  (let ((process-environment (op--process-environment))
        (stderr-file (make-temp-file "op-stderr"))
        (all-args (append args (op--global-args))))
    (unwind-protect
        (with-temp-buffer
          (let ((status
                 (if input
                     (progn
                       (insert input)
                       (apply #'call-process-region (point-min) (point-max)
                              op-executable t (list t stderr-file) nil all-args))
                   (apply #'call-process op-executable nil
                          (list t stderr-file) nil all-args))))
            (if (eq status 0)
                (buffer-string)
              (signal 'op-error
                      (list (string-trim
                             (with-temp-buffer
                               (insert-file-contents stderr-file)
                               (buffer-string))))))))
      (delete-file stderr-file))))

(defun op--call (&rest args)
  "Run op with ARGS, signing in and retrying once if needed."
  (condition-case err
      (op--call-raw args)
    (op-error
     (let ((msg (or (cadr err) "")))
       (cond
        ((string-match-p "found no accounts for filter" msg)
         (user-error "1Password: No account matches `op-account' (%S); \
choose one with M-x op-select-account or set it to nil"
                     (op--effective-account)))
        ((and op-app-auto-launch (eq op-signin-method 'app)
              (string-match-p op-app-connection-error-regexp msg))
         ;; The app is not reachable: start it if needed, then retry once.
         ;; アプリにつながらない: 必要なら起動してから 1 回だけ再実行する。
         (op--ensure-app t)
         (op--call-raw args))
        ((and op-auto-signin (string-match-p op--auth-error-regexp msg))
         ;; Discard the expired / invalid token of this account, then sign
         ;; in again.
         ;; このアカウントの期限切れ・無効なトークンを捨ててからサインインし直す。
         (op--forget-session (op--account-string))
         (op-signin (op--account-string))
         (op--call-raw args))
        (t (signal (car err) (cdr err))))))))

(defun op--call-parallel (accounts args)
  "Run op with ARGS once per account in ACCOUNTS, in parallel.
Return a list of (ACCOUNT OK OUTPUT), where OUTPUT is stdout on success
and stderr on failure."
  (op--ensure-app)
  (op--touch-session)
  (let ((process-environment (op--process-environment))
        jobs)
    (dolist (acct accounts)
      (let* ((out (generate-new-buffer " *op-out*"))
             (err (generate-new-buffer " *op-err*"))
             (errp (make-pipe-process :name "op-stderr" :buffer err
                                      :noquery t :sentinel #'ignore))
             (proc (make-process :name "op" :buffer out :stderr errp
                                 :noquery t :connection-type 'pipe
                                 :sentinel #'ignore
                                 :command (append (list op-executable) args
                                                  (list "--account" acct)))))
        (process-send-eof proc)
        (push (list acct proc errp out err) jobs)))
    (mapcar
     (lambda (job)
       (pcase-let ((`(,acct ,proc ,errp ,out ,err) job))
         (while (process-live-p proc)
           (accept-process-output proc 0.05))
         (accept-process-output errp 0.05)
         (let ((ok (eq (process-exit-status proc) 0)))
           (prog1 (list acct ok
                        (if ok
                            (with-current-buffer out (buffer-string))
                          (string-trim (with-current-buffer err (buffer-string)))))
             (delete-process errp)
             (kill-buffer out)
             (kill-buffer err)))))
     (nreverse jobs))))

(defun op--accounts (&optional refresh)
  "Return accounts known to op (ignores `op-account').
The result is cached; non-nil REFRESH fetches it again."
  (when (or refresh (null op--accounts-cache))
    (setq op--accounts-cache
          (let ((op-account nil) (op--current-account nil))
            (op--parse-json
             (op--call-raw '("account" "list" "--format" "json"))))))
  op--accounts-cache)

(defun op--account-id (account)
  "Return the identifier op-mode uses for ACCOUNT (an `op account list' entry)."
  (or (op--get account 'user_uuid) (op--get account 'url)))

(defun op--account-label (id)
  "Return a short display name (sign-in address) for account ID."
  (when (and id (null op--accounts-cache))
    (ignore-errors (op--accounts)))
  (if-let* ((a (seq-find (lambda (a) (member id (list (op--get a 'user_uuid)
                                                         (op--get a 'account_uuid)
                                                         (op--get a 'url))))
                         op--accounts-cache)))
      (op--get a 'url)
    (or id "")))

(defun op--account-candidates ()
  (or (mapcar (lambda (a)
                (cons (format "%s  <%s>" (op--get a 'url) (op--get a 'email))
                      (op--account-id a)))
              (op--accounts))
      (user-error "1Password: No accounts found; check the 1Password app's CLI \
integration or run `op account add'")))

(defun op--read-account (prompt)
  "Read an account with PROMPT; return its id.  Skip asking if only one."
  (let ((cands (op--account-candidates)))
    (if (cdr cands)
        (cdr (assoc (completing-read prompt cands nil t) cands))
      (cdar cands))))

(defun op--single-account (prompt)
  "Return the account for a single-account command.
When all accounts are in effect, ask for one with PROMPT."
  (let ((a (op--effective-account)))
    (if (eq a 'all) (op--read-account prompt) a)))

;;;###autoload
(defun op-select-account ()
  "Choose the account used by op-mode and set `op-account'.
\"All accounts\" sets it to `all'.  With a prefix argument, also save
it with Customize."
  (interactive)
  (let* ((cands (append (list (cons "All accounts" 'all))
                        (mapcar (lambda (a)
                                  (cons (format "%s  <%s>" (op--get a 'url)
                                                (op--get a 'email))
                                        (op--get a 'url)))
                                (op--accounts t))))
         (value (cdr (assoc (completing-read "1Password account: " cands nil t)
                            cands))))
    (setq op-account value
          op--items-cache nil)
    (when current-prefix-arg
      (customize-save-variable 'op-account value))
    (message "1Password: op-account = %s" value)))

(defun op--json (&rest args)
  "Run op with ARGS plus `--format json' and parse the result."
  (op--parse-json (apply #'op--call (append args '("--format" "json")))))

(defun op--get (alist &rest keys)
  "Follow KEYS (symbols) through nested ALIST."
  (let ((v alist))
    (dolist (k keys v)
      (setq v (alist-get k v)))))

;;;; Session and cache lifetime / セッションとキャッシュの寿命
;;
;; Inspired by Mew's mew-passwd.
;; Mew の mew-passwd を参考にしている。

(defun op--wipe (obj)
  "Overwrite every string inside OBJ (string, list, alist or vector)."
  (cond ((stringp obj) (clear-string obj))
        ((consp obj) (op--wipe (car obj)) (op--wipe (cdr obj)))
        ((vectorp obj) (mapc #'op--wipe obj))))

(defun op--deep-copy (obj)
  "Copy OBJ including its strings, so wiping the original is safe."
  (cond ((stringp obj) (copy-sequence obj))
        ((consp obj) (cons (op--deep-copy (car obj)) (op--deep-copy (cdr obj))))
        ((vectorp obj) (vconcat (mapcar #'op--deep-copy obj)))
        (t obj)))

(defun op--touch-session ()
  "Extend the session token lifetime (sliding expiration)."
  (when op--session-timer (cancel-timer op--session-timer))
  (setq op--session-timer
        (when (and op--session-env op-session-lifetime)
          (run-at-time (* 60 op-session-lifetime) nil #'op--expire-session))))

(defun op--forget-session (&optional account)
  "Wipe session tokens and the item list cache (no network access).
With ACCOUNT, wipe only that account's token when it is known."
  (let ((var (and account (cdr (assoc account op--session-accounts)))))
    (if var
        (let* ((prefix (concat var "="))
               (mine (seq-filter (lambda (e) (string-prefix-p prefix e))
                                 op--session-env)))
          (setq op--session-env (seq-difference op--session-env mine #'eq)
                op--session-accounts
                (seq-remove (lambda (c) (equal (car c) account)) op--session-accounts))
          (mapc #'clear-string mine))
      (mapc #'clear-string op--session-env)
      (setq op--session-env nil
            op--session-accounts nil)))
  (unless op--session-env
    (when op--session-timer (cancel-timer op--session-timer))
    (setq op--session-timer nil))
  (setq op--items-cache nil))

(defun op--expire-session ()
  "Timer callback: sign out and forget the session."
  (when op--session-env
    (let ((process-environment (op--process-environment)))
      ;; Also invalidate the session on the server (async, result ignored).
      ;; サーバー側のセッションも無効化する (非同期・結果は無視)。
      (ignore-errors
        (make-process :name "op-signout" :noquery t :buffer nil
                      :command (list op-executable "signout" "--all")
                      :sentinel #'ignore)))
    (op--forget-session)
    (op--secret-cache-clear)
    (message "1Password: session expired (idle %s min)" op-session-lifetime)))

(defun op--item-key (item)
  "Return the secret cache key of ITEM (account and item id)."
  (format "%s/%s" (or (op--get item 'op-account) (op--account-string) "")
          (op--get item 'id)))

(defun op--secret-cache-clear (&optional id)
  "Wipe cached item ID (a key), or all cached items when ID is nil."
  (dolist (e (if id (list (assoc id op--secret-cache)) op--secret-cache))
    (when e
      (when (timerp (nth 2 e)) (cancel-timer (nth 2 e)))
      (op--wipe (nth 1 e))
      (setq op--secret-cache (delq e op--secret-cache)))))

(defun op--secret-cache-get (id)
  "Return a copy of cached data for ID and extend its lifetime."
  (when-let* ((e (and op-cache-secrets (assoc id op--secret-cache))))
    (cancel-timer (nth 2 e))
    (setcar (nthcdr 2 e) (run-at-time (* 60 op-secret-cache-lifetime) nil
                                      #'op--secret-cache-clear id))
    (op--deep-copy (nth 1 e))))

(defun op--secret-cache-put (id data)
  "Cache a private copy of DATA under ID."
  (when op-cache-secrets
    (op--secret-cache-clear id)
    (push (list id (op--deep-copy data)
                (run-at-time (* 60 op-secret-cache-lifetime) nil
                             #'op--secret-cache-clear id))
          op--secret-cache)))

(defun op--cleanup ()
  "Wipe everything op-mode holds: clipboard secrets, tokens and caches."
  (ignore-errors (op-clear-clipboard))
  (op--secret-cache-clear)
  (op--forget-session))

(add-hook 'kill-emacs-hook #'op--cleanup)

;;;; Sign in / out / サインイン / サインアウト

;;;###autoload
(defun op-signin (&optional account)
  "Sign in to 1Password ACCOUNT (default: the account in effect).
When all accounts are in effect, ask which account to sign in to."
  (interactive (list (op--single-account "Sign in to account: ")))
  (op--with-account account
    (op--signin-1)))

(defun op--signin-1 ()
  (pcase op-signin-method
    ('app
     (op--call-raw '("signin"))
     (message "1Password: signed in (app integration)"))
    ('password
     (let* ((acct (op--account-string))
            (pw (read-passwd (format "1Password password%s: "
                                     (if acct (format " (%s)" (op--account-label acct))
                                       "")))))
       (unwind-protect
           ;; --force: op-mode parses the output itself instead of eval.
           ;; --force: 出力は eval せず op-mode 側で解析する。
           (let ((out (op--call-raw '("signin" "--force") pw)))
             (if (string-match
                  "\\(OP_SESSION_[[:alnum:]_]+\\) *= *\"\\([^\"]+\\)\"" out)
                 (let* ((var (match-string 1 out))
                        (tok (match-string 2 out))
                        (entry (concat var "=" tok)))
                   (clear-string tok)
                   (setq op--session-env
                         (cons entry
                               (seq-remove (lambda (e) (string-prefix-p (concat var "=") e))
                                           op--session-env)))
                   (clear-string out)
                   (when acct
                     (setq op--session-accounts
                           (cons (cons acct var)
                                 (seq-remove (lambda (c) (equal (car c) acct))
                                             op--session-accounts))))
                   (op--touch-session)
                   (message "1Password: signed in"))
               (message "1Password: signin returned no session token")))
         (clear-string pw))))))

;;;###autoload
(defun op-signout ()
  "Sign out of 1Password and forget session tokens."
  (interactive)
  (ignore-errors
    (if (or (eq (op--effective-account) 'all) (cdr op--session-env))
        (let ((op--current-account nil) (op-account nil))
          (op--call-raw '("signout" "--all")))
      (op--call-raw '("signout"))))
  (op--secret-cache-clear)
  (op--forget-session)
  (message "1Password: signed out"))

;;;###autoload
(defun op-whoami (&optional account)
  "Show the signed-in ACCOUNT."
  (interactive (list (op--single-account "Account: ")))
  (let ((info (op--with-account account (op--json "whoami"))))
    (message "1Password: %s (%s)"
             (op--get info 'email) (op--get info 'url))))

;;;; Clipboard / クリップボード
;;
;; When copying a secret, two values are pushed onto the kill ring (and the
;; clipboard) in this order:
;;   1. A random marker string ("op-mode-marker:<uuid>")
;;   2. The actual secret
;; On clearing, the marker is looked up in the kill ring and only the marker
;; and the value pushed right after it (= the secret) are removed.  The
;; secret itself is not kept by Emacs.  The system clipboard is emptied only
;; when it still holds that secret or the marker.
;;
;; シークレットのコピー時には次の 2 つを順に kill-ring (およびクリップボード) へ積む:
;;   1. 識別用のランダムなマーカー文字列 ("op-mode-marker:<uuid>")
;;   2. 実際のシークレット
;; 消去時は kill-ring からマーカーを探し、マーカーとその「次に」積まれた値
;; (= シークレット) だけを削除する。シークレット自体は Emacs 側で保持しない。
;; システムのクリップボードは、中身がそのシークレットかマーカーの場合のみ空にする。

(defun op--make-marker ()
  "Return a unique marker string (prefix + random UUIDv4)."
  (concat op--marker-prefix
          (format "%08x-%04x-4%03x-%04x-%012x"
                  (random #x100000000) (random #x10000) (random #x1000)
                  (logior #x8000 (random #x4000)) (random #x1000000000000))))

(defun op--system-clipboard ()
  "Return the system clipboard text, or `:unknown' if it cannot be read."
  (if (display-graphic-p)
      (condition-case nil
          (or (gui-get-selection 'CLIPBOARD 'UTF8_STRING) "")
        (error :unknown))
    :unknown))

(defun op--clear-marker (marker &optional quiet)
  "Remove MARKER and the value copied right after it from the kill ring.
Clear the system clipboard if it still holds either of them.
Non-nil QUIET suppresses the message.  Return non-nil if a secret was removed."
  (let ((entry (assoc marker op--pending-markers)))
    (when (timerp (cdr entry)) (cancel-timer (cdr entry)))
    (setq op--pending-markers (delq entry op--pending-markers)))
  (let ((pos (seq-position kill-ring marker)))
    (when pos
      (let* ((marker-obj (nth pos kill-ring))
             ;; The kill ring is newest-first, so the value pushed after the
             ;; marker sits one position before it.
             ;; kill-ring は新しい順なので、マーカーの「次の値」は 1 つ前の位置。
             (secret (and (> pos 0) (nth (1- pos) kill-ring)))
             (secret-latest (= pos 1))
             (clip (op--system-clipboard)))
        (setq kill-ring (delq marker-obj (if secret (delq secret kill-ring) kill-ring))
              kill-ring-yank-pointer kill-ring)
        (when interprogram-cut-function
          (cond
           ((stringp clip)
            (when (or (equal clip marker-obj) (and secret (equal clip secret)))
              (funcall interprogram-cut-function "")))
           ;; If the clipboard cannot be read (e.g. in a terminal), empty it
           ;; only when this secret was the last thing Emacs copied.
           ;; 読めない環境 (端末等) では、Emacs で最後にコピーしたのが
           ;; このシークレットだった場合のみ空にする。
           ((or secret-latest (= pos 0))
            (funcall interprogram-cut-function ""))))
        (when secret (clear-string secret))
        (unless quiet (message "1Password: clipboard cleared"))
        secret))))

;;;###autoload
(defun op-clear-clipboard ()
  "Clear all secrets copied by op-mode that are still pending."
  (interactive)
  (let ((n 0))
    (dolist (m (mapcar #'car op--pending-markers))
      (when (op--clear-marker m t) (setq n (1+ n))))
    (when (called-interactively-p 'interactive)
      (message "1Password: cleared %d secret(s)" n))))

(defun op--copy (secret what)
  "Copy SECRET to the kill ring, describing it as WHAT.
A marker is pushed first so the secret can be found and removed later."
  (unless (and secret (not (string-empty-p secret)))
    (user-error "1Password: %s is empty" what))
  (let ((marker (op--make-marker))
        (kill-do-not-save-duplicates nil))
    (kill-new marker)
    (kill-new (copy-sequence secret))
    (push (cons marker
                (when op-clipboard-clear-seconds
                  (run-at-time op-clipboard-clear-seconds nil
                               #'op--clear-marker marker)))
          op--pending-markers)
    (if op-clipboard-clear-seconds
        (message "1Password: copied %s (clears in %ds)" what op-clipboard-clear-seconds)
      (message "1Password: copied %s" what))))

;;;; Data access / データ取得

(defun op--vaults (&optional account)
  (op--with-account account
    (op--json "vault" "list")))

(defun op--item-list-args (vault)
  (append (list "item" "list")
          (when vault (list "--vault" vault))
          (when op-list-categories
            (list "--categories" (string-join op-list-categories ",")))
          (list "--format" "json")))

(defun op--tag-items (items account)
  "Record ACCOUNT in each of ITEMS so later commands use the same account."
  (if account
      (mapcar (lambda (it) (cons (cons 'op-account account) it)) items)
    items))

(defun op--list-items (&optional vault account)
  "List items in VAULT of ACCOUNT.
ACCOUNT nil means the account in effect; `all' lists every account
\(VAULT is then ignored)."
  (let ((acct (or account (op--effective-account))))
    (if (eq acct 'all)
        (op--list-items-all)
      (op--with-account (and (stringp acct) acct)
        (op--tag-items (op--parse-json (apply #'op--call (op--item-list-args vault)))
                       (op--account-string))))))

(defun op--list-items-all ()
  "List items of every account, reporting accounts that failed."
  (let* ((accts (mapcar #'op--account-id (op--accounts)))
         (args (op--item-list-args nil))
         (results (if (and op-parallel-fetch (cdr accts))
                      (op--call-parallel accts args)
                    (mapcar (lambda (a)
                              (condition-case e
                                  (list a t (op--with-account a (apply #'op--call args)))
                                (error (list a nil (error-message-string e)))))
                            accts)))
         items failed)
    (dolist (r results)
      (pcase-let ((`(,acct ,ok ,out) r))
        ;; Not signed in: retry this account alone (signs in if needed).
        ;; 未サインインのアカウントは単独で再実行する (必要ならサインイン)。
        (when (and (not ok)
                   (or (and op-auto-signin
                            (string-match-p op--auth-error-regexp out))
                       (and op-app-auto-launch (eq op-signin-method 'app)
                            (string-match-p op-app-connection-error-regexp out))))
          (condition-case e
              (setq out (op--with-account acct (apply #'op--call args))
                    ok t)
            (error (setq out (error-message-string e)))))
        (if ok
            (setq items (nconc items (op--tag-items (op--parse-json out) acct)))
          (push (format "%s (%s)" (op--account-label acct) out) failed))))
    (when failed
      (message "1Password: could not list %s" (string-join (nreverse failed) ", ")))
    items))

(defun op--item-get (item &optional fresh)
  "Fetch full ITEM (alist with id and vault) as JSON.
Uses the secret cache when `op-cache-secrets' is non-nil, unless FRESH."
  (let ((key (op--item-key item)))
    (or (and (not fresh) (op--secret-cache-get key))
        (let ((data (op--with-account (op--get item 'op-account)
                      (apply #'op--json "item" "get" (op--get item 'id)
                             (when-let* ((v (op--get item 'vault 'id)))
                               (list "--vault" v))))))
          (op--secret-cache-put key data)
          data))))

(defun op--item-otp (item)
  (string-trim
   (op--with-account (op--get item 'op-account)
     (apply #'op--call "item" "get" (op--get item 'id) "--otp"
            (when-let* ((v (op--get item 'vault 'id))) (list "--vault" v))))))

(defun op--field-by-purpose (full purpose)
  (seq-find (lambda (f) (equal (op--get f 'purpose) purpose))
            (op--get full 'fields)))

(defun op--field-by-label (full label)
  (seq-find (lambda (f) (equal (op--get f 'label) label))
            (op--get full 'fields)))

(defun op--password (full)
  (op--get (or (op--field-by-purpose full "PASSWORD")
               (op--field-by-label full "password")
               (seq-find (lambda (f) (equal (op--get f 'type) "CONCEALED"))
                         (op--get full 'fields)))
           'value))

(defun op--username (full)
  (op--get (or (op--field-by-purpose full "USERNAME")
               (op--field-by-label full "username"))
           'value))

(defun op--primary-url (item)
  (let ((urls (op--get item 'urls)))
    (op--get (or (seq-find (lambda (u) (op--get u 'primary)) urls) (car urls))
             'href)))

;;;; Completion / 補完

(defun op--item-candidates (&optional refresh)
  (let* ((all (eq (op--effective-account) 'all))
         (scope (list (op--effective-account) op-default-vault)))
    (when (or refresh (not (equal (car op--items-cache) scope)))
      (setq op--items-cache
            (cons scope (op--list-items (unless all op-default-vault)))))
    (mapcar (lambda (it)
              (cons (format "%s  (%s%s%s)"
                            (op--get it 'title)
                            (op--get it 'vault 'name)
                            (if all
                                (concat " @ " (op--account-label (op--get it 'op-account)))
                              "")
                            (let ((info (op--get it 'additional_information)))
                              (if (and info (not (string-empty-p info)))
                                  (concat " / " info) "")))
                    it))
            (cdr op--items-cache))))

(defun op--read-item (prompt)
  (let* ((cands (op--item-candidates))
         (choice (completing-read prompt cands nil t)))
    (cdr (assoc choice cands))))

;;;; Global commands / グローバルコマンド

;;;###autoload
(defun op-copy-password (item)
  "Copy the password of ITEM."
  (interactive (list (op--read-item "Password for: ")))
  (op--copy (op--password (op--item-get item))
            (format "password of %s" (op--get item 'title))))

;;;###autoload
(defun op-copy-username (item)
  "Copy the username of ITEM."
  (interactive (list (op--read-item "Username for: ")))
  (op--copy (op--username (op--item-get item))
            (format "username of %s" (op--get item 'title))))

;;;###autoload
(defun op-copy-otp (item)
  "Copy the current one-time password of ITEM."
  (interactive (list (op--read-item "OTP for: ")))
  (op--copy (op--item-otp item) (format "OTP of %s" (op--get item 'title))))

;;;###autoload
(defun op-read (reference &optional account)
  "Read secret REFERENCE (op://vault/item/field) in ACCOUNT and copy it."
  (interactive (list (read-string "Secret reference: " "op://")
                     (op--single-account "Read from account: ")))
  (op--copy (string-trim-right
             (op--with-account account (op--call "read" "--no-newline" reference))
             "\n")
            reference))

;;;###autoload
(defun op-insert-reference (item)
  "Insert an op:// reference to ITEM's password at point (no secret inserted)."
  (interactive (list (op--read-item "Reference to: ")))
  (insert (format "op://%s/%s/password"
                  (op--get item 'vault 'name) (op--get item 'title))))

;;;###autoload
(defun op-create-login (title username url vault &optional account)
  "Create a Login item TITLE with USERNAME, URL in VAULT of ACCOUNT.
A password is generated with `op-generate-password-recipe'."
  (interactive
   (let ((acct (op--single-account "Create in account: ")))
     (list (read-string "Title: ")
           (read-string "Username: ")
           (read-string "URL: ")
           (completing-read "Vault: "
                            (mapcar (lambda (v) (op--get v 'name)) (op--vaults acct))
                            nil t op-default-vault)
           acct)))
  (op--with-account account
    (op--create-login-1 title username url vault)))

(defun op--create-login-1 (title username url vault)
  (let* ((args (append (list "item" "create" "--category" "login"
                             "--title" title "--vault" vault
                             (concat "--generate-password=" op-generate-password-recipe))
                       (unless (string-empty-p url) (list "--url" url))
                       (unless (string-empty-p username)
                         (list (concat "username=" username)))))
         (created (apply #'op--json args)))
    (setq op--items-cache nil)
    (message "1Password: created %s" title)
    (when (y-or-n-p "Copy generated password? ")
      (op--copy (op--password created) (format "password of %s" title)))))

;;;; Item list mode / アイテム一覧モード

(defvar-local op-list--vault nil "Vault shown in this buffer (nil = all).")
(defvar-local op-list--account nil
  "Account shown in this buffer: nil (default), a string, or `all'.")
(defvar-local op-list--items nil "Items fetched for this buffer.")
(defvar-local op-list--filter nil "Regexp filter for this buffer.")

(defvar-keymap op-list-mode-map
  :doc "Keymap for `op-list-mode'."
  "RET" #'op-list-show-item
  "w" #'op-list-copy-password
  "u" #'op-list-copy-username
  "o" #'op-list-copy-otp
  "l" #'op-list-copy-url
  "b" #'op-list-browse-url
  "r" #'op-list-copy-reference
  "v" #'op-list-select-vault
  "/" #'op-list-filter
  "A" #'op-list-select-account
  "c" #'op-list-create-login
  "D" #'op-list-archive-item
  "s" #'op-signin
  "n" #'next-line
  "p" #'previous-line)

(define-derived-mode op-list-mode tabulated-list-mode "1Password"
  "Major mode listing 1Password items.

\\{op-list-mode-map}"
  (setq tabulated-list-padding 1)
  (op-list--setup-columns)
  (add-hook 'tabulated-list-revert-hook #'op-list--refresh nil t)
  (tabulated-list-init-header))

(defun op-list--all-p ()
  (eq (or op-list--account op-account) 'all))

(defun op-list--sort-value (entry field)
  (let ((it (car entry)))
    (downcase (or (pcase field
                    ('title (op--get it 'title))
                    ('vault (op--get it 'vault 'name))
                    ('account (op--account-label (op--get it 'op-account))))
                  ""))))

(defun op-list--compare (a b fields)
  "Compare entries A and B case-insensitively on FIELDS in order."
  (catch 'done
    (dolist (f fields nil)
      (let ((x (op-list--sort-value a f)) (y (op-list--sort-value b f)))
        (unless (string= x y) (throw 'done (string< x y)))))))

(defun op-list--title< (a b)
  "Sort predicate: title."
  (op-list--compare a b '(title)))

(defun op-list--vault-title< (a b)
  "Sort predicate: vault, then account, then title."
  (op-list--compare a b '(vault account title)))

(defun op-list--account-vault-title< (a b)
  "Sort predicate: account, then vault, then title."
  (op-list--compare a b '(account vault title)))

(defun op-list--setup-columns ()
  "Set columns and the default sort for the current scope.
All accounts: account, vault, title.  All vaults: vault, title.
Single vault: title."
  (setq tabulated-list-format
        (vconcat
         (list '("Title" 36 op-list--title<) '("Category" 14 t)
               '("Vault" 16 op-list--vault-title<))
         (when (op-list--all-p)
           (list '("Account" 22 op-list--account-vault-title<)))
         (list '("Info" 32 t) '("Updated" 17 t))))
  (setq tabulated-list-sort-key
        (cond ((op-list--all-p) '("Account" . nil))
              (op-list--vault '("Title" . nil))
              (t '("Vault" . nil))))
  (tabulated-list-init-header))

(defun op-list--format-time (s)
  (if (and s (>= (length s) 16))
      (replace-regexp-in-string "T" " " (substring s 0 16))
    (or s "")))

(defun op-list--render ()
  (setq tabulated-list-entries
        (delq nil
              (mapcar
               (lambda (it)
                 (let ((title (or (op--get it 'title) ""))
                       (info (or (op--get it 'additional_information) "")))
                   (when (or (null op-list--filter)
                             (string-match-p op-list--filter title)
                             (string-match-p op-list--filter info))
                     (list it
                           (vconcat
                            (list title
                                  (or (op--get it 'category) "")
                                  (or (op--get it 'vault 'name) ""))
                            (when (op-list--all-p)
                              (list (op--account-label (op--get it 'op-account))))
                            (list info
                                  (op-list--format-time (op--get it 'updated_at))))))))
               op-list--items)))
  (setq mode-line-process
        (format " [%s / %s%s]"
                (let ((a (or op-list--account op-account)))
                  (cond ((eq a 'all) "all accounts")
                        (a (op--account-label a))
                        (t "default account")))
                (or op-list--vault "all vaults")
                (if op-list--filter (format " /%s/" op-list--filter) ""))))

(defun op-list--account-arg ()
  "Account string of this buffer, or nil."
  (and (stringp op-list--account) op-list--account))

(defun op-list--refresh ()
  (setq op-list--items
        (op--list-items op-list--vault (or op-list--account op-account)))
  (op-list--render))

;;;###autoload
(defun op-list-items (&optional vault)
  "Show 1Password items, optionally restricted to VAULT."
  (interactive)
  (let ((buf (get-buffer-create "*1Password*")))
    (with-current-buffer buf
      (op-list-mode)
      (setq op-list--account op-account
            op-list--vault (unless (op-list--all-p) (or vault op-default-vault)))
      (op-list--setup-columns)
      (op-list--refresh)
      (tabulated-list-print))
    (pop-to-buffer-same-window buf)))

;;;###autoload
(defalias 'op #'op-list-items)

(defun op-list--item-at-point ()
  (or (tabulated-list-get-id) (user-error "No item at point")))

(defun op-list-show-item ()
  "Show the item at point."
  (interactive)
  (op-item-show (op-list--item-at-point)))

(defun op-list-copy-password ()
  "Copy password of the item at point."
  (interactive)
  (op-copy-password (op-list--item-at-point)))

(defun op-list-copy-username ()
  "Copy username of the item at point."
  (interactive)
  (op-copy-username (op-list--item-at-point)))

(defun op-list-copy-otp ()
  "Copy OTP of the item at point."
  (interactive)
  (op-copy-otp (op-list--item-at-point)))

(defun op-list-copy-url ()
  "Copy primary URL of the item at point."
  (interactive)
  (let ((url (op--primary-url (op-list--item-at-point))))
    (unless url (user-error "No URL"))
    (kill-new url)
    (message "Copied %s" url)))

(defun op-list-browse-url ()
  "Open primary URL of the item at point."
  (interactive)
  (let ((url (op--primary-url (op-list--item-at-point))))
    (unless url (user-error "No URL"))
    (browse-url url)))

(defun op-list-copy-reference ()
  "Copy an op:// reference to the password of the item at point."
  (interactive)
  (let* ((it (op-list--item-at-point))
         (ref (format "op://%s/%s/password"
                      (op--get it 'vault 'name) (op--get it 'title))))
    (kill-new ref)
    (message "Copied %s" ref)))

(defun op-list-select-vault ()
  "Switch the vault shown in this buffer.
When all accounts are shown, choosing a vault also narrows the list to
that vault's account."
  (interactive)
  (if (op-list--all-p)
      (let* ((cands
              (mapcan (lambda (acct)
                        (mapcar (lambda (v)
                                  (cons (format "%s  @ %s" (op--get v 'name)
                                                (op--account-label acct))
                                        (cons acct (op--get v 'name))))
                                (ignore-errors (op--vaults acct))))
                      (mapcar #'op--account-id (op--accounts))))
             (choice (completing-read "Vault (empty = all): " cands nil t))
             (sel (cdr (assoc choice cands))))
        (when sel
          (setq op-list--account (car sel)
                op-list--vault (cdr sel))))
    (let* ((names (mapcar (lambda (v) (op--get v 'name))
                          (op--vaults (op-list--account-arg))))
           (choice (completing-read "Vault (empty = all): " names nil t)))
      (setq op-list--vault (unless (string-empty-p choice) choice))))
  (op-list--setup-columns)
  (revert-buffer))

(defun op-list-select-account ()
  "Switch the account shown in this buffer (or all accounts)."
  (interactive)
  (let* ((cands (append (list (cons "All accounts" 'all))
                        (op--account-candidates)))
         (choice (cdr (assoc (completing-read "Account: " cands nil t) cands))))
    (setq op-list--account choice
          op-list--vault nil)
    (op-list--setup-columns)
    (revert-buffer)))

(defun op-list-create-login ()
  "Create a login item in this buffer's account."
  (interactive)
  (let ((op--current-account (op-list--account-arg)))
    (call-interactively #'op-create-login))
  (revert-buffer))

(defun op-list-filter (regexp)
  "Filter the list by REGEXP on title/info.  Empty clears the filter."
  (interactive (list (read-regexp "Filter (empty = clear): ")))
  (setq op-list--filter (unless (string-empty-p regexp) regexp))
  (op-list--render)
  (tabulated-list-print t))

(defun op-list-archive-item ()
  "Move the item at point to the archive."
  (interactive)
  (let ((it (op-list--item-at-point)))
    (when (yes-or-no-p (format "Archive \"%s\"? " (op--get it 'title)))
      (op--with-account (op--get it 'op-account)
        (op--call "item" "delete" (op--get it 'id)
                  "--vault" (op--get it 'vault 'id) "--archive"))
      (op--secret-cache-clear (op--item-key it))
      (revert-buffer)
      (message "1Password: archived %s" (op--get it 'title)))))

;;;; Item detail mode / アイテム詳細モード

(defvar-local op-item--item nil "Summary alist of the shown item.")
(defvar-local op-item--full nil "Full JSON of the shown item.")
(defvar-local op-item--reveal nil "Whether concealed values are shown.")

(defvar-keymap op-item-mode-map
  :doc "Keymap for `op-item-mode'."
  :parent special-mode-map
  "RET" #'op-item-copy-field
  "w" #'op-item-copy-field
  "TAB" #'op-item-toggle-reveal
  "o" #'op-item-copy-otp
  "b" #'op-item-browse-url
  "n" #'op-item-next-field
  "p" #'op-item-previous-field)

(define-derived-mode op-item-mode special-mode "1Password-Item"
  "Major mode showing a 1Password item.

\\{op-item-mode-map}"
  ;; g (revert) always refetches, bypassing the cache.
  ;; g (revert) は常にキャッシュを使わず取り直す。
  (setq-local revert-buffer-function
              (lambda (&rest _) (op-item--revert nil nil t))))

(defun op-item--concealed-p (field)
  (member (op--get field 'type) '("CONCEALED" "OTP")))

(defun op-item--insert-field (field)
  (let* ((label (or (op--get field 'label) (op--get field 'id) "?"))
         (value (or (op--get field 'value) ""))
         (otp (equal (op--get field 'type) "OTP"))
         (start (point)))
    (insert (propertize (format "  %-20s " label) 'face 'op-label-face))
    (cond
     ((and (op-item--concealed-p field) (not op-item--reveal))
      (insert (propertize (if otp "•••••• (o: copy code)" "••••••••••••")
                          'face 'op-concealed-face)))
     ((string-match-p "\n" value)
      (insert "\n" (replace-regexp-in-string "^" "      " value)))
     (t (insert value)))
    (insert "\n")
    (put-text-property start (point) 'op-field field)))

(defun op-item--render ()
  (let ((inhibit-read-only t)
        (full op-item--full)
        (pos (point)))
    (erase-buffer)
    (insert (propertize (or (op--get full 'title) "") 'face '(:height 1.3 :weight bold))
            "\n"
            (propertize (format "%s  /  %s%s  /  updated %s\n\n"
                                (op--get full 'category)
                                (op--get full 'vault 'name)
                                (if-let* ((a (op--get op-item--item 'op-account)))
                                    (concat "  /  " (op--account-label a))
                                  "")
                                (op-list--format-time (op--get full 'updated_at)))
                        'face 'shadow))
    (let ((fields (op--get full 'fields))
          (sections (op--get full 'sections)))
      ;; Fields without a section first.
      ;; セクションに属さない項目を先に表示する。
      (dolist (f fields)
        (unless (op--get f 'section 'id)
          (unless (and (equal (op--get f 'purpose) "NOTES")
                       (string-empty-p (or (op--get f 'value) "")))
            (op-item--insert-field f))))
      (dolist (s sections)
        (let ((sfields (seq-filter (lambda (f) (equal (op--get f 'section 'id)
                                                      (op--get s 'id)))
                                   fields)))
          (when sfields
            (insert "\n" (propertize (or (op--get s 'label) (op--get s 'id) "")
                                     'face 'op-section-face)
                    "\n")
            (mapc #'op-item--insert-field sfields)))))
    (when-let* ((urls (op--get full 'urls)))
      (insert "\n" (propertize "URLs" 'face 'op-section-face) "\n")
      (dolist (u urls)
        (let ((start (point)))
          (insert (propertize (format "  %-20s " (or (op--get u 'label) "website"))
                              'face 'op-label-face)
                  (op--get u 'href) "\n")
          (put-text-property start (point) 'op-field
                             `((label . "url") (type . "URL")
                               (value . ,(op--get u 'href)))))))
    (insert "\n" (propertize "RET/w: copy  TAB: reveal  o: OTP  b: browse  g: refresh  q: quit"
                             'face 'shadow))
    (goto-char (min pos (point-max)))))

(defun op-item--revert (&optional _ignore-auto _noconfirm fresh)
  (setq op-item--full (op--item-get op-item--item fresh))
  (op-item--render))

(defun op-item-show (item)
  "Display ITEM in a dedicated buffer."
  (let ((buf (get-buffer-create
              (format "*1Password: %s%s*" (op--get item 'title)
                      (if-let* ((a (op--get item 'op-account)))
                          (concat " @ " (op--account-label a))
                        "")))))
    (with-current-buffer buf
      (op-item-mode)
      (setq op-item--item item)
      (op-item--revert)
      (goto-char (point-min))
      (op-item-next-field))
    (pop-to-buffer buf)))

(defun op-item--field-at-point ()
  (or (get-text-property (point) 'op-field)
      (user-error "No field at point")))

(defun op-item-copy-field ()
  "Copy the value of the field at point (OTP fields copy the current code)."
  (interactive)
  (let ((f (op-item--field-at-point)))
    (if (equal (op--get f 'type) "OTP")
        (op-item-copy-otp)
      (op--copy (op--get f 'value) (or (op--get f 'label) "field")))))

(defun op-item-copy-otp ()
  "Copy the current OTP code of this item."
  (interactive)
  (op-copy-otp op-item--item))

(defun op-item-toggle-reveal ()
  "Toggle display of concealed values."
  (interactive)
  (setq op-item--reveal (not op-item--reveal))
  (op-item--render))

(defun op-item-browse-url ()
  "Open the item's primary URL."
  (interactive)
  (let ((url (op--primary-url op-item--full)))
    (unless url (user-error "No URL"))
    (browse-url url)))

(defun op-item-next-field ()
  "Move to the next field."
  (interactive)
  (let ((cur (get-text-property (point) 'op-field))
        (pos (point)))
    (while (and (< pos (point-max))
                (or (null (get-text-property pos 'op-field))
                    (eq (get-text-property pos 'op-field) cur)))
      (setq pos (1+ pos)))
    (when (get-text-property pos 'op-field)
      (goto-char pos))))

(defun op-item-previous-field ()
  "Move to the previous field."
  (interactive)
  (let ((cur (get-text-property (point) 'op-field))
        target)
    (save-excursion
      (beginning-of-line)
      (while (and (not target) (zerop (forward-line -1)))
        (let ((f (get-text-property (point) 'op-field)))
          (when (and f (not (eq f cur)))
            (setq target (point))))))
    (when target
      (goto-char (or (previous-single-property-change (1+ target) 'op-field)
                     (point-min))))))

;;;; Global minor mode / グローバルマイナーモード

(defvar-keymap op-command-map
  :doc "Command map for 1Password."
  :prefix 'op-command-map
  "l" #'op-list-items
  "w" #'op-copy-password
  "u" #'op-copy-username
  "o" #'op-copy-otp
  "r" #'op-read
  "i" #'op-insert-reference
  "c" #'op-create-login
  "s" #'op-signin
  "S" #'op-signout
  "x" #'op-clear-clipboard
  "a" #'op-select-account
  "?" #'op-whoami)

(defvar-keymap op-mode-map
  :doc "Keymap for `op-mode'."
  op-mode-prefix-key 'op-command-map)

;;;###autoload
(define-minor-mode op-mode
  "Global minor mode providing 1Password commands under `op-mode-prefix-key'.

\\{op-command-map}"
  :global t
  :lighter " 1P"
  :keymap op-mode-map
  (unless op-mode
    (op-clear-clipboard)))

(provide 'op-mode)
;;; op-mode.el ends here
