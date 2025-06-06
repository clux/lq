#!/usr/bin/env bats

@test "stdin" {
  run lq -y '.[2].kind' < test/deploy.yaml
  echo "$output" && echo "$output" | grep "ClusterRoleBinding"
}

@test "file" {
  if [[ "${CI}" =~ "true" ]]; then
    skip # isTerminal seems to do the wrong thing on github actions..
  fi
  lq -y '.[2].kind' test/deploy.yaml
  run lq -y '.[2].kind' test/deploy.yaml
  echo "$output" && echo "$output" | grep "ClusterRoleBinding"
}

@test "compact_json_output" {
  run lq '.[2].metadata' -c < test/deploy.yaml
  echo "$output" && echo "$output" | grep '{"name":"controller"}'
}

@test "nested_select" {
  run lq '.[] | select(.kind == "Deployment") | .spec.template.spec.containers[0].ports[0].containerPort' -r < test/deploy.yaml
  echo "$output" && echo "$output" | grep "8000"
}

@test "nested_select_json" {
  run lq '.[] | select(.kind == "Deployment") | .spec.template.spec.containers[0].readinessProbe' -c < test/deploy.yaml
  echo "$output" && echo "$output" | grep '{"httpGet":{"path":"/health","port":"http"},"initialDelaySeconds":5,"periodSeconds":5}'

  run lq '.spec.template.spec.containers[].image' -r < test/grafana.yaml
}

@test "jq_compat" {
  cat test/deploy.yaml | lq '.[] | select(.kind == "Deployment") | .spec.template.spec.containers[0].readinessProbe' -c > test/output.json
  run lq ".httpGet.path" test/output.json
  echo "$output" && echo "$output" | grep '"/health"'
  rm test/output.json
}

@test "lq_in_place_edit" {
  cat test/secret.yaml |  lq -i '.metadata.name="updated-name"' > test/output.yaml
  cat test/output.yaml | lq '.metadata.name' | grep 'updated-name'
  rm test/output.yaml
}

@test "exit_codes" {
  run lq -h
  [ "$status" -eq 0 ]
  run lq --help
  [ "$status" -eq 0 ]
  if [[ "${CI}" =~ "true" ]]; then
    skip # ci is fun
  fi
  run lq
  [ "$status" -eq 1 ]
}

@test "toml" {
  run lq --input=toml -y '.package.edition' -r < Cargo.toml
  echo "$output" && echo "$output" | grep '2021'
  run lq -Ty '.package.edition' -r < Cargo.toml

  run lq '.dependencies.clap.features' -c Cargo.toml
  echo "$output" && echo "$output" | grep '["cargo","derive"]'
}

@test "yaml_merge" {
  run lq '.workflows.my_flow.jobs[0].build' -c < test/circle.yml
  echo "$output" && echo "$output" | grep '{"filters":{"tags":{"only":"/.*/"}}}'

  run lq '.jobs.build.steps[1].run.name' -r < test/circle.yml
  echo "$output" && echo "$output" | grep "Version information"
}

@test "inplace" {
  run lq -yi '.kind = "Hahah"' test/grafana.yaml
  run lq -r .kind test/grafana.yaml
  echo "$output" && echo "$output" | grep "Hahah"
  lq -yi '.kind = "Deployment"' test/grafana.yaml # undo
}

@test "join" {
  run lq -j '.spec.template.spec.containers[].image' test/grafana.yaml
  echo "$output" && echo "$output" | grep "quay.io/kiwigrid/k8s-sidecar:1.24.6quay.io/kiwigrid/k8s-sidecar:1.24.6docker.io/grafana/grafana:10.1.0"
}

@test "json_input" {
  run lq --input=json ".ingredients | keys" -c < test/guacamole.json
  echo "$output" && echo "$output" | grep '["avocado","coriander","cumin","garlic","lime","onions","pepper","salt","tomatoes"]'
  run lq -J ".ingredients | keys" -c < test/guacamole.json
}

