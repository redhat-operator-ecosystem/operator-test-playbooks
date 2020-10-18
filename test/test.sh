#!/bin/bash
set +o pipefail

ACTION=${1-""}
OP_TEST_IMAGE=${OP_TEST_IMAGE-"quay.io/operator_testing/operator-test-playbooks:latest"}
OP_TEST_CERT_DIR=${OP_TEST_CERT_DIR-"/tmp/certs"}
OP_TEST_CONTAINER_TOOL=${OP_TEST_CONTAINER_TOOL-"docker"}
OP_TEST_NAME=${OPT_TEST_NAME-"op-test"}
OP_TEST_ANSIBLE_PULL_REPO=${OP_TEST_ANSIBLE_PULL_REPO-"https://github.com/redhat-operator-ecosystem/operator-test-playbooks"}
OP_TEST_ANSIBLE_PULL_BRANCH=${OP_TEST_ANSIBLE_PULL_BRANCH-"upstream-community"}
OP_TEST_ANSIBLE_DEFAULT_ARGS=${OP_TEST_ANSIBLE_DEFAULT_ARGS-"-i localhost, -e ansible_connection=local -e run_upstream=true -e run_remove_catalog_repo=true"}
OP_TEST_ANSIBLE_EXTRA_ARGS=${OP_TEST_ANSIBLE_EXTRA_ARGS-"--tags base,kubectl,kind"}
OP_TEST_CONAINER_RUN_DEFAULT_ARGS=${OP_TEST_CONAINER_RUN_DEFAULT_ARGS-"--net host --cap-add SYS_ADMIN --cap-add SYS_RESOURCE --security-opt seccomp=unconfined --security-opt label=disable -v $OP_TEST_CERT_DIR/domain.crt:/usr/share/pki/ca-trust-source/anchors/ca.crt -v /tmp/.kube:/root/.kube -e STORAGE_DRIVER=vfs"}
OP_TEST_CONTAINER_RUN_EXTRA_ARGS=${OP_TEST_CONTAINER_RUN_EXTRA_ARGS-""}
OP_TEST_CONTAINER_EXEC_DEFAULT_ARGS=${OP_TEST_CONTAINER_EXEC_DEFAULT_ARGS-""}
OP_TEST_CONTAINER_EXEC_EXTRA_ARGS=${OP_TEST_CONTAINER_EXEC_EXTRA_ARGS-""}
OP_TEST_EXEC_BASE=${OP_TEST_EXEC_BASE-"ansible-playbook -i localhost, -e ansible_connection=local local.yml -e run_upstream=true -e image_protocol='docker://' -vv"}
OP_TEST_EXEC_EXTRA=${OP_TEST_EXEC_EXTRA-"-e opm_container_tool=podman -e container_tool=podman -e opm_container_tool_index="}
OP_TEST_RUN_MODE=${OP_TEST_RUN_MODE-"privileged"}
OP_TEST_DEBUG=${OP_TEST_DEBUG-0}
OP_TEST_DRY_RUN=${OP_TEST_DRY_RUN-0}
OP_TEST_FORCE_INSTALL=${OP_TEST_FORCE_INSTALL-0}
OP_TEST_LOG_DIR=${OP_TEST_LOG_DIR-"/tmp/op-test"}

function help() {
    echo ""
    echo "sdsad"
    echo ""
    exit 1
}

function clean() {
    echo "Removing testing container '$OP_TEST_NAME' ..."
    $OP_TEST_CONTAINER_TOOL rm -f $OP_TEST_NAME > /dev/null 2>&1
    echo "Removing kind registry 'kind-registry' ..."
    $OP_TEST_CONTAINER_TOOL rm -f kind-registry > /dev/null 2>&1
    command -v kind > /dev/null 2>&1 && kind delete cluster --name operator-test
    echo "Removing cert dir '$OP_TEST_CERT_DIR' ..."
    rm -rf $OP_TEST_CERT_DIR > /dev/null 2>&1
    echo "Done"
    exit 0
}

run() {
        if [[ $OP_TEST_DEBUG -gt 0 ]] ; then
                v=$(exec 2>&1 && set -x && set -- "$@")
                echo "#${v#*--}"
                set -o pipefail
                "$@" | tee -a $OP_TEST_LOG_DIR/log.out
                [[ $? -eq 0 ]] || exit 1
                set +o pipefail
        else
                set -o pipefail
                "$@" | tee -a $OP_TEST_LOG_DIR/log.out >/dev/null 2>&1
                [[ $? -eq 0 ]] || exit 1
                set +o pipefail
        fi
}

[ "$OP_TEST_RUN_MODE" = "privileged" ] && OP_TEST_CONAINER_RUN_DEFAULT_ARGS="--privileged --net host -v $OP_TEST_CERT_DIR:/usr/share/pki/ca-trust-source/anchors -v $HOME/.kube:/root/.kube -e STORAGE_DRIVER=vfs"


