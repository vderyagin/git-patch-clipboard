;;; -*- lexical-binding: t; -*-

(load (expand-file-name
       "test-helper"
       (file-name-directory (or load-file-name buffer-file-name))))

(ert-deftest git-patch-clipboard-test-copy-requires-magit-status ()
  (with-temp-buffer
    (should-error
     (git-patch-clipboard--ensure-magit-status)
     :type 'user-error)))

(ert-deftest git-patch-clipboard-test-unborn-repo-includes-untracked-file ()
  (git-patch-clipboard-test--with-repo
    (git-patch-clipboard-test--write-file default-directory "new.txt" "hello\n")
    (let ((patch (git-patch-clipboard--make-patch default-directory)))
      (should (string-match-p "new file mode 100644" patch))
      (should (string-match-p "\\+\\+\\+ new.txt" patch))
      (should (string-match-p "\\+hello" patch))
      (should-not (string-match-p "\\+\\+\\+ b/new.txt" patch)))))

(ert-deftest git-patch-clipboard-test-repo-with-head-includes-tracked-and-untracked ()
  (git-patch-clipboard-test--with-repo
    (git-patch-clipboard-test--write-file default-directory "tracked.txt" "before\n")
    (git-patch-clipboard-test--commit-all default-directory "Initial")
    (git-patch-clipboard-test--write-file default-directory "tracked.txt" "after\n")
    (git-patch-clipboard-test--write-file default-directory "untracked.txt" "new\n")
    (let ((patch (git-patch-clipboard--make-patch default-directory)))
      (should (string-match-p "--- tracked.txt" patch))
      (should (string-match-p "\\+\\+\\+ tracked.txt" patch))
      (should (string-match-p "-before" patch))
      (should (string-match-p "\\+after" patch))
      (should (string-match-p "new file mode 100644" patch))
      (should (string-match-p "\\+\\+\\+ untracked.txt" patch)))))

(ert-deftest git-patch-clipboard-test-staged-patch-includes-index-only ()
  (git-patch-clipboard-test--with-repo
    (git-patch-clipboard-test--write-file default-directory "tracked.txt" "before\n")
    (git-patch-clipboard-test--commit-all default-directory "Initial")
    (git-patch-clipboard-test--write-file default-directory "tracked.txt" "staged\n")
    (git-patch-clipboard-test--git default-directory "add" "tracked.txt")
    (git-patch-clipboard-test--write-file default-directory "tracked.txt" "unstaged\n")
    (git-patch-clipboard-test--write-file default-directory "untracked.txt" "new\n")
    (let ((patch (git-patch-clipboard--make-staged-patch default-directory)))
      (should (string-match-p "--- tracked.txt" patch))
      (should (string-match-p "\\+\\+\\+ tracked.txt" patch))
      (should (string-match-p "-before" patch))
      (should (string-match-p "\\+staged" patch))
      (should-not (string-match-p "unstaged" patch))
      (should-not (string-match-p "untracked.txt" patch)))))

(ert-deftest git-patch-clipboard-test-copy-prefix-copies-staged-patch ()
  (git-patch-clipboard-test--with-repo
    (git-patch-clipboard-test--write-file default-directory "tracked.txt" "before\n")
    (git-patch-clipboard-test--commit-all default-directory "Initial")
    (git-patch-clipboard-test--write-file default-directory "tracked.txt" "staged\n")
    (git-patch-clipboard-test--git default-directory "add" "tracked.txt")
    (git-patch-clipboard-test--write-file default-directory "tracked.txt" "unstaged\n")
    (with-temp-buffer
      (magit-status-mode)
      (let ((default-directory default-directory)
            (copied nil))
        (cl-letf (((symbol-function 'kill-new)
                   (lambda (string &optional _replace)
                     (setq copied string)))
                  ((symbol-function 'gui-set-selection)
                   (lambda (&rest _args)
                     nil)))
          (git-patch-clipboard-copy t))
        (should (string-match-p "\\+staged" copied))
        (should-not (string-match-p "unstaged" copied))))))

(ert-deftest git-patch-clipboard-test-copy-prefix-fails-with-empty-index ()
  (git-patch-clipboard-test--with-repo
    (git-patch-clipboard-test--write-file default-directory "tracked.txt" "before\n")
    (git-patch-clipboard-test--commit-all default-directory "Initial")
    (git-patch-clipboard-test--write-file default-directory "tracked.txt" "unstaged\n")
    (with-temp-buffer
      (magit-status-mode)
      (let ((default-directory default-directory))
        (should-error
         (git-patch-clipboard-copy t)
         :type 'user-error)))))

(ert-deftest git-patch-clipboard-test-empty-repo-has-empty-patch ()
  (git-patch-clipboard-test--with-repo
    (should (string-empty-p
             (git-patch-clipboard--make-patch default-directory)))))

(ert-deftest git-patch-clipboard-test-apply-passes-section-args-and-patch-to-magit ()
  (with-temp-buffer
    (magit-status-mode)
    (let ((default-directory
           (file-name-as-directory
            (make-temp-file "git-patch-clipboard-test-apply-" t))))
      (unwind-protect
          (progn
            (git-patch-clipboard-test--git default-directory "init")
            (let ((captured nil)
                  (section 'fake-section))
              (cl-letf (((symbol-function 'git-patch-clipboard--clipboard-string)
                         (lambda () "diff --git tracked.txt tracked.txt\n"))
                        ((symbol-function 'magit-current-section)
                         (lambda () section))
                        ((symbol-function 'magit-apply-patch)
                         (lambda (actual-section actual-args actual-patch)
                           (setq captured
                                 (list actual-section
                                       actual-args
                                       actual-patch)))))
                (git-patch-clipboard-apply))
              (should (equal captured
                             (list section
                                   nil
                                   "diff --git tracked.txt tracked.txt\n")))))
        (delete-directory default-directory t)))))

;;; git-patch-clipboard-test.el ends here
