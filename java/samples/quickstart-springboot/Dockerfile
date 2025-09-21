ARG JDK_VERSION=11
FROM eclipse-temurin:${JDK_VERSION}-jre as runtime

WORKDIR /workspace
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 mvn -q -e -B dependency:go-offline
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -q -e -B package -DskipTests

FROM eclipse-temurin:${JDK_VERSION}-jre
WORKDIR /app
COPY --from=runtime /workspace/target/demo-0.0.1-SNAPSHOT.jar app.jar
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]