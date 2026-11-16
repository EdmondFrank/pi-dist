;;; agent-shell-pi-dist.el --- Wire agent-shell to this pi dist  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 pi-dist-build contributors
;; SPDX-License-Identifier: MIT

;;; Commentary:
;;
;; agent-shell already knows about pi: `agent-shell-pi-start-agent' (and the
;; "Pi" entry of the `agent-shell' picker) spawn `pi-acp', which install.sh
;; puts on PATH as ~/.local/bin/pi-acp. This file is optional; it only helps
;; when the shim is *not* on the PATH Emacs sees, or when pi's config lives
;; outside the default ~/.pi/agent.
;;
;; Load it after agent-shell:
;;
;;   (load "/path/to/pi-dist/config/agent-shell-pi-dist.el")
;;
;; Customize:
;;   M-x customize-group RET agent-shell-pi-dist
;;
;; The file is not installed into PI_CODING_AGENT_DIR: it configures Emacs,
;; nothing else.

;;; Code:

(require 'agent-shell)
(require 'agent-shell-pi)

(defgroup agent-shell-pi-dist nil
  "Integration between agent-shell and a pi-dist-build install."
  :group 'agent-shell)

(defcustom agent-shell-pi-dist-acp-shim nil
  "Absolute path to the pi-acp shim, or nil to search PATH.

install.sh writes the shim to `$PREFIX/bin/pi-acp' (by default
`~/.local/bin/pi-acp'). Set this only when GUI Emacs cannot see that
directory, since `executable-find' uses `exec-path', not the shell PATH."
  :type '(choice (const :tag "Search PATH" nil) file)
  :group 'agent-shell-pi-dist)

(defcustom agent-shell-pi-dist-agent-dir nil
  "Value for PI_CODING_AGENT_DIR, or nil to use pi's default.

Set this when the dist was installed with a non-default `--agent-dir'."
  :type '(choice (const :tag "pi default (~/.pi/agent)" nil) directory)
  :group 'agent-shell-pi-dist)

(defun agent-shell-pi-dist-apply ()
  "Point agent-shell's pi integration at this dist's adapter.
Idempotent; safe to call again after changing the options above."
  (interactive)
  (when agent-shell-pi-dist-acp-shim
    (setq agent-shell-pi-acp-command (list (expand-file-name agent-shell-pi-dist-acp-shim))))
  (when agent-shell-pi-dist-agent-dir
    (setq agent-shell-pi-environment
          (agent-shell-make-environment-variables
           "PI_CODING_AGENT_DIR" (expand-file-name agent-shell-pi-dist-agent-dir))))
  (unless (executable-find (car agent-shell-pi-acp-command))
    (display-warning 'agent-shell-pi-dist
                     (format "pi-acp not found (%s): install it with ./install.sh, or set `agent-shell-pi-dist-acp-shim'."
                             (car agent-shell-pi-acp-command))
                     :warning)))

(agent-shell-pi-dist-apply)

(provide 'agent-shell-pi-dist)
;;; agent-shell-pi-dist.el ends here