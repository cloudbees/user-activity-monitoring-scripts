#!/bin/bash
set -euo pipefail

HERE="$( cd -P "$( dirname "${BASH_SOURCE[0]}}" )" && pwd )"
GROOVY_LIB="${HERE}/.groovy"

download () {
  local groupId="$1"
  local artifactId="$2"
  local version="$3"
  [[ ! -f "${GROOVY_LIB}/${artifactId}-${version}.jar" ]] \
  && echo -n "Downloading ${groupId}:${artifactId}:${version}" \
  && wget -q -O "${GROOVY_LIB}/${artifactId}-${version}.jar" "https://repo.maven.apache.org/maven2/${groupId//.//}/${artifactId}/${version}/${artifactId}-${version}.jar" \
  && echo " OK" || true
}

# INSTALL GROOVY AND RELATED LIBS
mkdir -p "${GROOVY_LIB}"
download "org.codehaus.groovy" "groovy" "2.5.6"
download "org.apache.ivy" "ivy" "2.4.0"

java -cp "${GROOVY_LIB}/*" groovy.ui.GroovyMain CountUsers "$@"
