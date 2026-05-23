;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!



;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; ============================================================
;; 🧠 JOURNAL SYSTEM (literate config)
;;
;; Goal:
;; - Fast log entries (SPC n j j)
;; - Contextual org-capture entries (SPC n j c)
;; - Automatic structure:
;;     ~/Org/Journal/YYYY/MM/week-XX.org
;; - Daily headings auto-created
;; ============================================================


;; ============================================================
;; 🔧 BASIC SETUP
;; ============================================================

(use-package! toc-org
  :hook (org-mode . toc-org-mode))

(require 'org)
(require 'org-capture)
(require 'subr-x)


;; ============================================================
;; 📁 JOURNAL FILE STRUCTURE
;;
;; Format:
;;   ~/Org/Journal/YYYY/MM/week-XX.org
;; ============================================================

(setq org-directory "~/Documents/Org/")

(defun my/journal--week-file ()
  "Return path of current week journal file, creating dirs if needed."
  (let* ((year (format-time-string "%Y"))
         (month (format-time-string "%m"))
         (week (format-time-string "%V"))
         (dir (expand-file-name (concat "Lab-Journal/" year "/" month) org-directory))
         (file (expand-file-name (format "week-%s.org" week) dir)))
    (unless (file-directory-p dir)
      (make-directory dir t))
    file))


(defun my/journal--ensure-file ()
  "Create weekly journal file if it doesn't exist."
  (let ((file (my/journal--week-file)))
    (unless (file-exists-p file)
      (with-temp-file file
        (insert (format "#+TITLE: Journal Week %s\n#+OPTIONS: toc:2\n\n* Table of Contents :TOC:\n\n"
                        (format-time-string "%V")))))
    file))


;; ============================================================
;; 📅 DAILY HEADING MANAGEMENT
;;
;; Each day is a top-level heading:
;;   * 2026-05-15
;; ============================================================

(defun my/journal--goto-day ()
  "Jump to today's heading or create it if missing."
  (let ((day (format-time-string "%Y-%m-%d")))
    (goto-char (point-min))
    (unless (re-search-forward (concat "^\\* " day) nil t)
      (goto-char (point-max))
      (insert (format "\n* %s\n" day)))
    (re-search-backward (concat "^\\* " day))))


;; ============================================================
;; ⚡ 1. FAST ENTRY (LOG STYLE)
;;
;; Key: SPC n j j
;; Behavior:
;; - Opens journal
;; - Appends timestamped line
;; ============================================================

(defun my/journal-add-entry ()
  "Fast journal entry (no capture, just append)."
  (interactive)
  (my/journal-open)
  (my/journal--goto-day)
  (goto-char (point-max))
  (insert (format "\n** [%s] \n" (format-time-string "%H:%M")))
  (save-buffer))


;; ============================================================
;; 📌 ORG-CAPTURE ENTRY (CONTEXTUAL)
;;
;; Key: SPC n j c
;; Uses same daily heading logic as fast entries.
;; ============================================================

(defun my/journal-capture-target ()
  "Target location for journal captures."
  (set-buffer (find-file-noselect (my/journal--ensure-file)))
  (my/journal--goto-day)
  (goto-char (point-max)))

(setq org-capture-templates
      `(
        ("j" "Journal capture (context)"
         plain
         (file+function
          my/journal--week-file
          my/journal-capture-target)
         "** [%<%H:%M>] \n %?\n  %a\n"
         :empty-lines 1)))

(defun my/journal-capture ()
  "Org-capture journal entry with context."
  (interactive)
  (org-capture nil "j"))


(defun my/journal-open ()
  "Open weekly journal and jump to today."
  (interactive)
  (find-file (my/journal--ensure-file))
  (my/journal--goto-day))

(after! org
  (defun my/refresh-agenda-files ()
    (setq org-agenda-files
          (directory-files-recursively org-directory "\\.org$")))
  (my/refresh-agenda-files)
  (add-hook 'org-agenda-mode-hook #'my/refresh-agenda-files))

(after! org
  (setq org-todo-keywords
        '((sequence
           "TODO(t)"
           "NEXT(n)"
           "WAIT(w)"
           "|"
           "DONE(d)"
           "CANCELLED(c)"))))


;; ============================================================
;; ⌨️ KEYBINDINGS (DOOM LEADER)
;;
;; Namespace:
;;   SPC n j
;; ============================================================
(after! org
    (map! :leader
        (:prefix ("n j" . "journal")
        :desc "Fast journal entry" "j" #'my/journal-add-entry
        :desc "Open journal" "o" #'my/journal-open
        :desc "Capture journal entry" "c" #'my/journal-capture)))


(let ((imagemagick-path "C:/Program Files/ImageMagick-7.1.2-Q16-HDRI")
      (ipython-path "C:/Users/Marcelo/AppData/Roaming/Python/Python310/Scripts"))
     (dolist (path (list imagemagick-path ipython-path))
     (add-to-list 'exec-path path)
     (setenv "PATH" (concat path ";" (getenv "PATH")))))


(after! org
  (require 'org-download)

  ;; Mostrar imágenes inline
  (setq org-startup-with-inline-images t)
  (setq org-image-actual-width '(400))
  (setq org-download-method 'directory)
  (setq org-download-heading-lvl nil)

  ;; --------------------------------------------------
  ;; Assets directory: .../Lab-Journal/YYYY/MM/Assets/DD/
  ;; --------------------------------------------------
  (defun my/org-download-dir ()
    "Assets/DD folder next to current journal file."
    (when buffer-file-name
      (let* ((base-dir (file-name-directory buffer-file-name))
             (day (format-time-string "Day_%d"))
             (assets-dir (expand-file-name (concat "Assets/" day) base-dir)))
        (unless (file-directory-p assets-dir)
          (make-directory assets-dir t))
        assets-dir)))

  ;; --------------------------------------------------
  ;; Paste image: captura manual con magick, inserta link
  ;; --------------------------------------------------
    (defun my/org-download-clipboard ()
    "Paste clipboard image into Assets/DD folder with custom name."
    (interactive)
    (let* ((dir (my/org-download-dir))
            (name (read-string "Image name: "))
            (safe-name
            (replace-regexp-in-string
            "[^a-zA-Z0-9_-]" "_" name))
            (filename
            (format "%s.png" safe-name))
            (filepath
            (expand-file-name filename dir))
            (width (string-to-number
                    (read-string "Width: " "400"))))
        (let ((result (call-process "magick" nil nil nil
                                    "convert" "clipboard:" filepath)))
        (if (and (= result 0) (file-exists-p filepath))
            (progn
                (insert (format "#+ATTR_ORG: :width %d\n[[file:%s]]\n"
                                width
                                (file-relative-name filepath
                                                    (file-name-directory buffer-file-name))))
                (org-display-inline-images))
            (message "Error: no se pudo guardar la imagen del clipboard")))))

    (defun my/org-copy-images-from-explorer ()
    "Copy image files from Explorer clipboard into Assets folder."
    (interactive)
    (let* ((dir (my/org-download-dir))
            (count (string-to-number
                    (string-trim
                    (shell-command-to-string
                    "powershell.exe -command \"(Get-Clipboard -Format FileDropList).Count\""))))
            (_ (unless (> count 0)
                (error "No hay archivos en el clipboard")))
            (sources (cl-loop for i from 0 below count
                            collect (string-trim
                                        (shell-command-to-string
                                        (format "powershell.exe -command \"(Get-Clipboard -Format FileDropList)[%d].FullName\"" i))))))
        (dolist (source sources)
        (when (file-exists-p source)
            (let* ((name (read-string
                        "Image name: "
                        (file-name-sans-extension
                        (file-name-nondirectory source))))
                (safe-name
                    (replace-regexp-in-string
                    "[^a-zA-Z0-9_-]" "_" name))
                (width (string-to-number
                        (read-string "Width: " "400")))
                (filepath (expand-file-name (format "%s.png" safe-name) dir)))
            (copy-file source filepath t)
            (insert (format "#+ATTR_ORG: :width %d\n[[file:%s]]\n"
                            width
                            (file-relative-name filepath
                                                (file-name-directory buffer-file-name)))))))
        (org-display-inline-images)))

  ;; --------------------------------------------------
  ;; Keybinding
  ;; --------------------------------------------------
  (map! :leader
        :desc "Paste clipboard image" "i p" #'my/org-download-clipboard
        :desc "Copy image/s from Explorer" "i f" #'my/org-copy-images-from-explorer))

;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.


(use-package! pyvenv
  :config
  (pyvenv-mode 1))


(after! python
  (setq python-shell-interpreter "ipython"
        python-shell-interpreter-args "-i --simple-prompt --no-color-info"))


(after! org
  (setq org-preview-latex-default-process 'dvisvgm))

;; (use-package! org-fragtog
;;   :after org
;;   :hook (org-mode . my/org-fragtog-setup))

;; (defun my/org-fragtog-setup ()
;;   (org-latex-preview '(16))
;;   (org-fragtog-mode 1))


;; Guardar sesión automáticamente
(after! desktop
  (setq desktop-auto-save-timeout 30)  ;; guarda cada 30 segundos
  (desktop-save-mode 1))

;; Historial de comandos
(use-package! savehist
  :init
  (setq savehist-additional-variables
        '(extended-command-history search-ring regexp-search-ring))
  (savehist-mode 1))

;; Archivos recientes — guardar periódicamente
(after! recentf
  (setq recentf-max-saved-items 100)
  (run-at-time nil (* 2 60) #'recentf-save-list))






;; ── Org-roam ───────────────────────────────────────
(after! org-roam
  (setq org-roam-directory "~/Documents/Org/"))

;; ── Citar + Org-cite ───────────────────────────────
(after! oc
  (setq org-cite-global-bibliography '("~/Documents/Org/references.bib")
        org-cite-insert-processor 'citar
        org-cite-follow-processor 'citar
        org-cite-activate-processor 'citar))

(use-package! citar
  :after oc
  :custom
  (citar-bibliography '("~/Documents/Org/references.bib"))
  (citar-notes-paths '("~/Documents/Org/Notes/References/"))
  (citar-library-paths '("C:/Users/Marcelo/Zotero/storage/"))
  (citar-file-open-function #'find-file))

;; ── Citar-org-roam ─────────────────────────────────
(after! citar-org-roam
  (setq citar-org-roam-notes-path "~/Documents/Org/Notes/References/")
  (setq citar-org-roam-note-title-template "${author} - ${title}")
  (setq citar-org-roam-capture-template
        '("n" "nota" plain
          ":PROPERTIES:\n:NOTER_DOCUMENT: ${file}\n:END:\n\n%?"
          :target (file+head "${citekey}.org"
                             "#+TITLE: ${author} - ${title}\n")
          :unnarrowed t)))

;; ── Org-noter ──────────────────────────────────────
(after! org-noter
  (setq org-noter-always-create-frame nil
        org-noter-hide-other-headings nil
        org-noter-notes-window-location 'other-window
        org-noter-supported-modes '(doc-view-mode pdf-view-mode)))
