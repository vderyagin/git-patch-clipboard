;;; git-patch-clipboard.el --- Copy and apply Git patches via clipboard -*- lexical-binding: t; -*-

;; Author: Victor Deryagin <vderyagin@gmail.com>
;; Maintainer: Victor Deryagin <vderyagin@gmail.com>
;; Created: 10 Jun 2026
;; Version: 0.1.0
;; Package-Requires: ((magit "4.0.0"))

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Commands for copying all uncommitted Git repository changes to the
;; clipboard and applying a clipboard patch from a Magit status buffer.

;;; Code:

(require 'magit)
(require 'seq)
(require 'subr-x)

(defun git-patch-clipboard--ensure-magit-status ()
  "Return the current repository root, or signal an error.

This package intentionally only supports invocation from
`magit-status-mode' buffers."
  (unless (derived-mode-p 'magit-status-mode)
    (user-error "This command must be invoked from a Magit status buffer"))
  (or (magit-toplevel)
      (user-error "Could not determine Git repository root")))

(defun git-patch-clipboard--run-git-with-statuses (repo allowed-statuses &rest args)
  "Run Git in REPO with ARGS and return standard output.

Signal an error unless Git exits with one of ALLOWED-STATUSES."
  (let ((default-directory repo)
        (stdout (generate-new-buffer " *git-patch-clipboard stdout*"))
        (stderr-file (make-temp-file "git-patch-clipboard-stderr-")))
    (unwind-protect
        (let ((status (apply #'process-file "git" nil (list stdout stderr-file) nil args)))
          (unless (member status allowed-statuses)
            (error "Git failed: git %s\n%s"
                   (string-join args " ")
                   (string-trim
                    (with-temp-buffer
                      (insert-file-contents stderr-file)
                      (buffer-string)))))
          (with-current-buffer stdout
            (buffer-string)))
      (kill-buffer stdout)
      (when (file-exists-p stderr-file)
        (delete-file stderr-file)))))

(defun git-patch-clipboard--run-git (repo &rest args)
  "Run Git in REPO with ARGS and return standard output.

Signal an error if Git exits unsuccessfully."
  (apply #'git-patch-clipboard--run-git-with-statuses repo '(0) args))

(defun git-patch-clipboard--repo-has-head-p (repo)
  "Return non-nil if REPO has a HEAD commit."
  (let ((default-directory repo))
    (zerop (process-file "git" nil nil nil "rev-parse" "--verify" "HEAD"))))

(defun git-patch-clipboard--clipboard-string ()
  "Return clipboard contents as a string, or nil if unavailable."
  (or (when (fboundp 'gui-get-selection)
        (condition-case nil
            (gui-get-selection 'CLIPBOARD 'UTF8_STRING)
          (error nil)))
      (condition-case nil
          (current-kill 0 t)
        (error nil))))

(defun git-patch-clipboard--split-nul (string)
  "Split nul-delimited STRING into a list of nonempty strings."
  (split-string string "\0" t))

(defun git-patch-clipboard--existing-repo-path-p (repo file)
  "Return non-nil if FILE exists in REPO, including symlinks."
  (let ((path (expand-file-name file repo)))
    (or (file-exists-p path)
        (file-symlink-p path))))

(defun git-patch-clipboard--new-file-patches (repo files)
  "Return new-file patches for FILES in REPO."
  (mapconcat
   (lambda (file)
     (git-patch-clipboard--run-git-with-statuses
      repo '(0 1)
      "diff" "--no-index" "--no-prefix" "--binary" "--no-ext-diff" "--no-color"
      "--" "/dev/null" file))
   (seq-filter (lambda (file)
                 (git-patch-clipboard--existing-repo-path-p repo file))
               files)
   ""))

(defun git-patch-clipboard--make-patch (repo)
  "Return a patch containing all uncommitted changes in REPO.

The patch includes staged changes, unstaged changes, deletions, and
untracked files.  The repository index is not modified."
  (if (git-patch-clipboard--repo-has-head-p repo)
      (string-join
       (list
        (git-patch-clipboard--run-git
         repo "diff" "--no-prefix" "--binary" "--no-ext-diff" "--no-color"
         "HEAD" "--")
        (git-patch-clipboard--new-file-patches
         repo
         (git-patch-clipboard--split-nul
          (git-patch-clipboard--run-git
           repo "ls-files" "--others" "--exclude-standard" "-z"))))
       "")
    (git-patch-clipboard--new-file-patches
     repo
     (git-patch-clipboard--split-nul
      (git-patch-clipboard--run-git
       repo "ls-files" "--cached" "--others" "--exclude-standard" "-z")))))

(defun git-patch-clipboard--make-staged-patch (repo)
  "Return a patch containing staged changes in REPO."
  (git-patch-clipboard--run-git
   repo "diff" "--cached" "--no-prefix" "--binary" "--no-ext-diff" "--no-color"
   "--"))

;;;###autoload
(defun git-patch-clipboard-copy (&optional staged-only)
  "Copy a patch for all uncommitted changes to the clipboard.

With prefix argument STAGED-ONLY, copy only staged changes.

This command must be invoked from a `magit-status-mode' buffer."
  (interactive "P")
  (let* ((repo (git-patch-clipboard--ensure-magit-status))
         (patch (if staged-only
                    (git-patch-clipboard--make-staged-patch repo)
                  (git-patch-clipboard--make-patch repo))))
    (when (string-empty-p patch)
      (if staged-only
          (user-error "There are no staged changes to copy")
        (user-error "There are no uncommitted changes to copy")))
    (kill-new patch)
    (when (fboundp 'gui-set-selection)
      (condition-case nil
          (gui-set-selection 'CLIPBOARD patch)
        (error nil)))
    (message "Copied %spatch to clipboard"
             (if staged-only "staged " ""))))

;;;###autoload
(defun git-patch-clipboard-apply ()
  "Apply a patch from the clipboard using `magit-apply-patch'.

This command must be invoked from a `magit-status-mode' buffer."
  (interactive)
  (let* ((repo (git-patch-clipboard--ensure-magit-status))
         (patch (or (git-patch-clipboard--clipboard-string)
                    (user-error "Clipboard does not contain a patch"))))
    (when (string-empty-p (string-trim patch))
      (user-error "Clipboard does not contain a patch"))
    (let ((default-directory repo))
      (magit-apply-patch
       (or (magit-current-section)
           (user-error "Could not determine current Magit section"))
       nil
       patch))))

(provide 'git-patch-clipboard)

;;; git-patch-clipboard.el ends here
