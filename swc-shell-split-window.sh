#!/bin/bash
#
# Create terminal for Software Carpentry lesson
# with the log of the commands at the top.

# Where we'll store the executed history.  Defaults to /tmp/log-file,
# but you can override from the calling process.  For example:
#
#   LOG_FILE=/tmp/my-log ./swc-shell-split-window.sh
LOG_FILE="${LOG_FILE:-/tmp/${USER}-swc-split-log-file}"

# What percentage of the window the log pane on the right-hand-side takes up.
LOG_PANE_PERCENT="${LOG_PANE_PERCENT:-25}"

# Session name.  Defaults to 'swc', but you can override from the
# calling process.
SESSION="${SESSION:-swc}"

# If $LOG_FILE exists, truncate it, otherwise create it.
# Either way, this leaves us with an empty $LOG_FILE for tailing.
> "${LOG_FILE}"

# Create the session to be used
# * don't attach yet (-d)
# * name it $SESSION (-s "${SESSION}")
# * start reading the log
# * get rid of these errors:
#   * tail: inotify resources exhausted
#   * tail: inotify cannot be used, reverting to polling
# * ignore lines starting with '#' since they are the history file's internal
#   timestamps
cmd="tail -f '${LOG_FILE}' 2> /dev/null | grep -v '^#'"
tmux new-session -d -s "${SESSION}" "${cmd}"

# Get the unique (and permanent) ID for the new window
WINDOW=$(tmux list-windows -F '#{window_id}' -t "${SESSION}")

# Get the unique (and permanent) ID for the log pane
LOG_PANE=$(tmux list-panes -F '#{pane_id}' -t "${WINDOW}")
LOG_PID=$(tmux list-panes -F '#{pane_pid}' -t "${WINDOW}")

# Split the log-pane (-t "${LOG_PANE}") vertically (-v)
# * make the new pane the current pane (no -d)
# * load history from the empty $LOG_FILE (HISTFILE='${LOG_FILE}')
# * lines which begin with a space character are not saved in the
#   history list (HISTCONTROL=ignorespace)
# * append new history to $HISTFILE after each command
#   (PROMPT_COMMAND='history -a')
# * launch Bash since POSIX doesn't specify shell history or HISTFILE
#   (bash)
# * when the Bash process exits, kill the log process
cmd="HISTFILE='${LOG_FILE}'"
cmd="${cmd} HISTCONTROL=ignorespace"
cmd="${cmd} PROMPT_COMMAND='history -a'"
cmd="${cmd} bash; kill '${LOG_PID}'"
tmux split-window -h -t "${LOG_PANE}" "${cmd}"

# Get the unique (and permanent) ID for the shell pane
SHELL_PANE=$(tmux list-panes -F '#{pane_id}' -t "${WINDOW}" |
	grep -v "^${LOG_PANE}\$")

# Start in the user's home directory.
tmux send-keys -t "${SHELL_PANE}" " cd" enter

# If the user's .bashrc defines PROMPT_COMMAND, append 'history -a' to turn on
# the logging.
tmux send-keys -t "${SHELL_PANE}" \
  ' if [[ "${PROMPT_COMMAND}" != "history -a" ]]; then
      PROMPT_COMMAND="${PROMPT_COMMAND};
      history -a";
    fi' enter

sleep 0.1

# Clear the history so it starts over at number 1.
# The script shouldn't run any more non-shell commands in the shell
# pane after this.
tmux send-keys -t "${SHELL_PANE}" "history -c" enter

# Send Bash the clear-screen command (see clear-screen in bash(1))
tmux send-keys -t "${SHELL_PANE}" "C-l"

# Wait for Bash to act on the clear-screen.  We need to push the
# earlier commands into tmux's scrollback before we can ask tmux to
# clear them out.
sleep 0.1

# Clear tmux's scrollback buffer so it matches Bash's just-cleared
# history.
tmux clear-history -t "${SHELL_PANE}"

# Swap the panes such that the shell pane is on the left and the log pane is
# on the right.
tmux swap-pane -s "${LOG_PANE}" -t "${SHELL_PANE}"

# Resize the log pane such that it (ideally) doesn't take up as much horizontal
# space.
tmux resize-pane -t "${LOG_PANE}" \
  -x "$((${LOG_PANE_PERCENT} * $(tput cols) / 100))"

# Turn off tmux's status bar, because learners won't have one in their
# terminal.
# * don't print output to the terminal (-q)
# * set this option at the window level (-w).  I'd like new windows in
#   this session to get status bars, but it doesn't seem like there
#   are per-window settings for 'status'.  In any case, the -w doesn't
#   seem to cause any harm.
tmux set-option -t "${WINDOW}" -q -w status off

tmux attach-session -t "${SESSION}"
