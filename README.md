# yq
> yet another jq wrapper

A lightweight and portable Rust implementation of the common [jq](https://jqlang.github.io/jq/) wrapper; **`yq`** for doing arbitrary `jq` style queries on YAML documents.

Provides a limited, but **drop-in replacement** of [python-yq](https://github.com/kislyuk/yq) in a smaller format to allow more easily utilising the tool in a CI setting without pulling in the more sizeable python dependencies.

The approach is the same;

1. read YAML
2. convert it to JSON
3. pass it to `jq`
4. return result

Optionally the result is passed back into YAML format with `-y`.

## Usage
Currently supports any query functionality [supported by jq](https://jqlang.github.io/jq/tutorial/) either via stdin:

```sh
$ yq '.[3].kind' -r < deployment.yaml
Service

$ yq '.[3].metadata' -y < deployment.yaml
labels:
  app: version
name: version
namespace: default
```

or from a file arg (at the end):

```sh
$ yq '.[3].kind' -r deployment.yaml
$ yq '.[3].metadata' -y deployment.yaml
```

## Installation

```sh
cargo install yjq
```

**Note**: Depends on `jq` being installed.

## Limitations

Only YAML is supported (no TOML / XML - PRs welcome). Shells out to `jq`. Does not preserve [YAML tags](https://yaml.org/spec/1.2-old/spec.html#id2764295) (input is [singleton mapped](https://docs.rs/serde_yaml/latest/serde_yaml/with/singleton_map/index.html) [recursively](https://docs.rs/serde_yaml/latest/serde_yaml/with/singleton_map_recursive/index.html)). No binary builds on CI yet.