# op-mode

[English](README.md) | 日本語

[1Password CLI](https://developer.1password.com/docs/cli/)（`op`）を Emacs から操作するためのパッケージです。
アイテムの一覧・詳細表示、パスワード / ユーザー名 / ワンタイムパスワードのコピー、ログインアイテムの作成ができます。

1Password の「すべてのアカウント」のように、全アカウントのアイテムをまとめて検索することもできます。

コピーした秘密の値は一定時間後に kill-ring とクリップボードから自動で消去し、セッションやキャッシュにも有効期限を設けています。

## 必要なもの

- Emacs 30.2 以上
- 1Password CLI v2（`op`）
- 推奨：1Password デスクトップアプリの CLI 連携（生体認証でサインインできます）

## インストール

### package-vc（Emacs 30 標準）

```elisp
(use-package op-mode
  :vc (:url "https://github.com/SarupAtTech/op-mode" :rev :newest)
  :config
  (op-mode 1))
```

### 手動

`op-mode.el` を `load-path` の通ったディレクトリに置きます。

```elisp
(add-to-list 'load-path "~/.emacs.d/lisp")
(require 'op-mode)
(op-mode 1)
```

## 設定例

```elisp
;; 1Password の「すべてのアカウント」のように全アカウントを対象にする
;; (setq op-account 'all)

;; 特定のアカウントだけを使う場合。アカウントが複数ある場合のみ設定
;; （1つなら nil のままで構いません）。
;; 値は `op account list` に表示される URL、メールアドレス、またはアカウント ID。
;; M-x op-select-account で一覧から選ぶこともできます。
(setq op-account nil)

;; 起動時に表示する Vault（nil なら全 Vault）
(setq op-default-vault "Private")

;; デスクトップアプリ連携を使わない場合はパスワード方式に
;; (setq op-signin-method 'password)
```

## 使い方

`op-mode` を有効にすると、`C-c P` 以下にコマンドが割り当てられます（`op-mode-prefix-key` で変更可）。

| キー | コマンド | 内容 |
|---|---|---|
| `C-c P l` | `op-list-items` | アイテム一覧を開く（`M-x op` でも可） |
| `C-c P w` | `op-copy-password` | アイテムを補完で選んでパスワードをコピー |
| `C-c P u` | `op-copy-username` | 同、ユーザー名をコピー |
| `C-c P o` | `op-copy-otp` | 同、ワンタイムパスワードをコピー |
| `C-c P r` | `op-read` | `op://vault/item/field` 参照を読んでコピー |
| `C-c P i` | `op-insert-reference` | `op://` 参照をカーソル位置に挿入（秘密の値は挿入しない） |
| `C-c P c` | `op-create-login` | パスワードを生成してログインアイテムを作成 |
| `C-c P x` | `op-clear-clipboard` | コピーした秘密の値をすぐに消去 |
| `C-c P a` | `op-select-account` | 使うアカウントを選ぶ（「All accounts」で全アカウント） |
| `C-c P s` / `S` | `op-signin` / `op-signout` | サインイン / サインアウト |
| `C-c P ?` | `op-whoami` | サインイン中のアカウントを表示 |

### アイテム一覧（`op-list-mode`）

全アカウント表示のときはアカウント → Vault → タイトル、1つのアカウントの全 Vault 表示のときは Vault → タイトル、特定の Vault のときはタイトル順に並びます。全アカウント表示のときは「Account」列が増えます。

| キー | 内容 |
|---|---|
| `RET` | 詳細を表示 |
| `w` / `u` / `o` | パスワード / ユーザー名 / OTP をコピー |
| `l` / `b` | URL をコピー / ブラウザで開く |
| `r` | `op://` 参照をコピー |
| `A` | アカウントを切り替え（全アカウント表示にも戻せる） |
| `v` | Vault を切り替え（全アカウント表示中は、選んだ Vault のアカウントに絞り込む） |
| `/` | タイトル・補足情報を正規表現で絞り込み（空で解除） |
| `c` | ログインアイテムを作成 |
| `D` | アイテムをアーカイブ |
| `g` | 再読み込み |
| `S` | 列で並べ替え |

### 詳細表示（`op-item-mode`）

パスワードなどの秘密の値は、初期状態では伏せて表示します。

| キー | 内容 |
|---|---|
| `RET` / `w` | カーソル位置の項目をコピー（OTP 項目では現在のコードをコピー） |
| `TAB` | 秘密の値の表示 / 非表示を切り替え |
| `o` | OTP をコピー |
| `b` | URL をブラウザで開く |
| `n` / `p` | 次 / 前の項目へ移動 |
| `g` | 取り直す（キャッシュは使わない） |

## 1Password アプリの起動

アプリ連携（`op-signin-method` が `app`）のとき、1Password アプリが起動していなければ op-mode が起動します。

- Emacs で最初に `op` を呼ぶときに、アプリが起動しているかを確認します。起動していなければ起動し、最大 `op-app-launch-timeout` 秒（既定 15 秒）待ちます。
- その後、`op` が「アプリにつながらない」というエラーを返したとき（アプリを終了した場合など）は、アプリを起動して1回だけ再実行します。
- アプリは Emacs から切り離して起動するので、Emacs を終了してもアプリは動き続けます。
- アプリのロック解除と CLI の承認は、これまでどおり手で行います。

お使いの環境に合わせて `op-app-platform` を設定してください（既定は `linux`）。

| `op-app-platform` | 起動確認 | 起動 |
|---|---|---|
| `linux`（既定） | `pgrep -x 1password` | `1password --silent`（トレイに格納して起動） |
| `macos` | `pgrep -x 1Password` | `open -g -a 1Password`（前面に出さずに起動） |
| `windows` / `wsl` | `powershell.exe` で `Get-Process 1Password` | `powershell.exe` で `%LOCALAPPDATA%\1Password\app\8`（なければ `%ProgramFiles%`）の `1Password.exe` を起動 |
| `auto` | `system-type` から判定（WSL は `$WSL_DISTRO_NAME` で判定） | |

インストール先などが違う場合は、コマンドを直接設定できます。

```elisp
(setq op-app-check-command '("pgrep" "-x" "1password")
      op-app-launch-command '("/opt/1Password/1password" "--silent"))
```

WSL2 でアプリ連携を使う場合は、通常 Windows 側の `op.exe` を呼ぶ構成になります（例：`(setq op-executable "op.exe")`）。

この機能を使わない場合は `(setq op-app-auto-launch nil)` にしてください。

## 全アカウント

`op-account` を `all` にする（または `M-x op-select-account` で「All accounts」を選ぶ）と、`op` に登録されたすべてのアカウントを対象にします。

- `op` は1回のコマンドで1アカウントしか扱えないため、アカウントごとに一覧を取得（`op item list --account ...`）してまとめます。`op-parallel-fetch`（既定でオン）が有効なら並列で取得します。
- 各アイテムは自分のアカウントを覚えているので、コピー・詳細表示・OTP・アーカイブは自動でそのアカウントで実行します。
- あるアカウントで失敗しても、他のアカウントのアイテムは表示し、失敗したアカウントをエコーエリアに表示します。未サインインのアカウントは単独で再実行し、必要ならサインインします。
- 1つのアカウントに対して動くコマンド（`op-read`、`op-create-login`、`op-signin`、`op-whoami`）は、どのアカウントで実行するかを尋ねます。
- パスワード方式ではアカウントごとにサインインが必要で、トークンもアカウントごとに保持します。アプリ連携の場合、アカウントごとに承認が必要かどうかは 1Password 側の挙動によります。
- 全アカウント表示のときは `op-default-vault` は使いません。

## 秘密の値の扱い

### クリップボード

- コピー時は、識別用のランダムなマーカー（`op-mode-marker:<UUID>`）を先に kill-ring へ保存し、続けて実際の秘密の値を保存します。
- `op-clipboard-clear-seconds`（既定 45 秒）後に、kill-ring からマーカーとその次の値だけを削除し、文字列の中身も上書きします。その間に別のものをコピーしていても、それは消しません。
- システムのクリップボードは、中身がその秘密の値かマーカーのときだけ空にします。
- OS のクリップボード履歴ツールに残った分は消せません。履歴ツール側で除外設定をしてください。

### セッションとキャッシュ

Emacs のメーラー [Mew](https://github.com/kazu-yamamoto/Mew) のパスワード管理を参考にしています。

- パスワード方式のセッショントークンは、`op-session-lifetime`（既定 30 分）使わなければ破棄し、1Password 側もサインアウトします。使うたびに期限が延びます。
- 認証エラーのときは、古いトークンを捨ててからサインインし直します。
- `op-cache-secrets` を `t` にした場合だけ、取得したアイテムの詳細を `op-secret-cache-lifetime`（既定 5 分、使うと延長）の間メモリに保持します。既定では保持しません。OTP はキャッシュしません。
- Emacs 終了時に、未消去の秘密の値・トークン・キャッシュを消去します。
- マスターパスワードはコマンドライン引数に載せず、標準入力で `op` に渡します。

## カスタマイズ変数

| 変数 | 既定値 | 内容 |
|---|---|---|
| `op-executable` | `"op"` | `op` コマンドのパス |
| `op-account` | `nil` | `nil`（既定のアカウント）、アカウント文字列、または `all`（全アカウント） |
| `op-parallel-fetch` | `t` | 全アカウントの一覧を並列で取得する |
| `op-default-vault` | `nil` | 最初に表示する Vault（nil は全 Vault） |
| `op-list-categories` | `nil` | 一覧に出すカテゴリ（例：`("Login" "Password")`） |
| `op-signin-method` | `app` | `app`（デスクトップアプリ連携）または `password` |
| `op-app-auto-launch` | `t` | 1Password アプリが起動していなければ起動する（アプリ連携のときのみ） |
| `op-app-platform` | `linux` | `linux`、`macos`、`windows`、`wsl`、`auto` のいずれか |
| `op-app-check-command` | `nil` | アプリ起動中なら終了コード 0 を返すコマンド（nil は OS ごとの既定） |
| `op-app-launch-command` | `nil` | アプリを起動するコマンド（nil は OS ごとの既定） |
| `op-app-launch-timeout` | `15` | アプリの起動を待つ秒数 |
| `op-app-connection-error-regexp` | （ソース参照） | 「アプリにつながらない」op のエラーを判定する正規表現 |
| `op-auto-signin` | `t` | 未サインイン時に自動でサインインする |
| `op-clipboard-clear-seconds` | `45` | コピーした秘密の値を消すまでの秒数（nil で消さない） |
| `op-session-lifetime` | `30` | セッショントークンを破棄するまでの無操作時間（分） |
| `op-cache-secrets` | `nil` | アイテム詳細をメモリにキャッシュする |
| `op-secret-cache-lifetime` | `5` | キャッシュを破棄するまでの無操作時間（分） |
| `op-generate-password-recipe` | `"letters,digits,symbols,32"` | `op-create-login` で生成するパスワードの条件 |
| `op-mode-prefix-key` | `"C-c P"` | `op-mode` のプレフィックスキー（読み込み前に設定） |

## トラブルシューティング

- **`No account matches op-account`**（op のエラーは `found no accounts for filter "..."`）：`op-account` に一致するアカウントがありません。`M-x op-select-account` で選び直すか、`nil` にしてください。
- **`op-signin-method` を `password` にしたのにアプリを求められる**：1Password アプリで CLI 連携がオンになっていると、`op` はそちらを使います。そのため op-mode はパスワード方式のとき、`OP_BIOMETRIC_UNLOCK_ENABLED=false` を付けて `op` を実行します。あわせて、ターミナルで `op account add` を実行し、各アカウントを一度登録しておいてください。登録がないとサインインするアカウントがありません。
- **アプリ連携で操作が止まったように見える**：`op` は同期で呼び出すため、1Password の認証ダイアログに応答するまで Emacs は待ち状態になります。

## ライセンス

[MIT License](LICENSE)

このプロジェクトは 1Password（AgileBits Inc.）の公式ソフトウェアではなく、同社とは関係ありません。1Password は AgileBits Inc. の商標です。
