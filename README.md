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

## How it works

1. The action uses a Docker container based on the `archlinux:base-devel` image.
2. It sets up a build environment and creates a non-root user for building packages and signing them.
3. The specified package is built using `pikaur`.
4. The built package is signed using the provided GPG key.
5. If `repo_name` and `repo_path` are provided, the action updates the package repository.

## Outputs

After running this action, you can expect the following results:

1. The built package (`.pkg.tar.zst`) and its signature (`.pkg.tar.zst.sig`) will be available in the package's build directory.
2. If `repo_name` and `repo_path` are provided, the package repository will be updated with the new package. The updated repository, including the new package file, its signature, and the updated database files, will be available in the specified `repo_path`.

These outputs can be utilized in subsequent steps of your workflow for various purposes.

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

## Notes

- Ensure that your repository contains subdirectories named after each `package_name` within the `pkgs_path` (default: "."). Each subdirectory should contain the necessary `PKGBUILD` file.
- Store the complete GPG private key (including header and footer) and passphrase as separate secrets in your GitHub repository.
- When updating a repository, the `repo_path` will be automatically created if it doesn't exist.
- Automatic repository update may cause conflicts when using matrix strategy. To resolve this issue, you can use the [Matrix Lock](https://github.com/marketplace/actions/matrix-lock) action. This action allows you to control the execution order of jobs, preventing conflicts during repository updates. For a specific implementation example, please refer to [this workflow file](https://github.com/Slinet6056/AUR/blob/master/.github/workflows/build.yml).

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
