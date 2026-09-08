//go:build windows
// +build windows

package main

import "os/exec"

// job objects would be needed to group processes here, so this is a no-op
func setProcessGroup(cmd *exec.Cmd) {
}

// only the direct child is killed: a descendant of it may survive the timeout.
// The caller closes the stdout pipe as well, so the copy is unblocked anyway.
func killProcessTree(cmd *exec.Cmd) {
	if cmd.Process == nil {
		return
	}
	cmd.Process.Kill()
}
