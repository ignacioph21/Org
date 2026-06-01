;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; (add-hook 'window-setup-hook #'toggle-frame-fullscreen) ;; Se abre ocupando toda la pantalla.
;; (set-frame-parameter nil 'fullscreen 'maximized)
(add-to-list 'initial-frame-alist '(fullscreen . maximized)) ;; Esto funciona para el Emacs, pero se ignora para el cliente con Daemon.

(setenv "PATH" (concat (expand-file-name "~/bin") ":" (getenv "PATH")))
(add-to-list 'exec-path (expand-file-name "~/bin"))

(setenv "PATH" (concat (getenv "PATH") path-separator (expand-file-name "~/.local/bin")))
(add-to-list 'exec-path (expand-file-name "~/.local/bin"))

(setq doom-theme 'doom-one)

(setq display-line-numbers-type t)

(setq org-directory "~/Org/")

(after! org
  (setq org-todo-keywords
        '((sequence
           "TODO(t)"
           "NEXT(n)"
           "WAIT(w)"
           "|"
           "DONE(d)"
           "CANCELLED(c)"))))

(after! org
  (defun my/refresh-agenda-files ()
    (setq org-agenda-files
          (directory-files-recursively org-directory "\\.org$")))
  (my/refresh-agenda-files)
  (add-hook 'org-agenda-mode-hook #'my/refresh-agenda-files))

(defun my/journal--week-file ()
  (let* ((year (format-time-string "%Y"))
         (month (format-time-string "%m"))
         (week (format-time-string "%V"))
         (dir (expand-file-name (concat "Lab-Journal/" year "/" month) org-directory))
         (file (expand-file-name (format "week-%s.org" week) dir)))
    (unless (file-directory-p dir)
      (make-directory dir t))
    file))

(defun my/journal--ensure-file ()
  (let ((file (my/journal--week-file)))
    (unless (file-exists-p file)
      (with-temp-file file
        (insert (format "#+TITLE: Journal Week %s\n#+OPTIONS: toc:2\n#+BIBLIOGRAPHY: ../../../references.bib\n#+CITE_EXPORT: csl chicago-author-date.csl\n\n* Table of Contents :TOC:noexport:\n\n* Referencias\n#+PRINT_BIBLIOGRAPHY:\n"
                        (format-time-string "%V")))))
    file))

(defun my/journal--goto-day ()
  (let ((day (format-time-string "%Y-%m-%d")))
    (goto-char (point-min))
    (unless (re-search-forward (concat "^\\* " day) nil t)
      (goto-char (point-max))
      (insert (format "\n* %s\n" day)))
    (re-search-backward (concat "^\\* " day))))

(defun my/journal-add-entry ()
  (interactive)
  (my/journal-open)
  (my/journal--goto-day)
  (goto-char (point-max))
  (insert (format "\n** [%s] \n" (format-time-string "%H:%M")))
  (save-buffer))

(defun my/journal-capture-target ()
  "Target location for journal captures."
  (set-buffer (find-file-noselect (my/journal--ensure-file)))
  (my/journal--goto-day)
  (goto-char (point-max)))

(after! org
  (setq org-capture-templates
        (append
         (cl-remove-if (lambda (x) (equal (car x) "j"))
                       org-capture-templates)
         '(("j" "Journal capture (context)"
            plain
            (file+function
             my/journal--week-file
             my/journal-capture-target)
            "** [%<%H:%M>] \n %?\n  %a\n"
            :empty-lines 1)))))

(defun my/journal-capture ()
  "Org-capture journal entry with context."
  (interactive)
  (org-capture nil "j"))

(defun my/journal-open ()
  "Open weekly journal and jump to today."
  (interactive)
  (find-file (my/journal--ensure-file))
  (my/journal--goto-day))

(defun my/journal-sync ()
  (interactive)
  (let ((default-directory org-directory))
    (async-shell-command
     "git add . && git diff --cached --quiet || git commit -m \"Auto commit of Lab-Journal\" && git push")))

