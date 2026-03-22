FROM openjdk:8-jre-alpine

WORKDIR /app

COPY dogFooding.jar /app/app.jar

# 安装必要工具和时区数据
RUN apk add --no-cache tzdata curl

# 设置时区为 Asia/Shanghai
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 暴露服务端口
EXPOSE 10011

# 启动命令（直接指定JVM参数）
ENTRYPOINT java -Xms256m -Xmx512m -jar app.jar
