# Operator tests

## Running tests
One can run test by entering to 'community-operators' project directory and run with following command with these options. '<git repo>' and '<git branch>' options are optional
```
cd <community-operators>
bash <(curl -s https://raw.githubusercontent.com/J0zi/operator-test-playbooks/upstream-community/test/test.sh) \
<test-type1,test-type2,...,test-typeN> \
<operator-version-dir-relative-to-community-operators-project> \
[<git repo>] [<git branch>]
```

### Test type

List of tests are shwon in following table
|Test type|Description|
|:--------|:----------|
|kiwi|Full operator test|
|lemon|Full test of operator to be deployed from scratch|
|orange|Full test of operator to be deployed with existing bundles in quay registry|
|all|kiwi,lemon,orange|

### Logs
Logs can be found in `/tmp/op-test/log.out`

### Testing log files
If operator test fails, one can enter to testing container via follwing command. One can substitue 'docker'
```
docker exec -it op-test /bin/bash
```

# Examples

## Running tests from local direcotry
Following example will run 'all' tests on 'aqua' operator with version '1.0.2' from 'upstream-community-operators (k8s)' directory. 'community-operators' project will be taken from local directory one is running command from ($PWD).
```
cd <community-operators>
bash <(curl -s https://raw.githubusercontent.com/J0zi/operator-test-playbooks/upstream-community/test/test.sh) \
all \
upstream-community-operators/aqua/1.0.2
```

## Running tests from official 'community-operators' repo

Following example will run 'kiwi' and 'lemon' tests on 'aqua' operator with version '1.0.2' from 'community-operators (openshift)' directory. 'community-operators' project will be taken from git repo 'https://github.com/operator-framework/community-operators' and 'master' branch
```
cd <community-operators>
bash <(curl -s https://raw.githubusercontent.com/J0zi/operator-test-playbooks/upstream-community/test/test.sh) \
kiwi,lemon \
community-operators/aqua/1.0.2 \
https://github.com/operator-framework/community-operators \
master
```

## Running tests from forked 'community-operators' repo ans specific branch
Following example will run 'kiwi' and 'lemon' tests on 'kong' operator with version '0.5.0' from 'upstream-community-operators (k8s)' directory.'community-operators' project will be taken from git repo 'https://github.com/Kong/community-operators' and 'release/v0.5.0' branch ('https://github.com/Kong/community-operators/tree/release/v0.5.0')
```
cd <community-operators>
bash <(curl -s https://raw.githubusercontent.com/J0zi/operator-test-playbooks/upstream-community/test/test.sh) \
kiwi,lemon \
upstream-community-operators/kong/0.5.0 \
https://github.com/Kong/community-operators \
release/v0.5.0
```



