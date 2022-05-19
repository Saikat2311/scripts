#!/bin/bash


hadoop_user=hduser
hadoop_version=2.7.7
hadoop_home_dir=/usr/local/hadoop
host=`hostname`

create_hadoop_user() {
groupadd hadoop
mkdir $hadoop_home_dir
useradd -d /home/$hadoop_user -g hadoop $hadoop_user
chown -R  $hadoop_user:hadoop $hadoop_home_dir
passwd $hadoop_user
}

setup_ssh(){
    su - $hadoop_user -c 'ssh-keygen -t rsa'
    su - $hadoop_user -c 'cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys'
    su - $hadoop_user -c 'chmod 0600 ~/.ssh/authorized_keys'
}

setup_java() {
yum install -y java-1.8.0-openjdk
cd /tmp
wget http://www-us.apache.org/dist/hadoop/common/hadoop-$hadoop_version/hadoop-$hadoop_version.tar.gz
tar -zxvf hadoop-$hadoop_version.tar.gz
cp -R hadoop-$hadoop_version/* $hadoop_home_dir
chown -R $hadoop_user $hadoop_home_dir/
sed -i '/export JAVA_HOME=/c\export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")' $hadoop_home_dir/etc/hadoop/hadoop-env.sh
echo "export PATH=$hadoop_home_dir/bin:$PATH" | sudo tee -a /etc/profile
source /etc/profile
}

hadoop_user_path() {
    su - $hadoop_user -c 'echo "
export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")
export HADOOP_HOME='$hadoop_home_dir'
export HADOOP_CONF_DIR='$hadoop_home_dir'/etc/hadoop
export PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin" | tee ~/.bash_profile > ~/.bashrc'
source /home/hduser/.bashrc

su - $hadoop_user -c 'echo "
Host *
    StrictHostKeyChecking no" | tee /home/hduser/.ssh/config'
su - $hadoop_user -c 'chmod 400 ~/.ssh/config'    
}
cluster_config(){
    mkdir -p $hadoop_home_dir/dfs/name/data/
echo "<?xml version="'"1.0"'" encoding="'"UTF-8"'"?>
<?xml-stylesheet type="'"text/xsl"'" href="'"configuration.xsl"'"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->

<configuration>
<property>
    <name>fs.default.name</name>
    <value>hdfs://$host:9000/</value>
</property>
<property>
    <name>dfs.permissions</name>
    <value>false</value>
</property>
</configuration>" | tee $hadoop_home_dir/etc/hadoop/core-site.xml >/dev/null

echo "<?xml version="'"1.0"'" encoding="'"UTF-8"'"?>
<?xml-stylesheet type="'"text/xsl"'" href="'"configuration.xsl"'"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->

<configuration>
<property>
	<name>dfs.data.dir</name>
	<value>$hadoop_home_dir/dfs/name/data</value>
	<final>true</final>
</property>
<property>
	<name>dfs.name.dir</name>
	<value>$hadoop_home_dir/dfs/name</value>
	<final>true</final>
</property>
<property>
	<name>dfs.replication</name>
	<value>1</value>
</property>
</configuration>" | tee $hadoop_home_dir/etc/hadoop/hdfs-site.xml >/dev/null

echo "<?xml version="'"1.0"'" encoding="'"UTF-8"'"?>
<?xml-stylesheet type="'"text/xsl"'" href="'"configuration.xsl"'"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->

<configuration>
<property>
        <name>mapred.job.tracker</name>
	<value>$host:9001</value>
</property>
</configuration>" | tee $hadoop_home_dir/etc/hadoop/mapred-site.xml >/dev/null
}

start_cluster() {
    chown -R $hadoop_user /opt/hadoop/dfs/
    su - $hadoop_user -c 'hdfs namenode -format'
    su - $hadoop_user -c ''$hadoop_home_dir'/sbin/start-dfs.sh'
}


create_hadoop_user
setup_ssh
setup_java
hadoop_user_path
cluster_config
#start_cluster