FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 \
    HADOOP_VERSION=2.7.6 \
    HIVE_VERSION=2.3.7 \
    HADOOP_HOME=/opt/hadoop \
    HIVE_HOME=/opt/hive \
    SQOOP_HOME=/opt/sqoop

ENV PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$HIVE_HOME/bin:$SQOOP_HOME/bin

RUN sed -i 's|http://archive.ubuntu.com/ubuntu/|http://mirrors.aliyun.com/ubuntu/|g; s|http://security.ubuntu.com/ubuntu/|http://mirrors.aliyun.com/ubuntu/|g' /etc/apt/sources.list \
    && apt-get update && apt-get install -y --no-install-recommends \
      openjdk-8-jdk-headless curl ca-certificates procps netcat-openbsd default-mysql-client gettext-base \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fSL "https://mirrors.huaweicloud.com/apache/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz" -o /tmp/hadoop.tgz \
    && tar -xzf /tmp/hadoop.tgz -C /opt \
    && mv "/opt/hadoop-${HADOOP_VERSION}" "${HADOOP_HOME}" \
    && rm /tmp/hadoop.tgz

RUN curl -fSL "https://mirrors.huaweicloud.com/apache/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz" -o /tmp/hive.tgz \
    && tar -xzf /tmp/hive.tgz -C /opt \
    && mv "/opt/apache-hive-${HIVE_VERSION}-bin" "${HIVE_HOME}" \
    && rm /tmp/hive.tgz

COPY packages/sqoop-1.4.7.bin__hadoop-2.6.0.tar.gz /tmp/sqoop.tgz
RUN tar -xzf /tmp/sqoop.tgz -C /opt \
    && mv /opt/sqoop-1.4.7.bin__hadoop-2.6.0 "${SQOOP_HOME}" \
    && rm /tmp/sqoop.tgz

COPY packages/mysql-connector-java-5.1.49.jar "${SQOOP_HOME}/lib/"
COPY packages/mysql-connector-java-5.1.49.jar "${HIVE_HOME}/lib/"

COPY conf/core-site.xml "${HADOOP_HOME}/etc/hadoop/core-site.xml"
COPY conf/hdfs-site.xml "${HADOOP_HOME}/etc/hadoop/hdfs-site.xml"
COPY conf/mapred-site.xml "${HADOOP_HOME}/etc/hadoop/mapred-site.xml"
COPY conf/hive-env.sh "${HIVE_HOME}/conf/hive-env.sh"
COPY conf/sqoop-env.sh "${SQOOP_HOME}/conf/sqoop-env.sh"
COPY conf/hive-site.xml.template "${HIVE_HOME}/conf/hive-site.xml.template"

RUN mkdir -p /opt/hadoop/tmp /opt/hadoop/data/name /opt/hadoop/data/data /data /var/log/edu-dw \
    && chmod +x "${HIVE_HOME}/conf/hive-env.sh"

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 9000 50070 9083 10000
VOLUME ["/data"]
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]