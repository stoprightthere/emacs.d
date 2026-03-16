;; Override variables defined in this file
;; in a separate file my-settings.el.

;; Themes

(defvar my/current-theme :dark
  "The current theme regime (:light or :dark).")

(defun my/get-theme (regime)
  "Get theme associated with the REGIME (:light or :dark)."
  (plist-get my/themes regime))

(defun my/toggle-light-dark-theme ()
  "Toggle light or dark theme defined in my/themes."
  (interactive)
  (disable-theme (my/get-theme my/current-theme))
  (cond ((eq   my/current-theme :light)
         (setq my/current-theme :dark))
        ((eq   my/current-theme :dark)
         (setq my/current-theme :light)))
  (load-theme (my/get-theme my/current-theme) t))


(defcustom my/themes
  '(:light tango
    :dark  deeper-blue)
  "The plist of the regimes (:light and :dark) and their associated themes."
  :set (lambda (sym val)
         (set-default-toplevel-value sym val)
         ;; reload the theme
         (disable-theme (my/get-theme my/current-theme))
         (load-theme (my/get-theme my/current-theme) t)))


;; Fonts
(defun my/set-font-attributes (settings)
  (let ((font-attributes '(:family :weight :height :width)))
    (dolist (attribute font-attributes)
      (let ((attribute-value (plist-get settings attribute))
            (face (plist-get settings :face)))
        (if attribute-value
            (set-face-attribute face nil attribute attribute-value))))))

(defcustom my/font
  '(:face      default
    :family    "Hack"
    :weight    normal
    :width     normal
    :height    100)
  "The plist associating face attributes with attribute values for the `default` face"
  :set (lambda (sym val)
         (set-default-toplevel-value sym val)
         (my/set-font-attributes my/font)))

(defcustom my/fixed-pitch
  '(:face      fixed-pitch
               :family    "Fira Code")
  "The plist associating face attributes with attribute values for the `fixed-pitch` face"
  :set (lambda (sym val)
         (set-default-toplevel-value sym val)
         (my/set-font-attributes my/fixed-pitch)))

(defcustom my/variable-pitch
  '(:face      variable-pitch
    :family    "Noto Sans")
  "The plist associating face attributes with attribute values for the `variable-pitch` face"
  :set (lambda (sym val)
         (set-default-toplevel-value sym val)
         (my/set-font-attributes my/variable-pitch)))

;; org-mode
(defvar my/org-config
  '(:org-agenda-files           nil
    :org-inbox-file             nil
    :org-default-notes-file     org-default-notes-file
    :org-work-tasks-file        nil
    :org-personal-tasks-file    nil
    :org-journal-file           nil
    :org-roam-directory         nil
    :org-download-image-dir     "~/Images/")
  "The plist, associating several org-mode related configurations with specific values of them")

;; Mail
(defvar
  my/user-mail-address  (concat user-login-name "@" system-name))
(defvar
  my/user-full-name     (user-full-name))
(defvar
  my/gmail-smtp         nil)
(defvar
  my/mbsync-config-file "~/.emacs.d/.mbsyncrc")
(defvar
  my/maildir-root       "~/.mail")


(defun my/set-docplist-attribute (plist attribute value)
  "Set the VALUE of the ATTRIBUTE of the plist PLIST."
  (setq plist (plist-put plist attribute value)))

(defmacro my/set-docplist-attribute-option (option attribute value)
  "Set the VALUE of the ATTRIBUTE of the plist OPTION that is a customizable variable."
  `(setopt ,option
          (plist-put (copy-sequence ,option) ,attribute ,value)))

(provide 'my-settings-base)