@test "jq_modules" {
  run lq 'include "k"; . | gvk' -r -L$PWD/test/modules < test/grafana.yaml
  echo "$output" && echo "$output" | grep 'apps/v1.Deployment'
}

@test "paramless" {
  run lq -y <<< '["foo"]'
  echo "$output" && echo "$output" | grep '\- foo'
  run lq <<< '"bar"'
  echo "$output" && echo "$output" | grep '"bar"'
}

@test "multidoc-jq-output-to-yaml" {
  run lq '.[].metadata.labels' -y test/deploy.yaml
  echo "$output" && echo "$output" | rg -U '\- null\n- null\n- null\n- app: controller\n- app: controller'
}

@test "split-yaml-multi-to-yaml" {
  rm -f test/split/*
  mkdir -p test/split
  run lq '.' --split '"test/split/" + (.metadata.name) + "_" + (.kind | ascii_downcase) + ".yaml"' ./test/deploy.yaml -y
  [ "$status" -eq 0 ]
  files="$(find test/split -type f | wc -l)"
  echo $files && [[ "$files" -eq "5" ]]
  run lq '.kind' test/split/controller_service.yaml -r
  echo "$output" && echo "$output" | grep "Service"
}

@test "split-yaml-single-to-json" {
  rm -f test/split/*
  mkdir -p test/split
  run lq '.' --split '"test/split/" + (.metadata.name) + "_" + (.kind | ascii_downcase) + ".json"' ./test/grafana.yaml
  [ "$status" -eq 0 ]
  files="$(find test/split -type f | wc -l)"
  echo $files && [[ "$files" -eq "1" ]]
  run jq '.kind' test/split/promstack-grafana_deployment.json -r
  echo "$output" && echo "$output" | grep "Deployment"
}

@test "split-multi-json" {
  rm -f test/split/*
  mkdir -p test/split
  run lq '.' --split '"test/split/" + (.foo) + ".json"' ./test/multi.json --input=json
  [ "$status" -eq 0 ]
  files="$(find test/split -type f | wc -l)"
  echo $files && [[ "$files" -eq "2" ]]
  run jq '.foo' test/split/bar.json -r
  echo "$output" && echo "$output" | grep "bar"
}

@test "key-order-deser" {
  # order files maintains deliberately non-alphabetical key ordering which would be re-ordered unless we have preserve order features
  # run lq '.' -c ./test/order.json
  # [ "$status" -eq 0 ]
  # echo "$output" && echo "$output" | grep '{"z":"normally last","a":"normally first"}'

  run lq '.' -c ./test/order.yaml
  [ "$status" -eq 0 ]
  echo "$output" && echo "$output" | grep '{"z":"normally last","a":"normally first"}'

  run lq '.' -c ./test/order.toml
  [ "$status" -eq 0 ]
  echo "$output" && echo "$output" | grep '{"z":"normally last","a":"normally first"}'
}

@test "key-order-inplace" {
  # inplace editing should not change order
  lq '.b="last"' -i ./test/order.json
  run lq '.' -c ./test/order.json
  [ "$status" -eq 0 ]
  echo "$output" && echo "$output" | grep '{"z":"normally last","a":"normally first","b":"last"}'
  git restore ./test/order.json

  lq '.b="last"' -iy ./test/order.yaml
  run lq '.' -c ./test/order.yaml
  [ "$status" -eq 0 ]
  echo "$output" && echo "$output" | grep '{"z":"normally last","a":"normally first","b":"last"}'
  git restore ./test/order.yaml

  lq '.b="last"' -it ./test/order.toml
  run lq '.' -c ./test/order.toml
  [ "$status" -eq 0 ]
  echo "$output" && echo "$output" | grep '{"z":"normally last","a":"normally first","b":"last"}'
  git restore ./test/order.toml

}
