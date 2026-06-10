;;; -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'ert)

(add-to-list 'load-path
             (expand-file-name ".." (file-name-directory load-file-name)))

(require 'magit)
(require 'git-patch-clipboard)

(defun git-patch-clipboard-test--git (repo &rest args)
  "Run Git in REPO with ARGS."
  (let ((default-directory repo))
    (with-temp-buffer
      (let ((status (apply #'process-file "git" nil t nil args)))
        (unless (zerop status)
          (error "Git failed: git %s\n%s"
                 (string-join args " ")
                 (buffer-string))))
      (buffer-string))))

(defmacro git-patch-clipboard-test--with-repo (&rest body)
  "Run BODY in a temporary Git repository."
  (declare (indent 0))
  `(let ((repo (file-name-as-directory
                (make-temp-file "git-patch-clipboard-test-" t))))
     (unwind-protect
         (let ((default-directory repo))
           (git-patch-clipboard-test--git repo "init")
           ,@body)
       (delete-directory repo t))))

(defun git-patch-clipboard-test--write-file (repo file contents)
  "Write CONTENTS to FILE under REPO."
  (let ((path (expand-file-name file repo)))
    (make-directory (file-name-directory path) t)
    (with-temp-file path
      (insert contents))))

(defun git-patch-clipboard-test--commit-all (repo message)
  "Commit all current changes in REPO with MESSAGE."
  (git-patch-clipboard-test--git repo "add" "-A")
  (git-patch-clipboard-test--git
   repo
   "-c" "user.name=Test User"
   "-c" "user.email=test@example.invalid"
   "-c" "commit.gpgsign=false"
   "commit" "-m" message))

(provide 'test-helper)

;;; test-helper.el ends here
