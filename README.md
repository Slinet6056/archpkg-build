# archpkg-build action

This action builds ArchLinux packages in a Docker container and optionally updates a package repository.

## Example usage

```yml
uses: Slinet6056/archpkg-build@master
with:
  package_name: pkg
  gpg_private_key: ${{ secrets.GPG_PRIVATE_KEY }}
  gpg_passphrase: ${{ secrets.GPG_PASSPHRASE }}
  pkgs_path: test # optional
  repo_name: test-repo # optional
  repo_path: repo # optional
```

## Inputs

- `package_name`: Name of the package to build (required)
- `gpg_private_key`: GPG private key for package signing (required)
- `gpg_passphrase`: Passphrase for the GPG private key (required)
- `pkgs_path`: Path to the directory containing package subdirectories (optional, default: ".")
- `repo_name`: Repository name (optional, for repository update)
- `repo_path`: Repository path (optional, for repository update)

## Tips

### Use matrix to build multiple packages

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

## How it works

1. The action uses a Docker container based on the `archlinux:base-devel` image.
2. It sets up a build environment and creates a non-root user for building packages.
3. The specified package is built using `makepkg`.
4. The built package is signed using the provided GPG key.
5. If `repo_name` and `repo_path` are provided, the action updates the package repository.

## Notes

- Ensure that your repository contains subdirectories named after each `package_name` within the `pkgs_path` (default: "."). Each subdirectory should contain the necessary `PKGBUILD` file.
- The GPG private key and passphrase should be stored as secrets in your GitHub repository.
- When updating a repository, the `repo_path` will be automatically created if it doesn't exist.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
