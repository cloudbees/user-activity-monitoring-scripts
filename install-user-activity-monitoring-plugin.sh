#!/bin/bash
set -euo pipefail

HERE="$( cd -P "$( dirname "${BASH_SOURCE[0]}}" )" && pwd )"
# shellcheck source=/dev/null
source "${HERE}/.env"

# VERIFY NEED $OPS_CENTER_URL, JENKINS_USER_ID, JENKINS_API_TOKEN
if [[ -z "${OPS_CENTER_URL:-""}" ]]; then
    echo "Need to set environment variable OPS_CENTER_URL (CloudBees Core Ops Center root URL)."
    exit 1
fi

if [[ -z "${JENKINS_USER_ID:-""}" ]]; then
    echo "Need to set environment variable JENKINS_USER_ID."
    exit 1
fi

if [[ -z "${JENKINS_API_TOKEN:-""}" ]]; then
    echo "Need to set environment variable JENKINS_API_TOKEN."
    exit 1
fi

if [[ -z "${PLUGIN_CATALOG_REPOSITORY_CREDENTIALS_ID:-""}" ]]; then
    echo "Need to set environment variable PLUGIN_CATALOG_REPOSITORY_CREDENTIALS_ID."
    exit 1
fi

if [[ -z "${PLUGIN_CATALOG_REPOSITORY_USERNAME:-""}" ]]; then
    echo "Need to set environment variable PLUGIN_CATALOG_REPOSITORY_USERNAME."
    exit 1
fi

if [[ -z "${PLUGIN_CATALOG_REPOSITORY_PASSWORD:-""}" ]]; then
    echo "Need to set environment variable PLUGIN_CATALOG_REPOSITORY_PASSWORD."
    exit 1
fi

if [[ ! -f "${HERE}/standard-master-plugin-catalog.json" ]]; then
	echo "You must have a file ${HERE}/standard-master-plugin-catalog.json to describe the plugin catalog to install the plugin."
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

# Upload plugin to Maven Repo
# mvn deploy:deploy-file -DgroupId=com.cloudbees.jenkins.plugins \
#   -DartifactId=user-activity-monitoring \
#   -Dversion=1.1.2 \
#   -Dpackaging=hpi \
#   -Dfile=user-activity-monitoring-1.1.2.hpi \
#   -DrepositoryId=nexus3.beescloud.com \
#   -Durl=https://nexus3.beescloud.com/repository/private-maven-releases/

# UPLOAD PLUGIN CATALOG WITH A REFERENCE TO THE USER_ACTIVITY_MONITORING
echo -n "Uploading plugin catalog standard-master to ${OPS_CENTER_URL}..."
java -jar "${JENKINS_CLI_JAR}" -s "${OPS_CENTER_URL}" plugin-catalog --put < "${HERE}/standard-master-plugin-catalog.json" > /dev/null
echo " done"

echo -n "Collecting list of masters..."
masters=( $(java -jar "${JENKINS_CLI_JAR}" -s "${OPS_CENTER_URL}" list-masters | IFS='\n' jq -cr '.data.masters[] | select(.status == "ONLINE")') )
echo " done"

# DEPLOY CREDENTIALS ON ALL MASTERS
CREDENTIALS_FILE="${HERE}/.jenkins/credentials.xml"
cat > "${CREDENTIALS_FILE}" <<EOM
<com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
  <scope>GLOBAL</scope>
  <id>${PLUGIN_CATALOG_REPOSITORY_CREDENTIALS_ID}</id>
  <description>${PLUGIN_CATALOG_REPOSITORY_USERNAME} @ Plugin Catalog Repository</description>
  <username>${PLUGIN_CATALOG_REPOSITORY_USERNAME}</username>
  <password>${PLUGIN_CATALOG_REPOSITORY_PASSWORD}</password>
</com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
EOM
echo "Deploy plugin catalog credentials ${PLUGIN_CATALOG_REPOSITORY_CREDENTIALS_ID} on..."
for master in "${masters[@]}"; do
	masterName=$(echo "${master}" | jq -r '.fullName')
	masterUrl=$(echo "${master}" | jq -r '.url')
	echo -n " * ${masterName}: "
	java -jar "${JENKINS_CLI_JAR}" -s "${masterUrl}" create-credentials-by-xml system::system::jenkins _ < "${CREDENTIALS_FILE}" &> /dev/null || true
	if [[ "${?}" -eq 1 ]]; then
		java -jar "${JENKINS_CLI_JAR}" -s "${masterUrl}" update-credentials-by-xml system::system::jenkins _ "${PLUGIN_CATALOG_REPOSITORY_CREDENTIALS_ID}" < "${CREDENTIALS_FILE}" &> /dev/null
	fi
	echo "done"
done
test -f "${CREDENTIALS_FILE}" && rm "${CREDENTIALS_FILE}"

# DEFINE THE PLUGIN CATALOG ON EACH MASTER
echo "Define plugin catalog standard-master on..."
for master in "${masters[@]}"; do
	masterName=$(echo "${master}" | jq -r '.fullName')
	masterUrl=$(echo "${master}" | jq -r '.url')
	echo -en " * ${masterName}: "
	java -jar "${JENKINS_CLI_JAR}" -s "${OPS_CENTER_URL}" plugin-catalog --push "standard-master" --master "${masterName}" &> /dev/null && echo "done" || echo "ko"
done

echo "Sleep one minute to let Operations Center update plugin catalog on the masters..."
sleep 60

mkdir -p "${HERE}/out/reports"
mkdir -p "${HERE}/out/logs"

echo "Install plugin..."
for master in "${masters[@]}"; do
	masterName=$(echo "${master}" | jq -r '.fullName')
	masterUrl=$(echo "${master}" | jq -r '.url')
	echo -en " * ${masterName}: "
	java -jar "${JENKINS_CLI_JAR}" -s "${masterUrl}" install-plugin user-activity-monitoring -deploy > /dev/null 2> "${HERE}/out/logs/install-plugin-${masterName/\//_}-$(date '+%Y%m%d-%H%M%S')-error.log" && echo "done" || echo "ko"
done
