;; my emacs customizing

;; Better looks
(menu-bar-mode 0)
(tool-bar-mode 0)
(set-scroll-bar-mode 'nil)
(when (< emacs-major-version 29)
  (global-linum-mode 0))
(global-hl-line-mode 0)
(show-paren-mode 1)
(setq-default cursor-type 'bar)

(setq default-input-method "russian-computer")
(setq inhibit-startup-screen t)

;; never put tabs
(setq-default indent-tabs-mode nil)

;; disable audible bell
(setq visible-bell t)

;; more lenient garbage collection
(setq gc-cons-threshold-original gc-cons-threshold)
(setq gc-cons-threshold (* 1024 1024 64))  ; set GC threshold to 64Mb -- should be fine

;; read more from the process (> 4k)
(setq read-process-output-max (* 1024 1024)) ;; 1mb

(setq native-comp-async-report-warnings-errors nil)
(native-compile-async "~/.emacs.d/local-lisp")
(add-to-list 'load-path "~/.emacs.d/local-lisp")
(setq load-prefer-newer t)


;;;;;;;; WSL ;;;;;;;;
(when (eq system-type 'windows-nt)
    (defun fp/ignore-wsl-acls (orig-fun &rest args)
      "Ignore ACLs on WSL. WSL does not provide an ACL, but emacs
expects there to be one before saving any file. Without this
advice, files on WSL can not be saved.

Note that this makes sense when Emacs runs on Windows and the
access to WSL files is needed. If Emacs itself is on WSL, this is
not needed."
      (if (string-match-p "^//wsl\$/" (car args))
          (progn (message "ignoring wsl acls") "")
        (apply orig-fun args)))

    (advice-add 'file-acl :around 'fp/ignore-wsl-acls))

(defun my/is-on-wsl ()
  "Determine if Emacs is on WSL (or WSL2).

See URL `https://emacs.stackexchange.com/a/55295'."
  (string-match "-[Mm]icrosoft" operating-system-release))

(defconst my/wsl-dump-clipboard-image-command
  "powershell.exe -Command \"(Get-Clipboard -Format image).Save('$(wslpath -w %s)')\""
  "Command template to dump the image from the clipboard in a file specified by %s.

Example usage:
`(shell-command (format my/wsl-dump-clipboard-image-command filename))'

Credit goes to fkgruber, see URL `https://github.com/abo-abo/org-download/issues/178#issuecomment-1367606769'.")


;;;;;;;; PACKAGES ;;;;;;;;
;; elpa config
(require 'package)
(let* ((no-ssl (and (memq system-type '(windows-nt ms-dos))
                    (not (gnutls-available-p))))
       (proto (if no-ssl "http" "https")))
  ;; Comment/uncomment these two lines to enable/disable MELPA and MELPA Stable as desired
  (add-to-list 'package-archives (cons "melpa-stable" (concat proto "://stable.melpa.org/packages/")) t)
  (add-to-list 'package-archives (cons "melpa" (concat proto "://melpa.org/packages/")) t)
  (when (< emacs-major-version 24)
    ;; For important compatibility libraries like cl-lib
    (add-to-list 'package-archives (cons "gnu" (concat proto "://elpa.gnu.org/packages/")))))
(setq package-archive-priorities
      '(("melpa-stable" . 10)
        ("gnu" . 5)
        ("melpa" . 0)))
(package-initialize)

;; use use-package
(unless (package-installed-p 'use-package)
  (package-install 'use-package))
(require 'use-package)

;; configure packages
(use-package magit
  :ensure t
  :bind ("C-x g" . magit-status))

(use-package pyvenv
  :ensure t)

(use-package corfu
  :ensure t)

(use-package org-superstar
  :ensure t)

(use-package markdown-mode
  :ensure t)

(use-package flymake
  :ensure t)

(use-package flymake-ruff
  :disabled
  :ensure t
  :config
  (setq flymake-ruff-program "uv run ruff")
  :hook (eglot-managed-mode . flymake-ruff-load))

(use-package dockerfile-mode
  :ensure t)

(use-package which-key
  :ensure t
  :config
  (which-key-mode))

(use-package doc-view
  :config
  (setq doc-view-resolution 200))

;; grep -> ripgrep
(use-package grep
  :config
  (when (executable-find "rg")
    (grep-apply-setting  ;; orig:
     'grep-command '("rg -nS --no-heading "))
    (grep-apply-setting
     'grep-find-command
     ;; orig: ("find . -type f -exec grep --color=auto -nH --null -e  \\{\\} +" . 54)
     '("rg -n -H --no-heading -e '' $(git rev-parse --show-toplevel || pwd)" . 27))
    (grep-apply-setting
     'grep-use-null-device nil)))

;; use tree-sitter when emacs is old
(when (< emacs-major-version 29)
  (use-package tree-sitter
    :hook (python-mode . tree-sitter-hl-mode)
    :ensure t)
  (use-package tree-sitter-langs
    :ensure t))

;; use build-in treesit when emacs is new
(use-package treesit
  :if (>= emacs-major-version 29)
  :config
  (setq treesit-language-source-alist
        '((python     "https://github.com/tree-sitter/tree-sitter-python")
          (go         "https://github.com/tree-sitter/tree-sitter-go")
          (javascript "https://github.com/tree-sitter/tree-sitter-javascript")
          (bash       "https://github.com/tree-sitter/tree-sitter-bash")
          (css        "https://github.com/tree-sitter/tree-sitter-css")
          (html       "https://github.com/tree-sitter/tree-sitter-html")))
  (setq major-mode-remap-alist
        '((python-mode . python-ts-mode)
          (js-mode     . js-ts-mode)
          (bash-mode   . bash-ts-mode)
          (css-mode    . css-ts-mode))))

(use-package gptel
  :ensure t
  :config
  (gptel-make-openai "llama-cpp"
    :stream t
    :protocol "http"
    :host "localhost:8080"                ;; llama.cpp server location
    :models '("test")))                   ;; any names, doesn't matter for llama.cpp

(use-package ultra-scroll
  :ensure t
  :init
  (setq scroll-conservatively 3
        scroll-margin 0)
  :config
  (ultra-scroll-mode 1))


;;;;;;;; VTERM ;;;;;;;;
(require 'cl-lib)
(require 'seq)
(require 'transient)

(defconst my/vterm--switch-keys
  (append (mapcar #'number-to-string (number-sequence 1 9))
          '("0")
          (mapcar (lambda (c) (char-to-string c))
                  (number-sequence ?a ?z)))
  "Keys used to select vterm sessions in the transient menu.")

(defun my/vterm--dir-name (dir)
  "Return a human-friendly name for DIR."
  (let ((name (file-name-nondirectory (directory-file-name dir))))
    (if (string= name "") "/" name)))

(defun my/vterm-rename-buffer ()
  "Rename a vterm buffer to include the current directory name."
  (when (derived-mode-p 'vterm-mode)
    (let* ((dir (or default-directory ""))
           (dir-name (my/vterm--dir-name dir))
           (base (format "%s [%s]" vterm-buffer-name dir-name))
           (name (generate-new-buffer-name base)))
      (rename-buffer name t))))

(defun my/vterm--buffers ()
  "Return a list of live vterm buffers."
  (seq-filter
   (lambda (buf)
     (buffer-live-p buf))
   (seq-filter
    (lambda (buf)
      (with-current-buffer buf
        (derived-mode-p 'vterm-mode)))
    (nreverse (buffer-list)))))

(defun my/vterm-switch-by-name ()
  "Switch to a vterm buffer using completion."
  (interactive)
  (let* ((buffers (my/vterm--buffers))
         (names (mapcar #'buffer-name buffers)))
    (if (null names)
        (user-error "No vterm buffers")
      (switch-to-buffer
       (completing-read "Vterm: " names nil t)))))

(defun my/vterm--transient-children (_children)
  "Build transient suffixes for all vterm buffers."
  (let* ((buffers (my/vterm--buffers))
         (keys my/vterm--switch-keys)
         (direct-count (min (length buffers) (length keys)))
         (direct-bufs (seq-take buffers direct-count))
         (extra-bufs (seq-drop buffers direct-count))
         (suffixes
          (cl-loop for buf in direct-bufs
                   for key in keys
                   collect (list key (buffer-name buf)
                                 `(lambda ()
                                    (interactive)
                                    (switch-to-buffer ,(buffer-name buf)))))))
    (when extra-bufs
      (setq suffixes
            (append suffixes
                    (list (list "?" "Select by name" #'my/vterm-switch-by-name)
                          "Other sessions (use `?` to select):")
                    (mapcar (lambda (buf) (format "  %s" (buffer-name buf)))
                            extra-bufs))))
    (when (null buffers)
      (setq suffixes
            (list (list "?" "Select by name" #'my/vterm-switch-by-name)
                  "No vterm buffers")))
    (append (transient-parse-suffixes
             'my/vterm-switch
             (seq-filter #'listp suffixes))
            (seq-filter #'stringp suffixes))))

(transient-define-prefix my/vterm-switch ()
  "Switch between vterm sessions."
  ["Vterm Sessions"
   :class transient-column
   :setup-children my/vterm--transient-children]
  ["Actions"
   ("n" "New session" vterm)
   ("g" "Refresh" transient-update)
   ("q" "Quit" transient-quit-one)])

(defun my/vterm-fix-ansi-backgrounds ()
  "Ensure vterm attributes stay visible with themes that omit term backgrounds."
  (dolist (face '(vterm-color-black vterm-color-red vterm-color-green
                                   vterm-color-yellow vterm-color-blue
                                   vterm-color-magenta vterm-color-cyan
                                   vterm-color-white vterm-color-bright-black
                                   vterm-color-bright-red
                                   vterm-color-bright-green
                                   vterm-color-bright-yellow
                                   vterm-color-bright-blue
                                   vterm-color-bright-magenta
                                   vterm-color-bright-cyan
                                   vterm-color-bright-white))
    (let ((fg (face-foreground face nil 'default))
          (bg (face-background face nil 'default)))
      (when (and fg (or (null bg) (string= bg "unspecified-bg")))
        (set-face-attribute face nil :background fg))))
  ;; Codex uses inverse video in several UI elements; make it visibly inverted.
  (let ((default-fg (face-foreground 'default nil 'default))
        (default-bg (face-background 'default nil 'default)))
    (when (and default-fg default-bg)
      (set-face-attribute 'vterm-color-inverse-video nil
                          :foreground default-bg
                          :background default-fg))))

(defun my/vterm-with-color-env (orig-fn &rest args)
  "Run ORIG-FN with `NO_COLOR' removed from child process environment."
  (let ((process-environment
         (seq-remove
          (lambda (entry)
            (or (string= entry "NO_COLOR")
                (string-prefix-p "NO_COLOR=" entry)))
          process-environment)))
    (apply orig-fn args)))

(defconst my/vterm-sgr2-refresh-script
  (expand-file-name "local-lisp/vterm-sgr2-refresh.sh" user-emacs-directory)
  "Script that reapplies the local vterm SGR 2 patch and rebuilds the module.")

(defun my/vterm--latest-install-dir ()
  "Return newest installed vterm package directory, or nil if missing."
  (let* ((elpa-dir (expand-file-name "elpa" user-emacs-directory))
         (dirs (and (file-directory-p elpa-dir)
                    (directory-files elpa-dir t "^vterm-[0-9].*" t))))
    (when dirs
      (car (last (sort dirs #'string-version-lessp))))))

(defun my/vterm--sgr2-patched-p (vterm-dir)
  "Return non-nil when VTERM-DIR contains the local SGR 2 patch."
  (let ((header (expand-file-name
                 "build/libvterm-prefix/src/libvterm/include/vterm.h"
                 vterm-dir)))
    (and (file-readable-p header)
         (with-temp-buffer
           (insert-file-contents header)
           (re-search-forward "VTERM_ATTR_FAINT" nil t)))))

(defun my/vterm--refresh-sentinel (proc _event)
  "Report completion status for PROC."
  (when (memq (process-status proc) '(exit signal))
    (if (= (process-exit-status proc) 0)
        (message "vterm SGR 2 refresh finished")
      (message "vterm SGR 2 refresh failed; see %s"
               (buffer-name (process-buffer proc))))))

(defun my/vterm-refresh-sgr2 (&optional quiet)
  "Reapply local vterm SGR 2 patch and rebuild.
When QUIET is non-nil, do not pop the output buffer."
  (interactive)
  (if (not (file-executable-p my/vterm-sgr2-refresh-script))
      (if quiet
          (message "vterm SGR 2 refresh skipped: script is missing")
        (user-error "Missing executable script: %s" my/vterm-sgr2-refresh-script))
    (let ((buf (get-buffer-create "*vterm-sgr2-refresh*")))
      (with-current-buffer buf
        (erase-buffer))
      (let ((proc (start-process "vterm-sgr2-refresh"
                                 buf
                                 my/vterm-sgr2-refresh-script)))
        (set-process-sentinel proc #'my/vterm--refresh-sentinel)
        (unless quiet
          (display-buffer buf))
        proc))))

(defun my/vterm--package-name (pkg)
  "Extract package name symbol from PKG."
  (cond
   ((symbolp pkg) pkg)
   ((and (fboundp 'package-desc-p) (package-desc-p pkg))
    (package-desc-name pkg))
   ((and (consp pkg) (symbolp (car pkg)))
    (car pkg))
   (t nil)))

(defun my/vterm--refresh-after-package-install (orig-fn pkg &rest args)
  "Run ORIG-FN, then refresh patched vterm when PKG is `vterm'."
  (let ((result (apply orig-fn pkg args)))
    (when (eq (my/vterm--package-name pkg) 'vterm)
      (my/vterm-refresh-sgr2 t))
    result))

(defun my/vterm--refresh-after-package-upgrade (orig-fn pkg-desc &rest args)
  "Run ORIG-FN, then refresh patched vterm after upgrading PKG-DESC."
  (let ((result (apply orig-fn pkg-desc args)))
    (when (eq (my/vterm--package-name pkg-desc) 'vterm)
      (my/vterm-refresh-sgr2 t))
    result))

(defun my/vterm-maybe-refresh-sgr2 ()
  "Refresh vterm SGR 2 patch when latest vterm install is unpatched."
  (let ((vterm-dir (my/vterm--latest-install-dir)))
    (when (and vterm-dir
               (not (my/vterm--sgr2-patched-p vterm-dir)))
      (message "Detected unpatched vterm install at %s; refreshing" vterm-dir)
      (my/vterm-refresh-sgr2 t))))

(add-hook 'emacs-startup-hook #'my/vterm-maybe-refresh-sgr2)

(with-eval-after-load 'package
  (unless (advice-member-p #'my/vterm--refresh-after-package-install
                           'package-install)
    (advice-add 'package-install :around
                #'my/vterm--refresh-after-package-install))
  (when (and (fboundp 'package-upgrade)
             (not (advice-member-p #'my/vterm--refresh-after-package-upgrade
                                   'package-upgrade)))
    (advice-add 'package-upgrade :around
                #'my/vterm--refresh-after-package-upgrade)))

(use-package vterm
  :defer t
  :custom
  (vterm-term-environment-variable "xterm-256color")
  (vterm-environment '("COLORTERM=truecolor" "FORCE_COLOR=3" "CLICOLOR_FORCE=1"))
  (vterm-disable-bold-font nil)
  (vterm-disable-inverse-video nil)
  (vterm-disable-underline nil)
  (vterm-set-bold-hightbright t)
  :bind (("C-c v" . my/vterm-switch)
         ("C-c V" . vterm))
  :config
  (unless (advice-member-p #'my/vterm-with-color-env 'vterm)
    (advice-add 'vterm :around #'my/vterm-with-color-env))
  (unless (advice-member-p #'my/vterm-with-color-env 'vterm-other-window)
    (advice-add 'vterm-other-window :around #'my/vterm-with-color-env))
  :hook ((vterm-mode . my/vterm-rename-buffer)
         (vterm-mode . my/vterm-fix-ansi-backgrounds)))


;;;;;;;; COMPLETION ;;;;;;;;
(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

(use-package vertico
  :ensure t
  :config
  (vertico-mode))

;; perform INLINE completion on pressing TAB (i.e. ESC TAB in vanilla Emacs)
(setq tab-always-indent 'complete)


;;;;;;;; PERSONAL SETTINGS ;;;;;;;;
(let* ((my/settings-base-file "~/.emacs.d/local-lisp/my-settings-base.el")
       (my/settings-overload-file "~/.emacs.d/local-lisp/my-settings.el"))
  (require 'my-settings-base)
  (when (file-exists-p my/settings-overload-file)
    (require 'my-settings)))

;; Theme
(load-theme (my/get-theme my/current-theme) t)

;; Fonts
(let ((font-attributes '(:family :weight :height :width))
      (font-settings '(my/font my/variable-pitch my/fixed-pitch)))
  (dolist (attribute font-attributes)
    (dolist (settings font-settings)
      (let ((attribute-value (plist-get (eval settings) attribute))
            (face (plist-get (eval settings) :face)))
        (if attribute-value
            (set-face-attribute face nil attribute attribute-value))))))

(when (>= emacs-major-version 28)
  (use-package ligature
    :ensure t
    :config
    ;; Enable the "www" ligature in every possible major mode
    (ligature-set-ligatures 't '("www"))
    ;; Enable traditional ligature support in eww-mode, if the
    ;; `variable-pitch' face supports it
    (ligature-set-ligatures 'eww-mode '("ff" "fi" "ffi"))
    ;; Enable all Cascadia Code ligatures in programming modes
    (ligature-set-ligatures 'prog-mode '("|||>" "<|||" "<==>" "<!--" "####" "~~>" "***" "||=" "||>"
                                         ":::" "::=" "=:=" "===" "==>" "=!=" "=>>" "=<<" "=/=" "!=="
                                         "!!." ">=>" ">>=" ">>>" ">>-" ">->" "->>" "-->" "---" "-<<"
                                         "<~~" "<~>" "<*>" "<||" "<|>" "<$>" "<==" "<=>" "<=<" "<->"
                                         "<--" "<-<" "<<=" "<<-" "<<<" "<+>" "</>" "###" "#_(" "..<"
                                         "..." "+++" "/==" "///" "_|_" "www" "&&" "^=" "~~" "~@" "~="
                                         "~>" "~-" "**" "*>" "*/" "||" "|}" "|]" "|=" "|>" "|-" "{|"
                                         "[|" "]#" "::" ":=" ":>" ":<" "$>" "==" "=>" "!=" "!!" ">:"
                                         ">=" ">>" ">-" "-~" "-|" "->" "--" "-<" "<~" "<*" "<|" "<:"
                                         "<$" "<=" "<>" "<-" "<<" "<+" "</" "#{" "#[" "#:" "#=" "#!"
                                         "##" "#(" "#?" "#_" "%%" ".=" ".-" ".." ".?" "+>" "++" "?:"
                                         "?=" "?." "??" ";;" "/*" "/=" "/>" "//" "__" "~~" "(*" "*)"
                                         "\\\\" "://"))
    ;; Enables ligature checks globally in all buffers. One can also do it
    ;; per mode with `ligature-mode'.
    (global-ligature-mode t)))

;; org-mode
(use-package org
  :config
  (setq org-log-done t)
  (setq org-startup-indented t)
  (setq org-image-actual-width 512)
  (setq org-todo-keywords
        '((sequence "TODO" "|" "DONE")
          (sequence "|" "CANCELLED")))
  (setq org-hide-emphasis-markers t)
  (setq org-pretty-entities nil)
  (setq org-ellipsis " …")

  (add-hook 'org-mode-hook
            (lambda ()
              (visual-line-mode)
              (variable-pitch-mode)
              (org-superstar-mode)))

  (setq org-agenda-files (plist-get my/org-config :org-agenda-files))
  (setq org-default-notes-file (plist-get my/org-config :org-default-notes-file))

  (setq org-id-link-to-org-use-id 'create-if-interactive)

  ;; org-capture
  (setq org-capture-templates
      `(("t" "Todo" entry (file ,(plist-get my/org-config :org-inbox-file))
         "* TODO %?\n%U\n%a")
        ("m" "Meeting" entry (file+headline ,(plist-get my/org-config :org-inbox-file) "Meetings")
         "* %? \n%^T\n")
        ("s" "Stuff" entry (file ,(plist-get my/org-config :org-inbox-file))
         "* %?\n %U")
        ("j" "Journal" entry (file+datetree ,(plist-get my/org-config :org-journal-file))
         "* %?\n")))

  :bind
  ("C-c a" . org-agenda)
  ("C-c t" . org-capture))


(defconst my/xclip-dump-clipboad-image-command
  "xclip -selection clipboard -t image/png -o > %s"
  "Command template to dump the image from the clipboard in a file specified by %s using xclip.")


(use-package org-download
  :ensure t
  :config
  (setq
   org-download-backend "wget"
   org-download-method 'directory)
  (when (my/is-on-wsl)
    (setq org-download-screenshot-method my/wsl-dump-clipboard-image-command))
  (when (and
         (not (my/is-on-wsl))
         (eq system-type 'gnu/linux)
         (executable-find "xclip"))
    (setq org-download-screenshot-method my/xclip-dump-clipboad-image-command))
  (setq-default
   org-download-image-dir (plist-get my/org-config :org-download-image-dir)))


;;;;;;;; MAIL ;;;;;;;;
;; mu4e
(defun my/mu4e-set-mail-password ()
  (let ((password (string-trim
                   (with-temp-buffer
                     (insert-file-contents
                      (expand-file-name ".gmail-app-password.gpg" user-emacs-directory))
                     (buffer-string)))))
    (setenv "GMAIL_APP_PASSWORD" password)))

(defun my/mu4e-clear-mail-password ()
  (setenv "GMAIL_APP_PASSWORD" nil))

(use-package mu4e
  :bind ("C-c m" . mu4e)
  :hook
  (mu4e-update-pre-hook . my/mu4e-set-mail-password)
  (mu4e-update-post-hook . my/mu4e-clear-mail-password)
  :config
  ;; general mu4e config
  (setq
   mail-user-agent                  'mu4e-user-agent
   mu4e-get-mail-command            (format "mbsync -c %s -a"
                                            (shell-quote-argument
                                             (expand-file-name my/mbsync-config-file)))
   mu4e-change-filenames-when-moving t
   mu4e-update-interval             600
   user-mail-address                my/user-mail-address
   user-full-name                   my/user-full-name
   mu4e-view-show-images            t
   mu4e-sent-messages-behavior      'delete
   mu4e-index-lazy-check             t
   mu4e-index-cleanup                nil)

  ;; Gmail folders synced by mbsync.
  (setq
   mu4e-maildir                     (expand-file-name my/maildir-root)
   mu4e-sent-folder                 "/gmail/[Gmail]/Sent"
   mu4e-drafts-folder               "/gmail/[Gmail]/Drafts"
   mu4e-trash-folder                "/gmail/[Gmail]/Trash"
   mu4e-refile-folder               "/gmail/[Gmail]/All Mail")

  ;; headers fields
  (setq mu4e-headers-fields '((:human-date . 12)
                              (:maildir . 12)
                              (:flags . 6)
                              (:from . 22)
                              (:subject)))

  (add-to-list 'mu4e-bookmarks
               '( :name "Inbox"
                  :key ?i
                  :query "maildir:/gmail/INBOX" ))

  ;; Gmail send (smtp) config
  (when (or my/gmail-smtp
            (string-match-p "@gmail\\.com\\'" my/user-mail-address))
      (setq
       message-send-mail-function    'smtpmail-send-it
       smtpmail-default-smtp-server  "smtp.gmail.com"
       smtpmail-smtp-server          "smtp.gmail.com"
       smtpmail-smtp-user            my/user-mail-address
       smtpmail-local-domain         "gmail.com"
       smtpmail-stream-type          'starttls
       smtpmail-auth-supported       '(plain login)
       smtpmail-smtp-service         587
       starttls-extra-arguments      nil)
    (add-to-list 'auth-sources "~/.authinfo.gpg")))


;;;;;;;; TELEGA ;;;;;;;;
(defun my/telega-attach-clipboard-wsl (doc-p)
  "Attach image from the clipboard in telega chatbuf under WSL.

This works by saving the contents of the clipboard to a temporary
file via PowerShell and running `telega-chatbuf-attach-media'.

If `\\[universal-argument]' is given, then attach clipboard as document.
"
  (interactive "P")
  (let* ((temporary-file-directory telega-temp-dir)
         (tmpfile (telega-temp-name "clipboard" ".png"))
         (coding-system-for-write 'binary))
    (shell-command (format my/wsl-dump-clipboard-image-command tmpfile))
    (telega-chatbuf-attach-media tmpfile (when doc-p 'preview))))

(use-package telega
  :defer t
  :bind-keymap ("C-c x" . telega-prefix-map))

(use-package telega
  :defer t
  :if (my/is-on-wsl)
  :bind (:map telega-chat-mode-map ("C-c C-v" . my/telega-attach-clipboard-wsl)))


;;;;;;;; CODING ;;;;;;;;

(defun my/python-ts-find-ancestor (type)
  "Walk up the tree-sitter node tree from point and return the first node of TYPE, or nil."
  (when (and (fboundp 'treesit-node-at)
             (treesit-available-p)
             (treesit-buffer-root-node))
    (let ((node (treesit-node-at (window-start))))
      (catch 'found
        (while node
          (when (equal (treesit-node-type node) type)
            (throw 'found node))
          (setq node (treesit-node-parent node)))
        nil))))

(defun my/python-class-header-update ()
  "Update the header-line to show current class (and method) when scrolled off screen."
  (let ((class-node (my/python-ts-find-ancestor "class_definition")))
    (setq header-line-format
          (when class-node
            (let* ((class-pos  (treesit-node-start class-node))
                   (class-name (let ((n (treesit-node-child-by-field-name class-node "name")))
                                 (when n (treesit-node-text n t)))))
              (when (and class-name (< class-pos (window-start)))
                (let* ((class-line (save-excursion
                                     (goto-char class-pos)
                                     (string-trim-left
                                      (buffer-substring (line-beginning-position)
                                                        (- (line-end-position) 1)))))
                       (method-node (my/python-ts-find-ancestor "function_definition"))
                       (method-name (when method-node
                                      (let ((n (treesit-node-child-by-field-name method-node "name")))
                                        (when n (treesit-node-text n t)))))
                       (suffix (when method-name (concat "->" method-name "()"))))
                  (list (concat " " class-line suffix " ")))))))))

(define-minor-mode my/python-class-header-mode
  "Show the current Python class in the header line."
  :lighter ""
  (if my/python-class-header-mode
      (add-hook 'post-command-hook #'my/python-class-header-update nil t)
    (remove-hook 'post-command-hook #'my/python-class-header-update t)
    (setq header-line-format nil)))

(use-package python
  :config
  (defun my/python-mode-hook ()
    (setq indent-tabs-mode nil)
    (setq tab-width 4)
    (setq python-indent-offset 4)
    (hl-line-mode 1)
    (when (file-directory-p "~/.local/bin")
      (add-to-list 'exec-path "~/.local/bin"))
    (when (>= emacs-major-version 29)
      (my/python-class-header-mode 1)))
   :hook
   (python-mode . my/python-mode-hook)
   (python-ts-mode . my/python-mode-hook))

(use-package cc-mode
  :init
  (add-hook 'c++-mode-hook
            (lambda ()
              (define-key c++-mode-map [?\C-c ?\C-c] 'compile)
              (define-key c++-mode-map [?\C-c d]   'gdb)
              (c-set-offset 'access-label '0)
              (c-set-offset 'inclass '+)
              (auto-complete-mode)))
  :mode ("\\.h\\'" . c++-mode))

;; treat .m files as Octave
(add-to-list 'auto-mode-alist '("\\.m\\'" . octave-mode))

;; allow eldoc to use at most 3 lines in the echo area
;; prevents the echo area blowing up with a huge doc
(setq eldoc-echo-area-use-multiline-p 3)


;;;;;;;; DIRED ;;;;;;;;
(use-package dired-x
  :hook (dired-mode . dired-omit-mode)
  :config
  (setq dired-listing-switches "-alh")
  (setq dired-omit-files
        (concat dired-omit-files "\\|^\\..+$")))


;;;;;;;; SPECIAL KEYS ;;;;;;;;
(global-set-key (kbd "C-c l") 'goto-line)


;;;;;;;; WINDOWS ;;;;;;;;
;; some Windows-specific options that are not local
(when (memq system-type '(windows-nt ms-dos))
  ;; tramp for windows
  (setq tramp-default-method "plink")
  ;; git ask password in gui (for windows)
  (setenv "GIT_ASKPASS" "git-gui--askpass")
  ;; encoding
  (set-coding-system-priority 'utf-8 'utf-16 'windows-1251 'cp1251-dos)
  ;; Prevent issues with the Windows null device (NUL)
  ;; when using cygwin find with rgrep.
  (defadvice grep-compute-defaults (around grep-compute-defaults-advice-null-device)
    "Use cygwin's /dev/null as the null-device."
    (let ((null-device "/dev/null"))
      ad-do-it))
  (ad-activate 'grep-compute-defaults))


;;;;;;;; CUSTOM ;;;;;;;;
;; set custom file for Customize but never load it
(setq custom-file "~/.emacs.d/local-lisp/custom.el")
