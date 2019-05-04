#!/bin/sh
## Defaults
[ -z ${ARTIFACT_ID+x} ] && export ARTIFACT_ID="${UNDEFINED}"
echo "Bootstrapping ${ARTIFACT_ID}..."

# SYS and APP variables
[ -z ${SYS+x} ] && export SYS=$(echo ${ARTIFACT_ID}| cut -d'-' -f 1)
[ -z ${APP+x} ] && export APP=${ARTIFACT_ID:${#SYS}+1}
echo "- ARTIFACT_ID '${ARTIFACT_ID}' parsed as SYS='${SYS}' and APP='${APP}'"

# Microservice
[ -z ${MICROSERVICE+x} ] && export MICROSERVICE="target/microservice.jar"
echo "- Using the '${MICROSERVICE}' jar file"

# Parsing app auth secrets file if it exists...
[ -z ${APP_AUTH+x} ] && export APP_AUTH="/run/secrets/app/auth"
if [ -f "${APP_AUTH}" ]; then
    echo "- Parsing credentials from the '${APP_AUTH}' secrets file"
    IFS=':' read -ra CRED < ${APP_AUTH}
    export APP_USER="${CRED[0]}" APP_PASS="${CRED[1]}"
fi

# Parsing username secrets file if it exists...
[ -z ${APP_USER_FILE+x} ] && export APP_USER_FILE="/run/secrets/app/username"
if [ -f "${APP_USER_FILE}" ]; then
    echo "- Parsing username from the '${APP_USER}' secrets file"
    export APP_USER=$(cat ${APP_USER_FILE} | xargs echo -n)
fi

# Parsing password secrets file if it exists...
[ -z ${APP_PASS_FILE+x} ] && export APP_PASS_FILE="/run/secrets/app/password"
if [ -f "${APP_PASS_FILE}" ]; then
    echo "- Parsing password from the '${APP_USER}' secrets file"
    export APP_PASS=$(cat ${APP_PASS_FILE} | xargs echo -n)
fi

export APP_USER="${APP_USER:-CHANGEME}" APP_PASS="${APP_PASS:-CHANGEME}"
echo "- Using the '${APP_USER}' account as the Microservice identity"

# Parsing app secret
[ -z ${SECRET_PATH+x} ] && export SECRET_PATH="/run/secrets/app-secret"
if [ -f "${SECRET_PATH}" ]; then
    # Note that we assume that the secret does not contain whitespace as the command below will trim and remove all
    # multiple whitespace, e.g. the string "  some   secret\n" will become "some secret"
    echo "- Using the content of the '$SECRET_PATH' as the Microservice secret"
    export SECRET=$(cat $SECRET_PATH | xargs echo -n)
else
    echo "WARN: The SECRET_PATH envar does not point to a secrets file, defaulting to the value of the SECRET envar"
fi

# Configuring JMX options...
[ -z ${JMXREMOTE_PASSWORD_PATH+x} ] && export JMXREMOTE_PASSWORD_PATH="/run/secrets/jmxremote.password"
if [ -f "${JMXREMOTE_PASSWORD_PATH}" ]; then
    ## JMX Options
    echo "- Enabling remote JMX access using the '$JMXREMOTE_PASSWORD_PATH' remote password file"
    JMX_OPTS="${JMX_OPTS} -Dcom.sun.management.jmxremote.port=8181"
    JMX_OPTS="${JMX_OPTS} -Dcom.sun.management.jmxremote.password.file=${JMXREMOTE_PASSWORD_PATH}"
    JMX_OPTS="${JMX_OPTS} -Dcom.sun.management.jmxremote.access.file=${ETC_DIR}/jmxremote.access"
    JMX_OPTS="${JMX_OPTS} -Dcom.sun.management.jmxremote"
    JMX_OPTS="${JMX_OPTS} -Dcom.sun.management.jmxremote.ssl=false"
    JMX_OPTS="${JMX_OPTS} -Dcom.sun.management.jmxremote.local.only=false"
else
    echo "WARN: Remote JMX access disabled as the '${JMXREMOTE_PASSWORD_PATH}' JMX remote password file could not be found"
fi

# Directories
[ -z ${ETC_DIR+x} ] && export ETC_DIR="src/files"
echo "- Configuration files stored in '$ETC_DIR'"
[ -z ${CACHE_DIR+x} ] && export CACHE_DIR="target/microservice/cache"
echo "- Files cached in '${CACHE_DIR}'"

# Spring Cloud Configuration
[ -z ${CONFIG_URI+x} ] && export CONFIG_URI="http://localhost:8888"
[ -z ${CONFIG_LABEL+x} ] && export CONFIG_LABEL="develop"
[ -z ${CONFIG_PROFILES+x} ] && export CONFIG_PROFILES="loc"

# For debugging and non-spring boot apps
[ -z ${CONFIG+x} ] && export CONFIG="${CONFIG_URI}/${ARTIFACT_ID}/${CONFIG_PROFILES}/${CONFIG_LABEL}"
echo "- Config will be loaded from '${CONFIG}'"

# Spring Boot Configuration
[ -z ${SPRING_CLOUD_CONFIG_URI+x} ] && export SPRING_CLOUD_CONFIG_URI="${CONFIG_URI}"
[ -z ${SPRING_CLOUD_CONFIG_LABEL+x} ] && export SPRING_CLOUD_CONFIG_LABEL="${CONFIG_LABEL}"
[ -z ${SPRING_CLOUD_CONFIG_USERNAME+x} ] && export SPRING_CLOUD_CONFIG_USERNAME="${APP_USER}"
[ -z ${SPRING_CLOUD_CONFIG_PASSWORD+x} ] && export SPRING_CLOUD_CONFIG_PASSWORD="${APP_PASS}"

[ -z ${SPRING_PROFILES_ACTIVE+x} ] && export SPRING_PROFILES_ACTIVE="${CONFIG_PROFILES}"
[ -z ${SPRING_APPLICATION_NAME+x} ] && export SPRING_APPLICATION_NAME="${ARTIFACT_ID}"

[ -z ${HTTP_PORT+x} ] && export HTTP_PORT=9000

# TODO configure spring boot http context = /${ARTIFACT_ID}
# TODO configure java trust store

[ -z ${KEYSTORE+x} ] && export KEYSTORE="file://${ETC_DIR}/keystore.jceks"
echo "- Keystore will be loaded from '${KEYSTORE}'"
[ -z ${SECRET+x} ] && export SECRET="CHANGEME" && echo "WARN: Using default secret '${SECRET}'"

## Java Options
JAVA_OPTS="${JAVA_OPTS} -server"
JAVA_OPTS="${JAVA_OPTS} -Xms${XMS:-32M}"
JAVA_OPTS="${JAVA_OPTS} -Xmx${XMX:-128M}"
# The OnOutOfMemoryError fails the JVM on startup with a message "Unrecognized option: -9"
#JAVA_OPTS="${JAVA_OPTS} -XX:OnOutOfMemoryError='kill -9 %p'"
# Using the new CrashOnOutOfMemoryError option from Java 8u92 instead:
JAVA_OPTS="${JAVA_OPTS} -XX:+CrashOnOutOfMemoryError"
# Clean exit without crash files, probably not what we want
#JAVA_OPTS="${JAVA_OPTS} -XX:+ExitOnOutOfMemoryError"
# We do want a heap dump for further analysis
JAVA_OPTS="${JAVA_OPTS} -XX:+HeapDumpOnOutOfMemoryError"

## Application options
APP_OPTS="${APP_OPTS} -Dlogback.configurationFile=${ETC_DIR}/logback.xml"
APP_OPTS="${APP_OPTS} -Dlogging.config=${ETC_DIR}/logback.xml"
APP_OPTS="${APP_OPTS} -Dconfig.url=${CONFIG}"
APP_OPTS="${APP_OPTS} -Dkeystore.url=${KEYSTORE}"
APP_OPTS="${APP_OPTS} -Dkeystore.password=${SECRET}"
APP_OPTS="${APP_OPTS} -Djwt.secret=${SECRET}"
APP_OPTS="${APP_OPTS} -Dcache.dir=${CACHE_DIR}"

echo "Content of ${ETC_DIR}:"
ls -l ${ETC_DIR}

## Start the Microservice
echo "Bootstrapping finished, starting the ${MICROSERVICE} Microservice..."
exec java ${JAVA_OPTS} ${JMX_OPTS} ${APP_OPTS} -jar ${MICROSERVICE} "${@}"
