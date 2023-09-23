;; Override variables defined in this file
;; in a separate file my-settings.el.

;; Themes
(defvar my/themes
  '(:light tango
    :dark deeper-blue)
  "The plist of the regimes (:light and :dark) and their associated themes.")

(defvar my/current-theme :dark
  "The current theme regime (:light or :dark).")

(defun my/get-theme (regime)
  "Get theme associated with the REGIME (:light or :dark)."
  (plist-get my/themes regime))

(defun my/toggle-light-dark-theme ()
  "Toggle light or dark theme defined in my/themes."
  (interactive)
  (disable-theme (my/get-theme my/current-theme))
  (cond ((eq my/current-theme :light)
         (setq my/current-theme :dark))
        ((eq my/current-theme :dark)
         (setq my/current-theme :light)))
  (load-theme (my/get-theme my/current-theme) t))

;; Fonts
(defvar my/font
  '(:face default
    :family "Hack"
    :weight normal
    :width normal
    :height 100)
  "The plist associating face attributes with attribute values for the `default` face")

(defvar my/fixed-pitch
  '(:face fixed-pitch
    :family "Fira Code")
  "The plist associating face attributes with attribute values for the `fixed-pitch` face")

(defvar my/variable-pitch
  '(
    :face variable-pitch
    :family "Noto Sans")
  "The plist associating face attributes with attribute values for the `variable-pitch` face")

;; org-mode
(defvar my/org-config
  '(:org-agenda-files nil
    :org-inbox-file nil
    :org-default-notes-file org-default-notes-file
    :org-work-tasks-file nil
    :org-personal-tasks-file nil
    :org-journal-file nil
    :org-roam-directory nil
    :org-download-image-dir "~/Images/")
  "The plist, associating several org-mode related configurations with specific values of them")

;; Mail
(defvar
  my/user-mail-address  (concat user-login-name "@" system-name))
(defvar
  my/user-full-name     (user-full-name))
(defvar
  my/gmail-smtp         nil)


(defun my/set-docplist-attribute (plist attribute value)
  "Set the VALUE of the ATTRIBUTE of the plist PLIST."
  (setq plist (plist-put plist attribute value)))

(provide 'my-settings-base)
