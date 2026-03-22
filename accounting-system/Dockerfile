FROM openjdk:11-jre-slim

LABEL maintainer="accounting-app"
LABEL version="1.0.0"
LABEL description="Accounting System Application"

WORKDIR /app

COPY kimi.jar app.jar

EXPOSE 10013

ENV JAVA_OPTS="-Xms256m -Xmx512m"
ENV SERVER_PORT=10013

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:10013/actuator/health || exit 1

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -Djava.security.egd=file:/dev/./urandom -jar app.jar --server.port=$SERVER_PORT"]
