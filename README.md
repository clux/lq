# lq - low overhead yq/tq/jq cli
[![CI](https://github.com/clux/lq/actions/workflows/release.yml/badge.svg)](https://github.com/clux/lq/actions/workflows/release.yml)
[![Crates.io](https://img.shields.io/crates/v/lq.svg)](https://crates.io/crates/lq)
[![dependency status](https://deps.rs/repo/github/clux/lq/status.svg)](https://deps.rs/repo/github/clux/lq)

A lightweight and portable [jq](https://jqlang.github.io/jq/) style cli for doing jq queries/filters/maps/transforms on **YAML**/**TOML**/**JSON** documents by converting to **JSON** and passing data to `jq`. Output is raw `jq` output which can optionally be mapped to TOML or YAML.

## Installation

Via cargo:

```sh
cargo install lq
```

or download a prebuilt from [releases](https://github.com/clux/lq/releases) either manually, or via [binstall](https://github.com/cargo-bins/cargo-binstall):

```sh
cargo binstall lq
```

**Note**: Requires `jq`.

## Why / Why Not

### jq compatibility

- arbitrary `jq` usage on any input format (yaml/toml/json) by going through json and jq
- [same syntax](https://jqlang.github.io/jq/manual/), same filters, types, operators, conditionals, regexes, assignment, modules, etc
- matches `jq`'s cli interface (only some extra input/output format controlling flags)
- supports `jq` output formatters such as `-c`, `-r`, and `-j` (compact, raw, joined output resp)

### Extra Features

- supports __multidoc yaml__ input, handles [yaml merge keys](https://yaml.org/type/merge.html) (expanding tags)
- supports __multidoc__ document splitting into expression based filenames
- supports __in-place edits__ of documents
- reads from __stdin xor file__ (file if last arg is a file)
- filetype format inference when passing files
- quick input/output flags: `-y` (YAML out) or `-t` (TOML out), `-T` (TOML in), `-J` (JSON in)

### Portable yq replacement

- ~[1MB](https://github.com/clux/lq/releases/latest) in binary (for small CI images / [binstalled ci actions](https://github.com/cargo-bins/cargo-binstall#faq))
- 99% replacement of [python-yq](https://kislyuk.github.io/yq/) (with `yq` named/linked to `lq`)

### Limitations

- Shells out to `jq` (not standalone - [for now](https://github.com/clux/lq/issues/64))
- Expands [YAML tags](https://yaml.org/spec/1.2-old/spec.html#id2764295) (input is [singleton mapped](https://docs.rs/serde_yaml/latest/serde_yaml/with/singleton_map/index.html) -> [recursively](https://docs.rs/serde_yaml/latest/serde_yaml/with/singleton_map_recursive/index.html), then [merged](https://docs.rs/serde_yaml/latest/serde_yaml/value/enum.Value.html#method.apply_merge)) - so tags are [not preserved](https://github.com/clux/lq/issues/12) in the output
- Does not preserve indentation (unsupported in [serde_yaml](https://github.com/dtolnay/serde-yaml/issues/337))
- Does not support [duplicate keys](https://github.com/clux/lq/issues/14) in the input document
- Formats require a [serde implementation](https://serde.rs/#data-formats).
- Limited format support. No XML/CSV/RON support (or other more exotic formats). [KDL wanted](https://github.com/clux/lq/issues/56).

## Usage

### YAML
Use as [jq](https://jqlang.github.io/jq/tutorial/) either via stdin:

```sh
$ lq '.[3].kind' -r < test/deploy.yaml
Service

$ lq -y '.[3].metadata' < test/deploy.yaml
labels:
  app: controller
name: controller
namespace: default
```

or from a file arg (at the end):

```sh
$ lq '.[3].kind' -r test/deploy.yaml
$ lq -y '.[3].metadata' test/deploy.yaml
```

### TOML

Infers input format from extension, or set explicitly via `-T` or `--input=toml`.

```sh
$ lq '.package.categories[]' -r Cargo.toml
command-line-utilities
parsing
```

convert jq output back into toml (`-t`):

```sh
$ lq -t '.package.metadata' Cargo.toml
[binstall]
bin-dir = "lq-{ target }/{ bin }{ format }"
pkg-url = "{ repo }/releases/download/{ version }lq-{ target }{ archive-suffix }"
```

convert jq output to yaml (`-y`) and set explicit toml input when using stdin (`-T`):

```sh
$ lq -Ty '.dependencies.clap' < Cargo.toml
features:
- cargo
- derive
version: 4.4.2
```

jq style compact output:

```sh
$ lq '.profile' -c Cargo.toml
{"release":{"lto":true,"panic":"abort","strip":"symbols"}}
```

To shortcut passing input formats, you can add `alias tq='lq --input=toml'` in your `.bashrc` / `.zshrc` (etc).

### JSON Input

Infers input format from extension, or set explicitly via `-J` or `--input=json`.

```sh
$ lq -Jy '.ingredients | keys' < test/guacamole.json
- avocado
- coriander
- cumin
- garlic
- lime
- onions
- pepper
- salt
- tomatoes
```

Using JSON input is kind of like talking to `jq` directly, with the benefit that you can change output formats, or do inplace edits.

### Formats
Default is going from `yaml` input to `jq` output to allow further pipes into `jq`.

- **Input** flags are **upper case** :: `-J` json input, `-T` toml input (shorthands for `--input=FORMAT`)
- **Output** flags are **lower case** :: `-y` yaml output, `-t` toml output (shorthands for `--output=FORMAT`)

Ex;
- `lq` :: yaml -> jq output
- `lq -t` :: yaml -> toml
- `lq -y`  :: yaml -> yaml
- `lq -Tt` :: toml -> toml
- `lq -Jy` :: json -> yaml
- `jq -Ty` :: toml -> yaml
- `jq -Jt` :: json -> toml

Output formatting such as `-y` for YAML or `-t` for TOML will require the output from `jq` to be parseable json.
If you pass on `-r`,`-c` or `-c` for raw/compact output, then this output may not be parseable as json.

### Advanced Features
Two things you cannot do in `jq`:

#### Multidoc Splits
Split a bundle of yaml files into a yaml file per Kubernetes `.metadata.name` key:

```sh
mkdir -p crds
curl -sSL https://github.com/prometheus-operator/prometheus-operator/releases/download/v0.82.1/stripped-down-crds.yaml \
  | lq . -y --split '"crds/" + (.metadata.name) + ".yaml"'
```

#### In Place Edits
Patch a json file ([without multiple pipes](https://github.com/jqlang/jq/issues/105)):

```sh
lq -i '.SKIP_HOST_UPDATE=true' ~/.config/discord/settings.json
```

### Advanced jq
Any weird things you can do with `jq` works. Some common (larger) examples:

#### Selects

Select on yaml multidoc:

```sh
$ lq '.[] | select(.kind == "Deployment") | .spec.template.spec.containers[0].ports[0].containerPort' test/deploy.yaml
8000
```

Escaping keys with slashes etc in them:

```sh
lq '.updates[] | select(.["package-ecosystem"] == "cargo") | .groups' .github/dependabot.yml
```

#### Modules
You can import [jq modules](https://jqlang.github.io/jq/manual/#modules) e.g. [k.jq](https://github.com/clux/lq/blob/main/test/modules/k.jq):

```sh
$ lq 'include "k"; .[] | gvk' -r -L$PWD/test/modules < test/deploy.yaml
v1.ServiceAccount
rbac.authorization.k8s.io/v1.ClusterRole
rbac.authorization.k8s.io/v1.ClusterRoleBinding
v1.Service
apps/v1.Deployment
```

### Debug Logs

The project respects `RUST_LOG` when set, and sends these diagnostic logs to stderr:

```sh
$ RUST_LOG=debug lq '.version' test/circle.yml
2023-09-18T23:17:04.533055Z DEBUG lq: args: Args { input: Yaml, output: Jq, yaml_output: false, toml_output: false, in_place: false, jq_query: ".version", file: Some("test/circle.yml"), compact_output: false, raw_output: false, join_output: false, modules: None }
2023-09-18T23:17:04.533531Z DEBUG lq: found 1 documents
2023-09-18T23:17:04.533563Z DEBUG lq: input decoded as json: {"definitions":{"filters":{"on_every_commit":{"tags":{"only":"/.*/"}},"on_tag":{"branches":{"ignore":"/.*/"},"tags":{"only":"/v[0-9]+(\\.[0-9]+)*/"}}},"steps":[{"step":{"command":"chmod a+w . && cargo build --release","name":"Build binary"}},{"step":{"command":"rustc --version; cargo --version; rustup --version","name":"Version information"}}]},"jobs":{"build":{"docker":[{"image":"clux/muslrust:stable"}],"environment":{"IMAGE_NAME":"lq"},"resource_class":"xlarge","steps":["checkout",{"run":{"command":"rustc --version; cargo --version; rustup --version","name":"Version information"}},{"run":{"command":"chmod a+w . && cargo build --release","name":"Build binary"}},{"run":"echo versions"}]},"release":{"docker":[{"image":"clux/muslrust:stable"}],"resource_class":"xlarge","steps":["checkout",{"run":{"command":"rustc --version; cargo --version; rustup --version","name":"Version information"}},{"run":{"command":"chmod a+w . && cargo build --release","name":"Build binary"}},{"upload":{"arch":"x86_64-unknown-linux-musl","binary_name":"${IMAGE_NAME}","source":"target/x86_64-unknown-linux-musl/release/${IMAGE_NAME}","version":"${CIRCLE_TAG}"}}]}},"version":2.1,"workflows":{"my_flow":{"jobs":[{"build":{"filters":{"tags":{"only":"/.*/"}}}},{"release":{"filters":{"branches":{"ignore":"/.*/"},"tags":{"only":"/v[0-9]+(\\.[0-9]+)*/"}}}}]},"version":2}}
2023-09-18T23:17:04.533650Z DEBUG lq: jq args: [".version"]
2023-09-18T23:17:04.538606Z DEBUG lq: jq stdout: 2.1

2.1
```

### lq as yq
Because yaml is the default input language, you __can__ use it as your top level `yq` executable with a symlink or alias:

```sh
# globally make yq be lq
ln -s $(which lq) /usr/local/bin/yq

# alias yq to lq in shell environment only
alias yq=lq
```

It is mostly compatible with `python-yq` (which uses `jq` syntax) but differs from go yq (which invents its own syntax).

(This use-case was the first use-case for this tool, i.e. to get rid of heavy python deps in CI images)