# OP_TEST_EXEC_USER="-e operator_dir=/tmp/community-operators-for-catalog/upstream-community-operators/aqua -e operator_version=1.0.2 --tags pure_test"

if ! command -v ansible > /dev/null 2>&1; then
    echo "Error: Ansible is not installed. Please install it first !!!"
    echo "    e.g. : pip install ansible jmespath"
    exit 1
fi

if [ "$OP_TEST_CONTAINER_TOOL" = "podman" ];then
    OP_TEST_ANSIBLE_EXTRA_ARGS="$OP_TEST_ANSIBLE_EXTRA_ARGS -e opm_container_tool=podman -e container_tool=podman -e opm_container_tool_index="
    OP_TEST_EXEC_EXTRA="$OP_TEST_EXEC_EXTRA -e opm_container_tool=podman -e container_tool=podman -e opm_container_tool_index="
fi

[[ $OP_TEST_DEBUG -eq 2 ]] && OP_TEST_EXEC_EXTRA="-v $OP_TEST_EXEC_EXTRA"
[[ $OP_TEST_DEBUG -eq 3 ]] && OP_TEST_EXEC_EXTRA="-vv $OP_TEST_EXEC_EXTRA"
[[ $OP_TEST_DRY_RUN -eq 1 ]] && DRY_RUN_CMD="echo"


# Handle test types
[ -z $1 ] && help

# Handle operator info
OP_TEST_BASE_DIR=${OP_TEST_BASE_DIR-"/tmp/community-operators-for-catalog"}
OP_TEST_STREAM=${OP_TEST_STREAM-"upstream-community-operators"}
OP_TEST_OPERATOR=${OP_TEST_OPERATOR-"aqua"}
OP_TEST_VERSION=${OP_TEST_VERSION-"1.0.2"}

if [ "$OP_TEST_STREAM" = "upstream-community-operators" ] ; then
    PROD_REGISTRY_ARGS='-e production_registry_namespace=quay.io/operatorhubio -e index_force_update=true'
elif [ "$OP_TEST_STREAM" = "community-operators" ] ; then
    PROD_REGISTRY_ARGS='-e production_registry_namespace=quay.io/openshift-community-operators -e index_force_update=true'
else
  echo -e "\n Error: Unknown stream name : $OP_TEST_STREAM\n"
fi


echo "Using $(ansible --version | head -n 1) ..."
if [[ $OP_TEST_DEBUG -eq 2 ]];then
    run echo "OP_TEST_DEBUG='$OP_TEST_DEBUG'"
    run echo "OP_TEST_DRY_RUN='$OP_TEST_DRY_RUN'"
    run echo "OP_TEST_EXEC_USER='$OP_TEST_EXEC_USER'"
    run echo "OP_TEST_IMAGE='$OP_TEST_IMAGE'"
    run echo "OP_TEST_CONTAINER_EXEC_EXTRA_ARGS='$OP_TEST_CONTAINER_EXEC_EXTRA_ARGS'"
    run echo "OP_TEST_CERT_DIR='$OP_TEST_CERT_DIR'"
    run echo "OP_TEST_CONTAINER_TOOL='$OP_TEST_CONTAINER_TOOL'"
    run echo "OP_TEST_NAME='$OP_TEST_NAME'"
    run echo "OP_TEST_ANSIBLE_PULL_REPO='$OP_TEST_ANSIBLE_PULL_REPO'"
    run echo "OP_TEST_ANSIBLE_PULL_BRANCH='$OP_TEST_ANSIBLE_PULL_BRANCH'"
    run echo "OP_TEST_ANSIBLE_DEFAULT_ARGS='$OP_TEST_ANSIBLE_DEFAULT_ARGS'"
    run echo "OP_TEST_ANSIBLE_EXTRA_ARGS='$OP_TEST_ANSIBLE_EXTRA_ARGS'"
    run echo "OP_TEST_CONAINER_RUN_DEFAULT_ARGS='$OP_TEST_CONTAINER_RUN_EXTRA_ARGS'"
    run echo "OP_TEST_CONTAINER_RUN_EXTRA_ARGS='$OP_TEST_CONTAINER_RUN_EXTRA_ARGS'"
    run echo "OP_TEST_CONTAINER_EXEC_DEFAULT_ARGS='$OP_TEST_CONTAINER_EXEC_EXTRA_ARGS'"
    run echo "OP_TEST_CONTAINER_EXEC_EXTRA_ARGS='$OP_TEST_CONTAINER_EXEC_EXTRA_ARGS'"
    run echo "OP_TEST_RUN_MODE='$OP_TEST_RUN_MODE'"
    run echo "OP_TEST_FORCE_INSTALL='$OP_TEST_FORCE_INSTALL'"
    run echo "OP_TEST_LOG_DIR='$OP_TEST_LOG_DIR'"
