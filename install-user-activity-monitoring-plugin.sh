#!/bin/bash
set -euo pipefail

HERE="$( cd -P "$( dirname "${BASH_SOURCE[0]}}" )" && pwd )"
# shellcheck source=/dev/null
source "${HERE}/.env"

# VERIFY NEED $OPS_CENTER_URL, JENKINS_USER_ID, JENKINS_API_TOKEN
if [[ -z "$OPS_CENTER_URL" ]]; then
    echo "Need to set environment variable OPS_CENTER_URL (CloudBees Core Ops Center root URL)."
    exit 1
fi

if [[ -z "$JENKINS_USER_ID" ]]; then
    echo "Need to set environment variable JENKINS_USER_ID."
    exit 1
fi

if [[ -z "$JENKINS_API_TOKEN" ]]; then
    echo "Need to set environment variable JENKINS_API_TOKEN."
    exit 1
fi

# INSTALL JENKINS CLI
mkdir -p "${HERE}/.jenkins"
JENKINS_CLI_JAR="${HERE}/.jenkins/jenkins-cli.jar"
if [[ -f "$JENKINS_CLI_JAR" ]]
then
	echo "Using ${JENKINS_CLI_JAR##${HERE}/}."
else
	wget -q -O "${JENKINS_CLI_JAR}" "${OPS_CENTER_URL}/jnlpJars/jenkins-cli.jar"
fi

mkdir -p "${HERE}/reports/"

echo -n "Collecting list of masters..."
masters=( $(java -jar "${JENKINS_CLI_JAR}" -s "${OPS_CENTER_URL}" list-masters | IFS='\n' jq -cr '.data.masters[] | select(.status == "ONLINE")') )
echo " done"

echo "Install plugin on masters..."
for master in "${masters[@]}"; do
	masterName=$(echo "${master}" | jq -r '.fullName')
	masterUrl=$(echo "${master}" | jq -r '.url')
	echo -en " * ${masterName}: "
	java -jar "${JENKINS_CLI_JAR}" -s "${masterUrl}" install-plugin user-activity-monitoring -deploy -restart > /dev/null 2> "${HERE}/reports/install-plugin-${masterName/\//_}-$(date '+%Y%m%d-%H%M%S')-error.log" && echo "done" || echo "ko"
done