(after! org
    (map! :leader
        (:prefix ("n j" . "journal")
        :desc "Fast journal entry" "j" #'my/journal-add-entry
        :desc "Open journal" "o" #'my/journal-open
        :desc "Capture journal entry" "c" #'my/journal-capture
        :desc "Journal sync" "g" #'my/journal-sync)))

(setq org-startup-with-inline-images t)

(setq org-image-actual-width '(500))

(after! org
  (defun my/org-download-dir ()
  (let ((dir (expand-file-name
              (format-time-string "%Y/%m/Day_%d")
              (expand-file-name "Assets" org-directory))))
      (make-directory dir t)
      dir)))

(after! org
  (defun my/org-download-clipboard ()
    "Paste clipboard image into Assets folder with custom name."
    (interactive)
    (let* ((dir (my/org-download-dir))
            (name (read-string "Image name: "))
            (safe-name
            (replace-regexp-in-string
            "[^a-zA-Z0-9_-]" "_" name))
            (filepath (expand-file-name (format "%s.png" safe-name) dir))
            (width (string-to-number
                    (read-string "Width: " "500")))
            (result (call-process "xclip" nil `(:file ,filepath) nil
                                "-selection" "clipboard"
                                "-t" "image/png"
                                "-o")))
        (if (and (= result 0) (file-exists-p filepath))
            (progn
            (insert (format "#+ATTR_ORG: :width %d\n[[file:%s]]\n"
                            width
                            (file-relative-name filepath
                                                (file-name-directory buffer-file-name))))
            (org-display-inline-images))
        (message "Error: no se pudo guardar la imagen del clipboard")))))

(after! org
  (defun my/org-copy-images-from-files ()
    "Copy image files from file manager clipboard into Assets folder."
    (interactive)
    (let* ((dir (my/org-download-dir))
           (raw (shell-command-to-string
                 "xclip -selection clipboard -t text/uri-list -o"))
           (uris (cl-remove-if #'string-empty-p
                               (split-string (string-trim raw) "\n")))
           (_ (unless uris
                (error "No hay archivos en el clipboard")))
           (sources (mapcar (lambda (uri)
                              (string-remove-prefix "file://" uri))
                            uris)))
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
                         (read-string "Width: " "500")))
                 (filepath (expand-file-name
                            (format "%s.png" safe-name) dir)))
            (copy-file source filepath t)
            (insert (format "#+ATTR_ORG: :width %d\n[[file:%s]]\n"
                            width
                            (file-relative-name
                             filepath
                             (file-name-directory buffer-file-name)))))))
      (org-display-inline-images))))

(map! :leader
    :desc "Paste clipboard image"  "i p" #'my/org-download-clipboard
    :desc "Copy images from files" "i f" #'my/org-copy-images-from-files)

(after! org
  (setq org-preview-latex-default-process 'dvipng))

;; (use-package! org-fragtog
;;    :after org
;;    :hook (org-mode . my/org-fragtog-setup))

;;  (defun my/org-fragtog-setup ()
;;    (org-latex-preview '(16))
;;    (org-fragtog-mode 1))

(after! org
  (setq org-export-with-broken-links t))

(after! org
  (require 'ox-publish)
  (setq org-publish-project-alist
        '(
          ("lab-journal"
           :base-directory "~/Org/Lab-Journal/"
           :base-extension "org"
           :publishing-directory "~/Org/Lab-Journal-html/"
           :recursive t
           :publishing-function org-html-publish-to-html
           :with-author nil
           :with-creator nil
           :with-toc t
           :section-numbers nil
           :time-stamp-file nil
           :html-head-include-default-style nil
           :html-head-include-scripts nil
           :html-head "<link rel='stylesheet' href='../../../style.css' />
<script defer src='../../../script.js'></script>"
           :auto-sitemap t
           :sitemap-filename "index.org"
           :sitemap-title "Lab Journal"
           :sitemap-style list
           :sitemap-sort-files anti-chronologically))))

(after! org
  (defun my/lab-journal-generate-index ()
    "Genera search-index.json en el root del repo."
    (let* ((docs-dir (expand-file-name "~/Org/Lab-Journal-html/"))
           (output-file (expand-file-name "~/Org/search-index.json"))
           (files (directory-files-recursively docs-dir "\\.html$"))
           (entries
            (delq nil
                  (mapcar
                   (lambda (file)
                     (let* ((rel (file-relative-name file (expand-file-name "~/Org/")))
                            (parts (split-string rel "/"))
                            (year  (and (>= (length parts) 4) (nth 1 parts)))
                            (month (and (>= (length parts) 4) (nth 2 parts)))
                            (name  (file-name-sans-extension (file-name-nondirectory file)))
                            (title (replace-regexp-in-string "[-_]" " " name)))
                       (when (and year month
                                  (not (string= name "index")))
                         (format "{\"title\":\"%s\",\"url\":\"%s\",\"year\":\"%s\",\"month\":\"%s\"}"
                                 title rel year month))))
                   files))))
      (with-temp-file output-file
        (insert "[" (mapconcat #'identity entries ",") "]"))))

(after! org
  (require 'oc-csl)
  (setq org-cite-global-bibliography '("~/Org/references.bib"))
  (setq org-cite-export-processors
        '((html . (csl "chicago-author-date.csl"))
          (t    . (csl "chicago-author-date.csl"))))
  (setq org-cite-csl-styles-dir "~/Zotero/styles/"))

(defun my/lab-journal-export-and-push ()
  (interactive)
  (save-some-buffers t)
  (org-publish "lab-journal")
  (my/lab-journal-generate-index)
  (async-shell-command
   (concat
    "cd " (expand-file-name org-directory) " && "
    "npx pagefind --site Lab-Journal-html --output-path Lab-Journal-html/pagefind && "
    "git add . && "
    "git diff --cached --quiet || "
    "(git commit -m \"Auto export for the Lab Journal.\" && git push)")))

(defun my/lab-journal-full-rebuild ()
  (interactive)
  (org-publish-remove-all-timestamps)
  (org-publish "lab-journal" t)
  (my/lab-journal-generate-index)
  (async-shell-command
   (concat
    "cd " (expand-file-name org-directory) " && "
    "npx pagefind --site Lab-Journal-html --output-path Lab-Journal-html/pagefind")))

(map! :leader
        :prefix ("n j" . "journal")
        :desc "Export Lab Journal"
        "p" #'my/lab-journal-export-and-push
        :desc "Full rebuild Lab Journal"
        "R" #'my/lab-journal-full-rebuild))

(setq org-roam-directory "~/Org")

(after! org-noter
  (setq org-noter-notes-search-path '("~/Org/Notes/References")
        org-noter-auto-save-last-location t
        org-noter-doc-split-fraction '(0.6 . 0.4)  ; PDF izquierda, notas derecha
        org-noter-always-create-frame nil
        org-noter-kill-frame-at-session-end nil))

(after! citar
  (setq citar-bibliography '("~/Org/references.bib")) ;; Tu .bib exportado por Zotero
  (setq citar-library-paths '("~/Zotero/storage")) ;; Donde Zotero guarda los PDFs
  (setq citar-notes-paths '("~/Org/Notes/References")) ;; Donde se crearán/guardarán las notas de org-noter
  (setq citar-file-note-org-include '(org-id org-noter-document-property))) ;; Formato del nombre del archivo de nota

(after! (citar org-noter)
  ;; Función que crea la nota con el template correcto para org-noter
  (defun my/citar-open-noter (citekey)
    "Abre o crea una nota org-noter para CITEKEY."
    (let* ((entry (citar-get-entry citekey))
           (title (citar-get-value "title" entry))
           (file  (expand-file-name
                   (concat citekey ".org")
                   "~/Org/Notes/References"))
           (pdf   (car (citar-get-files citekey))))
      (find-file file)
      (when (= (buffer-size) 0)
        ;; Crea el archivo con el header de org-noter si no existe
        (insert (format "#+title: %s\n#+author: \n\n* %s\n:PROPERTIES:\n:NOTER_DOCUMENT: %s\n:END:\n\n"
                        title title (or pdf ""))))
      (org-noter)))

  ;; Reemplaza la acción de "abrir nota" en citar por la nuestra
  (setq citar-open-note-function #'my/citar-open-noter))

(after! citar
  (setq completion-ignore-case t))

(after! pdf-tools
  (setq-default pdf-view-display-size 'fit-page))

(use-package! pyvenv
  :config
  (pyvenv-mode 1)
  (unless pyvenv-virtual-env (pyvenv-activate (expand-file-name "~/.venv"))))

(after! python
  (setq python-shell-interpreter "ipython"
        python-shell-interpreter-args "-i --simple-prompt"))

;; (set-language-environment "UTF-8")
;; (prefer-coding-system 'utf-8)

;; (set-default-coding-systems 'utf-8)
;; (set-terminal-coding-system 'utf-8)
;; (set-keyboard-coding-system 'utf-8)
;; (set-selection-coding-system 'utf-8)

;; (setenv "PYTHONUTF8" "1")
;; (setenv "IPYTHONIOENCODING" "utf-8")
