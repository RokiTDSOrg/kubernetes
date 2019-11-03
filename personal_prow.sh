#!/bin/bash - 
#===============================================================================
#
#          FILE: personal_prow.sh
# 
#         USAGE: ./personal_prow.sh 
# 
#   DESCRIPTION: Deploy prow from head commit on test-infra on kind using kaap 
#                from k14s 
#                Destroys pre-existing prow on kind
#                Cluster name is personal-prow
# 
#       OPTIONS: ---
#  REQUIREMENTS: kind, kapp, kwt, docker 
#          BUGS: TODO parameterise script to accept locations of github secrets
#                      
#         NOTES: Run in personal-prow directory as it depend on and 
#                references github secret files that need to be stored here 
#        AUTHOR: Robert Kielty (robk), rob.kielty@gmail.com
#  ORGANIZATION: 
#       CREATED: 12/10/19 15:26:58
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error
declare -r GITHUB_USER="RobertKielty"
declare -r CLUSTER_NAME="personal-prow-cluster"
declare -r SECRETS_DIR="./secrets"
# declare PROW_GIT_REF="head" # TODO make the version of PROW selectable

# Start up a kind cluster for prow called personal-prow
if result=$(kind get clusters | grep "$CLUSTER_NAME"); then
	echo "$0: Let's delete that old personal-prow"
	if kind delete cluster --name="$CLUSTER_NAME"; then 
		echo "$0: deleted $CLUSTER_NAME"
		echo "$0: creating new kind cluster $CLUSTER_NAME"
		if result=$(kind create cluster --name="$CLUSTER_NAME"); then
			echo "$0: kind has brought up $CLUSTER_NAME"
			KUBECONFIG="$(kind get kubeconfig-path --name="$CLUSTER_NAME")"
			export KUBECONFIG 
			kubectl cluster-info
			CLUSTER_USER=$(kubectl config view -o jsonpath=\'\{.users[*].name\}\')
			# Configure cluster
			kubectl create clusterrolebinding cluster-admin-binding --clusterrole cluster-admin --user "$CLUSTER_USER"
			kubectl create secret generic hmac-token --from-file=hmac="$SECRETS_DIR"/hmac-token 
			kubectl create secret generic oauth-token --from-file=oauth="$SECRETS_DIR"/oauth_secret_personal_access_token 
		else
			echo "kind create cluster --name=\"personal-prow\" |$result| : Kubeston we have a problem.";
			exit
		fi
	else
		echo "kind delete cluster --name=\"personal-prow\" |$result| : Kubeston we have a problem.";
		exit 1
	fi
fi

# Deploy Prow TODO make it so can reference a specific version of Prow 
cd "$GOPATH"/src/github.com/"$GITHUB_USER"/test-infra && kapp deploy -a personal-prow-app -f prow/cluster/starter.yaml

#  
echo "./tools/ngrok http http://hook.default.svc.cluster.local:8888/"
kubectl create configmap plugins --from-file=plugins.yaml=./plugins.yaml --dry-run -o yaml | kubectl replace configmap plugins -f -
