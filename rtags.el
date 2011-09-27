;; (defun rtags-setup-hooks () (interactive)
;;   (remove-hook 'after-save-hook 'rtags-sync-all-open-files)
;;   (remove-hook 'find-file-hooks 'rtags-sync-all-open-files)
  ;; (add-hook 'after-save-hook 'rtags-sync-all-open-files)
  ;; (add-hook 'find-file-hooks 'rtags-sync-all-open-files)
  ;; )

(defgroup rtags nil
  "Minor mode for rtags."
  :group 'tools
  :prefix "rtags-")

;; (defcustom rtags-enable t
;;   "Whether or rtags is enabled"
;;   :type 'boolean
;;   :group 'rtags)

(defun rtags-goto-location(location)
  (let (line column)
    (string-match "\\(.*\\):\\([0-9]+\\):\\([0-9]+\\)" location)
    (if (match-beginning 1)
        (progn
          (setq line (string-to-int (match-string 2 location)))
          (setq column (string-to-int (match-string 3 location)))
          (find-file (match-string 1 location))
          (goto-char (point-min))
          (forward-line (- line 1))
          (forward-char (- column 1))))))

(defun rtags-goto-symbol-at-point()
  (interactive)
  (let ((bufname (buffer-file-name))
        (line (int-to-string (line-number-at-pos)))
        (column nil))
    (save-excursion
      (if (looking-at "[0-9A-Za-z_]")
          (progn
            (while (and (> (point) 0) (looking-at "[0-9A-Za-z_]"))
              (backward-char))
            (if (not (looking-at "[0-9A-Za-z_]"))
                (forward-char))
            (setq column (int-to-string (- (point) (point-at-bol) -1))))))
    (with-temp-buffer
      ;; (message (executable-find "rc"))
      ;; (message (concat (executable-find "rc") " --follow-symbol " bufname ":" line ":" column))
      (call-process (executable-find "rc") nil t nil "--follow-symbol" (concat bufname ":" line ":" column))
      (rtags-goto-location (buffer-string)))
    )
  )

(defun rtags-find-references-at-point()
  (interactive)
  (let ((bufname (buffer-file-name))
        (line (int-to-string (line-number-at-pos)))
        (column nil)
        (previous (current-buffer)))
    (save-excursion
      (if (looking-at "[0-9A-Za-z_]")
          (progn
            (while (and (> (point) 0) (looking-at "[0-9A-Za-z_]"))
              (backward-char))
            (if (not (looking-at "[0-9A-Za-z_]"))
                (forward-char))
            (setq column (int-to-string (- (point) (point-at-bol) -1))))))
    (if (get-buffer "*Rtags-Complete*")
        (kill-buffer "*Rtags-Complete*"))
    (switch-to-buffer (generate-new-buffer "*Rtags-Complete*"))
      ;; (message (executable-find "rc"))
      ;; (message (concat (executable-find "rc") " --follow-symbol " bufname ":" line ":" column))
    (call-process (executable-find "rc") nil t nil "--references" (concat bufname ":" line ":" column))
    (if (= (point-min) (point-max))
        (progn
          (kill-buffer "*Rtags-Complete*")
          (switch-to-buffer previous))
      (if (= (count-lines (point-min) (point-max)) 1)
          (rtags-goto-location (buffer-string))
        (progn
          (goto-char (point-min))
          (compilation-mode))))
  ))


(defun rtags-complete (string predicate code)
  (let ((completions))
    (with-temp-buffer
      (call-process "rc" nil t nil "-S" "-n" "-l" string)
      (setq 'completions (split-string (buffer-string))))))
      ;; (all-completion string completions))))
      ;; (cond ((eq code nil)
      ;;        (try-completion string completions predicate))
      ;;       ((eq code t)
      ;;        (all-completions string completions predicate))
      ;;       ((eq code 'lambda)
      ;;        (if (intern-soft string completions) t nil))))))


(defun rtags-find-symbol ()
  (interactive)
  (let (tagname prompt input completions previous)
    (setq tagname (gtags-current-token))
    (setq previous (current-buffer))
    (if tagname
        (setq prompt (concat "Find symbol: (default " tagname ") "))
      (setq prompt "Find symbol: "))
    (with-temp-buffer
      (call-process "rc" nil t nil "-S" "-C" "-l" "")
      (setq completions (split-string (buffer-string))))
    (setq input (completing-read prompt completions nil nil nil gtags-history-list))
    (if (not (equal "" input))
        (setq tagname input))
    (if (get-buffer "*Rtags-Complete*")
        (kill-buffer "*Rtags-Complete*"))
    (switch-to-buffer (generate-new-buffer "*Rtags-Complete*"))
    (call-process "rc" nil t nil "-S" "-l" tagname)
    (if (= (point-min) (point-max))
        (progn
          (kill-buffer "*Rtags-Complete*")
          (switch-to-buffer previous))
      (if (= (count-lines (point-min) (point-max)) 1)
          (rtags-goto-location (buffer-string))
        (progn
          (goto-char (point-min))
          (compilation-mode))))
    ))

(provide 'rtags)