fi


[ "$ACTION" = "clean" ] && clean

if ! command -v $OP_TEST_CONTAINER_TOOL > /dev/null 2>&1; then
    echo -e "\nError: '$OP_TEST_CONTAINER_TOOL' is missing !!! Install it via:"
    [ "$OP_TEST_CONTAINER_TOOL" = "docker" ] && echo -e "\n\tbash <(curl -s https://<url>/test.sh) docker"
    echo
    exit 1
fi

if [ "$OP_TEST_CONTAINER_TOOL" = "docker" ];then
    OP_TEST_CONTAINER_TOOL="docker"
    #OP_TEST_CONTAINER_TOOL="sudo docker"
fi

# Check if kind is installed
echo -e "\nChecking for kind binary ..."
if ! $DRY_RUN_CMD command -v kind > /dev/null 2>&1; then
    OP_TEST_FORCE_INSTALL=1
    # Check if kind cluster is running
else
    echo -e "Testing existance of kind cluster ..."
    if ! $DRY_RUN_CMD kind get clusters | grep operator-test > /dev/null 2>&1; then
        OP_TEST_FORCE_INSTALL=1
        echo
    fi
fi

[ -d $OP_TEST_LOG_DIR ] || mkdir -p $OP_TEST_LOG_DIR
[ -f $OP_TEST_LOG_DIR/log.out ] && rm -f $OP_TEST_LOG_DIR/log.out

# Install prerequisites (kind cluster)
[[ $OP_TEST_FORCE_INSTALL -eq 1 ]] && run echo -e " [ Installing prerequisites ] "
[[ $OP_TEST_FORCE_INSTALL -eq 1 ]] && run $DRY_RUN_CMD ansible-pull -U $OP_TEST_ANSIBLE_PULL_REPO -C $OP_TEST_ANSIBLE_PULL_BRANCH $OP_TEST_ANSIBLE_DEFAULT_ARGS $OP_TEST_ANSIBLE_EXTRA_ARGS


# Start container
run echo -e " [ Preparing testing container '$OP_TEST_NAME' ] "
run $DRY_RUN_CMD $OP_TEST_CONTAINER_TOOL pull $OP_TEST_IMAGE

TESTS=$1
[[ $TESTS == all* ]] && TESTS="kiwi,lemon,orange"
TESTS=${TESTS//,/ }

for t in $TESTS;do
    # Exec test
    OP_TEST_EXEC_USER=
    [ "$t" = "kiwi" ] && OP_TEST_EXEC_USER="-e operator_dir=$OP_TEST_BASE_DIR/$OP_TEST_STREAM/$OP_TEST_OPERATOR -e operator_version=$OP_TEST_VERSION --tags pure_test"
    [ "$t" = "lemon" ] && OP_TEST_EXEC_USER="-e operator_dir=$OP_TEST_BASE_DIR/$OP_TEST_STREAM/$OP_TEST_OPERATOR --tags deploy_bundles"
    [ "$t" = "orange" ] && OP_TEST_EXEC_USER="-e operator_dir=$OP_TEST_BASE_DIR/$OP_TEST_STREAM/$OP_TEST_OPERATOR $PROD_REGISTRY_ARGS --tags deploy_bundles"

    [ -z "$OP_TEST_EXEC_USER" ] && { echo "Error: Unknown test '$t' !!! Exiting ..."; help; }
    echo -e "Running test '$t' ..."
    echo "$OP_TEST_EXEC_USER"
    run $DRY_RUN_CMD $OP_TEST_CONTAINER_TOOL rm -f $OP_TEST_NAME
    run $DRY_RUN_CMD $OP_TEST_CONTAINER_TOOL run -d --rm -it --name $OP_TEST_NAME $OP_TEST_CONAINER_RUN_DEFAULT_ARGS $OP_TEST_CONTAINER_RUN_EXTRA_ARGS $OP_TEST_IMAGE
    run $DRY_RUN_CMD $OP_TEST_CONTAINER_TOOL exec -it $OP_TEST_NAME /bin/bash -c "update-ca-trust && $OP_TEST_EXEC_BASE $OP_TEST_EXEC_EXTRA $OP_TEST_EXEC_USER"
done

echo "Done"

# For playbook developers
# export OP_TEST_ANSIBLE_PULL_REPO="https://github.com/J0zi/operator-test-playbooks"
# OP_TEST_DEBUG=1 OP_TEST_ANSIBLE_PULL_REPO="https://github.com/J0zi/operator-test-playbooks" bash <(curl -s https://raw.githubusercontent.com/J0zi/operator-test-playbooks/upstream-community/test/test.sh)

