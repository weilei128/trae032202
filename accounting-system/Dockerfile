FROM openjdk:11-jre-slim

LABEL app="accountingTest-app" version="1.0.0"

WORKDIR /app

ENV JAVA_OPTS="-Xms256m -Xmx512m"
ENV TZ=Asia/Shanghai

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

COPY GLM.jar app.jar

EXPOSE 10012

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
