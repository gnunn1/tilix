Tilix Release Notes
===================

1. Ensure `master` branch is up to date (`git pull`)

2. Manually write NEWS entries for Tilix in the same format as usual.

`git shortlog 1.9.4.. | grep -i -v trivial | grep -v Merge > NEWS.new`

```
Version 1.9.5
~~~~~~~~~~~~~~
Released: 2021-xx-xx

Notes:

Features:

Bugfixes:
```

3. Run `extract-strings.sh` script

4. Commit l10n changes to Git

5. Commit NEWS and other changes to Git, tag release:
```
git commit -a -m "Release version 1.9.5"
git tag -s -f -m "Release 1.9.5" 1.9.5 <gpg password>
git push --tags
git push
```

6. Make release for the new tag in GitHub

7. Do post-release version bump in `meson.build`, `source/gx/tilix/constants.d` and `RELEASE.md`

8. Commit trivial changes:
```
git commit -a -m "trivial: post release version bump"
git push
```
