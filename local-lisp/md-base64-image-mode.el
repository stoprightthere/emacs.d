;;; md-base64-image-mode.el --- Inline display for base64 PNGs in markdown -*- lexical-binding: t; -*-

(defgroup md-base64-image-mode nil
  "Display base64-encoded PNGs (data:image/png;base64,...) inline."
  :group 'convenience)

(defcustom md-base64-image-regexp
  (rx "![](data:image/png;base64,"
      (group (+ (any alphanumeric "+" "/" "=")));; (+ ascii)) ;;
      ")")
  "Regexp matching a Markdown image with a base64 PNG payload.
Group 1 captures the base64 content."
  :type 'regexp)

(defvar-local md-base64-image--overlays nil)
(defvar-local md-base64-image--temp-files nil)

(defun md-base64-image--cleanup ()
  "Remove overlays and delete temp files created by this mode."
  (when md-base64-image--overlays
    (mapc #'delete-overlay md-base64-image--overlays)
    (setq md-base64-image--overlays nil))
  (when md-base64-image--temp-files
    (dolist (f md-base64-image--temp-files)
      (ignore-errors (when (and f (file-exists-p f)) (delete-file f))))
    (setq md-base64-image--temp-files nil)))

(defun md-base64-image--b64-to-temp-png (b64)
  "Decode base64 string B64 and write it to a temp PNG file. Return the file path."
  (let* ((clean (replace-regexp-in-string "[ \t\n\r]" "" b64))
         (bytes (base64-decode-string clean))
         (file (make-temp-file "emacs-b64png-" nil ".png")))
    (with-temp-buffer
      (set-buffer-multibyte nil)          ;; important: write raw bytes
      (insert bytes)
      (let ((coding-system-for-write 'binary))
        (write-region (point-min) (point-max) file nil 'silent)))
    file))

(defun md-base64-image-refresh ()
  "Rescan the current buffer and display any base64 PNG markdown images inline."
  (interactive)
  (unless (image-type-available-p 'png)
    (user-error "PNG image support is not available in this Emacs build"))
  (save-excursion
    (save-restriction
      (widen)
      (md-base64-image--cleanup)
      (goto-char (point-min))
      (let ((case-fold-search nil))
        (while (re-search-forward md-base64-image-regexp nil t)
          (let* ((beg (match-beginning 0))
                 (end (match-end 0))
                 (b64 (match-string-no-properties 1))
                 (file (condition-case err
                           (md-base64-image--b64-to-temp-png b64)
                         (error
                          (message "md-base64-image: decode failed at %d: %s"
                                   beg (error-message-string err))
                          nil))))
            (when file
              (push file md-base64-image--temp-files)
              (let ((ov (make-overlay beg end)))
                (overlay-put ov 'md-base64-image t)
                (overlay-put ov 'evaporate t)
                (overlay-put ov 'display (create-image file 'png nil :ascent 'center))
                (overlay-put ov 'help-echo "Inline image (base64 PNG)")
                (push ov md-base64-image--overlays)))))))))

;;;###autoload
(define-minor-mode md-base64-image-mode
  "Toggle inline display of base64 PNG markdown images like ![](data:image/png;base64,...)."
  :lighter " b64img"
  (if md-base64-image-mode
      (progn
        (md-base64-image-refresh))
    (md-base64-image--cleanup)))

(provide 'md-base64-image-mode)
;;; md-base64-image-mode.el ends here
