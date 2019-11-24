#!/bin/bash
set -e

source ~/.bashrc

echo "listing data directories of $(hostname)"
/bin/ls /opt/hadoop/data

echo "Starting sshd service..."
/etc/init.d/ssh start

echo "Hostname: $(hostname)"
echo $HADOOP_HOME

initHiveSchema() {
  ($HIVE_HOME/bin/schematool -initSchema -ifNotExists -dbType mysql) || {
    return 0
  }
}

if [ "$(hostname)" == 'node-master' ]; then
    HDFS_ALREADY_FORMATTED=$(find "$HADOOP_HOME/data/nameNode" -mindepth 1 -print -quit 2>/dev/null)

    # Checking if HDFS needs to be formated.
    if [ !  $HDFS_ALREADY_FORMATTED ]; then
        echo "FORMATTING NAMENODE"
        $HADOOP_HOME/bin/hdfs namenode -format || { echo 'FORMATTING FAILED' ; exit 1; }
    fi

    echo "Starting HDFS.."
    $HADOOP_HOME/sbin/start-dfs.sh

    # Create non-existing folders
    $HADOOP_HOME/bin/hadoop fs -mkdir -p    /tmp
    $HADOOP_HOME/bin/hadoop fs -mkdir -p    /user/hive/warehouse
    $HADOOP_HOME/bin/hadoop fs -chmod 777   /tmp
    $HADOOP_HOME/bin/hadoop fs -chmod 777   /user/hive/warehouse

    # Create hue directories
    $HADOOP_HOME/bin/hadoop fs -mkdir -p /user/hue
    $HADOOP_HOME/bin/hadoop fs -chmod 777 /user/hue

    echo "Initializing hive..."
    /bin/bash  /opt/apache-hive/bin/init-hive-dfs.sh

    echo "Initializing schemas hive..."
    initHiveSchema

    echo "Starting HIVESERVER.."
    $HIVE_HOME/bin/hive --service hiveserver2 &

    echo "Starting YARN."
    $HADOOP_HOME/sbin/start-yarn.sh

    echo "Starting webhttp hadoop service..."
    $HADOOP_HOME/bin/hdfs httpfs &
fi


while true;
do
  sleep 30;
done;