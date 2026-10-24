# git-patch-clipboard

Copy all uncommitted changes from a Magit status buffer to the clipboard as a Git patch, then apply a clipboard patch back through Magit.

## Compatibility

- Git

Development and CI currently use Emacs 31.1 and Magit 4.5.0.  The
package does not intentionally depend on those exact versions, and may
work with older Emacs and Magit releases.

## Commands

- `git-patch-clipboard-copy`
  Copies a patch for all uncommitted changes in the current repository. This includes staged changes, unstaged changes, deletions, and untracked files.
  With a prefix argument, copies only staged changes and fails if the index is empty.

- `git-patch-clipboard-apply`
  Reads a patch from the clipboard and applies it with `magit-apply-patch`.

Both commands are intentionally only supported from `magit-status-mode` buffers.

## Development

Install dependencies:

```sh
just install-deps
```

Compile:

```sh
just build
```

Run tests:

```sh
just test
```
