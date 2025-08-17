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

(use-package dockerfile-mode
  :ensure t)

(use-package which-key
  :ensure t
  :config
  (which-key-mode))

(use-package emojify
  :ensure t)

(use-package doc-view
  :config
  (setq doc-view-resolution 200))

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
        '((python "https://github.com/tree-sitter/tree-sitter-python")
          (javascript "https://github.com/tree-sitter/tree-sitter-javascript")))
  (setq major-mode-remap-alist
        '((python-mode . python-ts-mode)
          (js-mode . js-ts-mode))))

(use-package gptel
  :ensure t
  :config
  (gptel-make-openai "llama-cpp"
    :stream t
    :protocol "http"
    :host "localhost:8080"                ;; llama.cpp server location
    :models '("test")))                   ;; any names, doesn't matter for llama.cpp


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

  ;; org-capture
  (setq org-capture-templates
      `(("t" "Todo" entry (file ,(plist-get my/org-config :org-inbox-file))
         "* TODO %?\n")
        ("m" "Meeting" entry (file+headline ,(plist-get my/org-config :org-inbox-file) "Meetings")
         "* %? \n%^T\n")
        ("s" "Stuff" entry (file ,(plist-get my/org-config :org-inbox-file))
         "* %?\n %U")
        ("j" "Journal" entry (file+datetree ,(plist-get my/org-config :org-journal-file))
         "* %?\n")))

  :bind
  ("C-c a" . org-agenda)
  ("C-c t" . org-capture))

(use-package org-download
  :config
  (setq
   org-download-backend "wget"
   org-download-method 'directory)
  (when (my/is-on-wsl)
   (setq org-download-screenshot-method my/wsl-dump-clipboard-image-command))
  (setq-default
   org-download-image-dir (plist-get my/org-config :org-download-image-dir)))


;;;;;;;; MAIL ;;;;;;;;
;; mu4e
(use-package mu4e
  :bind ("C-c m" . mu4e)
  :config
  ;; general mu4e config
  (setq
   mail-user-agent                  'mu4e-user-agent
   mu4e-get-mail-command            "mbsync -a"
   mu4e-update-interval             600
   user-mail-address                my/user-mail-address
   user-full-name                   my/user-full-name
   mu4e-view-show-images            t
   mu4e-sent-messages-behavior      'delete)

  ;; headers fields
  (setq mu4e-headers-fields '((:human-date . 12)
                              (:maildir . 12)
                              (:flags . 6)
                              (:from . 22)
                              (:subject)))

  ;; Gmail send (smtp) config
  (when my/gmail-smtp
      (setq
       message-send-mail-function    'smtpmail-send-it
       smtpmail-default-smtp-server  "smtp.gmail.com"
       smtpmail-smtp-server          "smtp.gmail.com"
       smtpmail-local-domain         "gmail.com"
       smtpmail-starttls-credentials '(("smtp.gmail.com" 587 nil nil))
       smtpmail-smtp-service         587
       starttls-extra-arguments      nil
       starttls-gnutls-program       "gnutls-cli"
       starttls-extra-arguments      nil
       starttls-use-gnutls           t)))


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
(use-package python
  :config
  (defun my/python-mode-hook ()
    (setq indent-tabs-mode nil)
    (setq tab-width 4)
    (setq python-indent-offset 4)
    (hl-line-mode 1)
    (when (file-directory-p "~/.local/bin")
      (add-to-list 'exec-path "~/.local/bin"))
   :hook
   (python-mode . my/python-mode-hook)
   (if (>= emacs-major-version 29)
       (python-ts-mode . my/python-mode-hook))))

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

(use-package dape
  :hook
  ;; Save breakpoints on quit
  (kill-emacs . dape-breakpoint-save)
  ;; Load breakpoints on startup
  (after-init . dape-breakpoint-load)

  :config
  ;; Info buffers like gud (gdb-mi)
  (setq dape-buffer-window-arrangement 'gud)
  (setq dape-info-hide-mode-line nil)

  :ensure t)

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
