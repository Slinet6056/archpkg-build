# archpkg-build action

## Example usage

```yml
uses: Slinet6056/archpkg-build@master
with:
  package_name: pkg
  gpg_private_key: ${{ secrets.GPG_PRIVATE_KEY }}
  gpg_passphrase: ${{ secrets.GPG_PASSPHRASE }}
  pkgs_directory: test # optional
```

## Tips

### use matrix to build multi pkgs

```yml
strategy:
  matrix:
    pkgs: [pkg1, pkg2]

steps:
  - uses: Slinet6056/archpkg-build@master
    with:
      package_name: ${{ matrix.pkgs }}
      gpg_private_key: ${{ secrets.GPG_PRIVATE_KEY }}
      gpg_passphrase: ${{ secrets.GPG_PASSPHRASE }}
```
