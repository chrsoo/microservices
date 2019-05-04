FROM openjdk:8-jdk-alpine

ENV SVC_HOME=/opt/microservice
ENV SVC_ETC=${SVC_HOME}/etc SVC_LIB=${SVC_HOME}/lib SVC_CACHE=/var/cache/microservice BOOTSTRAP=${SVC_HOME}/bootstrap.sh

RUN addgroup --system microservice \
    && adduser --system --ingroup microservice --home $SVC_HOME microservice

ADD src/files ${SVC_ETC}/
ADD bootstrap.sh ${BOOTSTRAP}

RUN mkdir -p $SVC_LOG $SVC_CACHE $SVC_ETC \
    && chown -R microservice:microservice $SVC_LOG $SVC_CACHE $SVC_HOME \
    && chmod +x ${BOOTSTRAP}

USER microservice

ONBUILD ARG JAR_FILE

ONBUILD ARG ARTIFACT_ID
ONBUILD ARG GROUP_ID
ONBUILD ARG VERSION

ONBUILD ARG name=$ARTIFACT_ID
ONBUILD ARG description="unknown"
ONBUILD ARG usage="/README.md"
ONBUILD ARG url="unknnown"
ONBUILD ARG vcs_url="unknown"
ONBUILD ARG vcs_branch="unknown"
ONBUILD ARG vcs_ref="unknown"
ONBUILD ARG build_date="unknown"

ONBUILD LABEL org.label-schema.vendor="My Company" \
    org.label-schema.name=$name \
    org.label-schema.description=$description \
    org.label-schema.usage=$usage \
    org.label-schema.url=$url \
    org.label-schema.vcs-url=$vcs_url\
    org.label-schema.vcs-branch=$vcs_branch \
    org.label-schema.vcs-ref=$vcs_ref\
    org.label-schema.version=$VERSION \
    org.label-schema.schema-version="1.0" \
    org.label-schema.build-date=$build_date \
    java.version=${JAVA_VERSION} \
    java.alpine.version=${JAVA_ALPINE_VERSION}

ONBUILD ENV \
    ARTIFACT_ID=${ARTIFACT_ID} \
    GROUP_ID=${GROUP_ID} \
    VERSION=${VERSION} \
    LOG_LEVEL=INFO \
    CACHE_DIR=${SVC_CACHE}/${ARTIFACT_ID} \
    ETC_DIR=${SVC_ETC}/${ARTIFACT_ID} \
    MICROSERVICE=${SVC_HOME}/${JAR_FILE}

ONBUILD ADD target/lib ${SVC_LIB}/
ONBUILD ADD target/${JAR_FILE} ${MICROSERVICE}

# HTTP
ONBUILD EXPOSE 9000
# JMX
ONBUILD EXPOSE 8181

ONBUILD ENTRYPOINT ["/opt/microservice/bootstrap.sh"]
