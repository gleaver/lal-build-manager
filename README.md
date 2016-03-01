# lal dependency manager
A dependency manager for C++ following LAL conventions.

## Design
`lal` is a simple command line tool that works on folders with a valid `manifest.json`, and accepts the following commands:

- [`lal install`](#lal-install-components) - install dependencies from `manifest.json` into `INPUT`
- [`lal status`](#lal-status) - print current installed dependencies with origin
- [`lal build [name]`](#lal-build-name) - run canonical build in current directory
- [`lal shell`](#lal-shell) - enter container environment mounting `$PWD`
- [`lal stash name`](#lal-stash-name) - copies current `OUTPUT` to cache
- `lal update-manifest`
- [`lal verify`](#lal-verify) - verify manifest validity + verify flat lockfile dependency tree

## Manifest
A per-repo file. Format looks like this (here annotated with illegal comments):

```json
{
  "name": "libwebsockets",  // name of repo
  "version": 10,            // corresponds to latest tag
  "components": ["$1"],     // list of components (used if more than one)
  "scripts": {              // canonical build + test scripts for repo
    "build": "./BUILD $1 $2",
    "test": "./BUILD $1-unit-tests $2"
  },
  "dependencies": {
    "ciscossl": 42
  },
  "devDependencies": {
    "gtest": 42
  }
}
```

## Lockfile
A per-build file auto-generated by `lal build` and will reduce the lockfiles generated from dependencies to provide aggregated information.

```json
{
  "name": "monolith",
  "date": "datestring",
  "commit": "sha",
  "container": {
    "name": "edonusdevelopers/centos_build",
    "version": "sha"
  },
  "dependencies": {
    "ciscossl": {
      "target": "ncp.amd64",
      "version": 6,
      "order": "global"
    },
    "libwebsockets": {
      "target": "ncp.amd64",
      "version": 5,
      "order": "global",
      "dependencies": {
        "ciscossl": {
          "target": "ncp.amd64",
          "version": 6,
          "order": "global"
        }
      }
    }
  },
  "dev": {
    "gtest": {
      "version": 42
    }
  }
}
```

## .lalrc
Per machine configuration file from `lal configure`.

```json
{
  "target": "ncp.amd64",
  "container": "edonusdevelopers/centos_build",
  "cache": "~/.lal/cache",
  "registry": "https://artifactory.wherever"
}
```

## Installation
Install [stable rust](https://www.rust-lang.org/downloads.html) (inlined below), clone and install.

```sh
curl -sSf https://static.rust-lang.org/rustup.sh | sh
#clone && cd lal
cargo build
cargo install
export PATH=$HOME/.cargo/bin:$PATH
lal configure
```

## Developing
You can avoid doing the install step everytime by just:

```sh
cargo build
./lal subcommand
```

`./lal` is a symlink to the current build (when installed it will be avilable on `PATH`). To see what commands are implemented run `./lal -h`.

Formatting

```sh
cargo fmt # requires cargo install rustfmt and .cargo/bin on PATH
```

## Updating
TODO: At some point `lal` will version check itself and let you know of a new version, and the command to update it. It can also give indications of docker container updates.

## Caching
The local cache is populated when doing installs from the registry, when building locally and stashing them, or when linking them directly.

```sh
~/.lal/cache $ tree -aC  --dirsfirst .
.
├── globals
│   └── ncp.amd64
│       └── ciscossl
│           └── 6
│               ├── ciscossl.tar.gz
│               └── lockfile.json
└── stash
    └── ncp.amd64
        └── ciscossl
            └── asan
                ├── ciscossl.tar.gz
                └── lockfile.json
```

Sources:

- `globals` are unpacked straight from the registry
- `stash` are tarballs of OUTPUT of builds when doing `lal stash <name>`


### Common Command Specification
#### lal status
Provides list of dependencies currently installed.
If they are not in the manifest they will be listed as _extraneous_.
If they are modified (not a global fetch) they will be listed as _modified_.

#### lal build [name]
Runs the `scripts.build` shell script in the manifest file inside the configured container.

E.g. `"build": "./BUILD $1 $2"` key in the manifest under `scripts` will cause `lal build dme` to run `./BUILD dme ncp.amd64` in the configured container.
If no positional argument (name) is set, it will assume the repository name and do the canonical build.

`lal build` will run `lal verify` and warn if this fails, but proceed anyway. The warning is a developer notice that the build will not be identical on jenkins due to local modifications and should not be ignored indefinitely.

The `lal build` step will generate `OUTPUT/lockfile.json`. For local builds, this generated lockfile may be inconsistent (or wrong). However, this will fail the build on jenkins.

Jenkins will run `lal verify` to ensure it passes anyway.

#### lal install [components..]
Comes in two variants.

 - *lal install [--dev]*: fetches versions corresponding to the manifest from the registry and puts them into `INPUT`. The optional `--dev` flag will also cause `devDependencies` to be installed.

 - *lal install component=version [--save]*: fetches a specific version. The optional `--save` flag will also update the manifest file locally.

The specific version is either a number corresponding to the last tag, or it's a name corresponding to something in `stash` (see `lal stash`). Without a specific version, the latest version is installed.

### Uncommon/Advanced/Internal Command Specification
#### lal shell
Enters an interactive shell in the container listed in `.lalrc` mounting the current directory.

Useful for experimental builds with stuff like `bcm` and `opts`.
Assumes you have run `lal install` or equivalent so that `INPUT` is ready for this.

Should run:

```sh
docker run \
  -v $HOME/.gitconfig:/home/lal/.gitconfig \
  -v $PWD:/home/lal/root \
  -w /home/lal/root \
  --net host \
  --cap-add SYS_NICE \
  --user lal \
  -it $LALCONTAINER \
  /bin/bash
```

You may just have your own wrapper for this anyway, but this is the canonical one. You can not use `lal` inside the container (right?).

#### lal stash <name>
Stashes the current `OUTPUT` folder to in `~/.lal/cache/stash/${target}/${component}/${NAME}` for future reuse. This can be installed into another repository with `lal install component=name`

#### lal verify
Verifies that:

- `manifest.json` exists in `$PWD`
- `manifest.json` is valid json.
- dependencies in `INPUT` match `manifest.json`.
- the dependency tree is flat.
- `INPUT` contains only global dependencies.

#### lal configure
Interactively configures:

- target to inject into `install` and `build` (default: ncp.amd64)
- docker container to use for `build` (default: edonusdevelopers/centos_build)
- registry to use (default: https://artifactory.wherever)
- cache directory to use (default: ~/.lal/cache)
- cache size warning (default: 5G)

To get defaults use `yes "" | lal configure`.

#### lal deploy
Run `scripts.deploy` in manifest in container.

#### lal test
Run `script.test` in manifest in container.

### Universal Options

- `--verbose` or `-v`
- `--help` or `-h`


## Workflow
### Install and Update
Installing pinned versions and building:

```sh
git clone git@sqbu-github.cisco.com:Edonus/monolith
cd monolith
lal install --dev
# for canonical build
lal build
# for experimental
lal shell
docker> ./bcm shared_tests -t
```

Updating dependencies:
(This example presumes ciscossl has independently been updated to version 6 and is ready to be bumped.)

```sh
lal install ciscossl 6 --save
lal verify # checks the tree for consistency
lal build # check it builds with new version
git commit manifest.json -m "updated ciscossl to version 6"
git push
```

### Reusing Builds
Using stashed dependencies:

```sh
git clone git@sqbu-github.cisco.com:Edonus/ciscossl
cd ciscossl
# edit
lal build
lal stash asan
cd ../monolith
lal install ciscossl=asan # install named version (always from stash)
lal build
```

This workflow replaces listing multiple components to `./build` and `lal status` replaces the output for the build plan.

### Creating a new version
Done automatically on validated merge. Jenkins will create a tag for each successful build and that tag should be fetchable from artifactory.

### Creating a new component
Create a git repo, `lal init` it, then install deps and verify it builds.

```sh
mkdir newcomponent
cd newcomponent
lal init # create manifest
git init
git add manifest.json
git ci -m "init newcomponent"
# add git remotes (depends on where we host)
lal install gtest --save-dev
lal install libwebsockets --save
# create source and iterate until `lal build` and `lal test` succeeds
lal version --bump # new version
git commit -a -m "inital working version"
git push -u origin master
```

The last changeset will be tagged by jenkins if it succeeds. These have been done in two changesets here for clarity, but they could be done  in the same change.

### Historical Documentation
Terms used herin reference [so you want to write a package manager](https://medium.com/@sdboyer/so-you-want-to-write-a-package-manager-4ae9c17d9527#.rlvjqxc4r) (long read).

Original [buildroot notes](https://hg.lal.cisco.com/root/files/tip/NOTES).
