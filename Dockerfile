FROM 979668027692.dkr.ecr.ap-south-1.amazonaws.com/maven:3.9.5-openjdk-21-slim as builder

RUN mkdir -p /root/.m2 \
    && mkdir /root/.m2/repository

# Copy local code to the container image.
WORKDIR /app
COPY settings.xml /root/.m2
COPY pom.xml ./
COPY src ./src/
ARG CODEARTIFACT_AUTH_TOKEN
ARG DOMAIN
ARG REPO
ARG REPO_URL
ENV CODEARTIFACT_AUTH_TOKEN=${CODEARTIFACT_AUTH_TOKEN}
ENV DOMAIN=${DOMAIN}
ENV REPO=${REPO}
ENV REPO_URL=${REPO_URL}

# Build a release artifact.
RUN mvn package -DskipTests
RUN mvn sonar:sonar -Dsonar.login=squ_e3a08af5d87a5f71766fa133809b0187e8edaa3d

# Use AdoptOpenJDK for base image
# It's important to use OpenJDK 8u191 or above that has container support enabled.
# https://hub.docker.com/r/adoptopenjdk/openjdk8
# https://docs.docker.com/develop/develop-images/multistage-build/#use-multi-stage-builds
FROM 979668027692.dkr.ecr.ap-south-1.amazonaws.com/openjdk:21-alpine3.18-jdk

ENV S3_BUCKET=${S3_BUCKET}
ENV AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
ENV AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
ENV S3_REGION=${S3_REGION}
ENV MOUNT_POINT '/var/s3'
ENV S3_ACL 'private'
ENV IAM_ROLE none
ARG S3FS_VERSION=v1.93

VOLUME /var/s3

RUN apk --update add fuse alpine-sdk automake autoconf libxml2-dev fuse-dev curl-dev git bash;
RUN git clone https://github.com/s3fs-fuse/s3fs-fuse.git; \
 cd s3fs-fuse; \
 git checkout tags/${S3FS_VERSION}; \
 ./autogen.sh; \
 ./configure --prefix=/usr; \
 make; \
 make install; \
 rm -rf /var/cache/apk/*;

COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]


ENV JAVA_HOME=/opt/openjdk-18/bin
# Copy the jar to the production image from the builder stage
COPY --from=builder /app/target/business-master-service*.jar /business-master-service.jar
# Run the web service on container startup.
CMD ["java", "-Dliquibase.secureParsing=false", "-Djava.security.egd=file:/dev/./urandom", "-Djava.awt.headless=true", "-jar", "/business-master-service.jar"]
