#!/bin/bash -xe


hadoop_user=hduser
hadoop_version=3.3.0
hive_version=3.1.2
hadoop_home_dir=/usr/local/hadoop
hive_home_dir=/usr/local/hive
derby_home_dir=/usr/local/derby
host=`hostname`
krb_princ_pass=chronos
krb_realm=TEST.COM
krb_realm_lc=`echo "$krb_realm" | tr '[:upper:]' '[:lower:]'`


create_hadoop_user() {
groupadd hadoop
mkdir $hadoop_home_dir
mkdir $hive_home_dir
mkdir -p $derby_home_dir/logs
useradd -d /home/$hadoop_user -g hadoop $hadoop_user
chown -R  $hadoop_user:hadoop $hadoop_home_dir
echo "$hadoop_user:chronos" | sudo chpasswd
}

setup_ssh(){
    hostnamectl set-hostname $host
    ip=`hostname -I`
    echo "$ip $host" >> /etc/hosts
    sed -i 's|PasswordAuthentication no|PasswordAuthentication yes|g' /etc/ssh/sshd_config
    sed -i 's|KerberosAuthentication no|KerberosAuthentication yes|g' /etc/ssh/sshd_config
    service sshd restart
    su - $hadoop_user -c 'ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa <<<y >/dev/null 2>&1'
    su - $hadoop_user -c 'cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys'
    su - $hadoop_user -c 'chmod 0600 ~/.ssh/authorized_keys'
    su - $hadoop_user -c 'echo "
Host *
    StrictHostKeyChecking no" | tee /home/hduser/.ssh/config' >/dev/null
    su - $hadoop_user -c 'chmod 400 ~/.ssh/config' 
}

setup_java() {
setenforce 0
yum install -y java-1.8.0-openjdk wget
cd /tmp
wget https://archive.apache.org/dist/hadoop/common/hadoop-$hadoop_version/hadoop-$hadoop_version.tar.gz
tar -zxf hadoop-$hadoop_version.tar.gz
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
export PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
export HIVE_HOME='$hive_home_dir'
export PATH=$PATH:$HIVE_HOME/bin
export CLASSPATH=$CLASSPATH:/usr/local/hadoop/lib/*:.
export CLASSPATH=$CLASSPATH:/usr/local/hive/lib/*:.
export DERBY_HOME='$derby_home_dir'
export PATH=$PATH:$DERBY_HOME/bin
export CLASSPATH=$CLASSPATH:$DERBY_HOME/lib/derby.jar:$DERBY_HOME/lib/derbytools.jar" | tee ~/.bash_profile > ~/.bashrc'
source /home/hduser/.bashrc
}

cluster_config(){
    mkdir -p $hadoop_home_dir/dfs/name/data/
    chown -R $hadoop_user $hadoop_home_dir/dfs/
echo "<?xml version="'"1.0"'" encoding="'"UTF-8"'"?>
<?xml-stylesheet type="'"text/xsl"'" href="'"configuration.xsl"'"?>
<configuration>
  <property>
    <name>hadoop.tmp.dir</name>
    <value>/tmp</value>
    <description>A base for other temporary directories.</description>
  </property>
  <property>
    <name>fs.default.name</name>
    <value>hdfs://$host:54310</value>
    <description>The name and URI of the default file system.</description>
  </property>

  <property>
    <name>hadoop.security.authentication</name>
    <value>kerberos</value>
    <!-- Giving value as "simple" disables security.-->
  </property>
  <property>
    <name>hadoop.security.authorization</name>
    <value>true</value>
  </property>
   <!-- Allow other users to impersonate hdfs user -->
  <property>
    <name>hadoop.proxyuser.hdfs.groups</name>
    <value>*</value>
  </property>
  <property>
    <name>hadoop.proxyuser.hdfs.hosts</name>
    <value>*</value>
  </property>

  <property>
     <name>hadoop.http.staticuser.user</name>
     <value>hduser</value>
  </property>

</configuration>
" | tee $hadoop_home_dir/etc/hadoop/core-site.xml >/dev/null

echo "<?xml version="'"1.0"'" encoding="'"UTF-8"'"?>
<?xml-stylesheet type="'"text/xsl"'" href="'"configuration.xsl"'"?>
<configuration>
  <property>
    <name>dfs.replication</name>
    <value>1</value>
    <description>Default block replication.</description>
  </property>

  <property>
    <name>ignore.secure.ports.for.testing</name>
    <value>true</value>
  </property>

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
    <name>dfs.webhdfs.enabled</name>
    <value>true</value>
  </property>
  <property>
    <name>dfs.web.authentication.kerberos.principal</name>
    <value>HTTP/$host@$krb_realm</value>
  </property>
  <property>
    <name>dfs.web.authentication.kerberos.keytab</name>
    <value>$hadoop_home_dir/etc/hadoop/hdfs.keytab</value>
  </property>

  <!-- General HDFS security config -->
  <property>
  <name>dfs.block.access.token.enable</name>
  <value>true</value>
  </property>

  <!-- NameNode security config -->
  <property>
    <name>dfs.namenode.keytab.file</name>
    <value>$hadoop_home_dir/etc/hadoop/hdfs.keytab</value>
  </property>
  <property>
    <name>dfs.namenode.kerberos.principal</name>
    <value>hdfs/$host@$krb_realm</value>
  </property>
  <property>
    <name>dfs.namenode.kerberos.https.principal</name>
    <value>hdfs/$host@$krb_realm</value>
  </property>

  <!-- DataNode security config -->
  <property>
    <name>dfs.namenode.datanode.registration.ip-hostname-check</name>
    <value>false</value>
  </property>
  <property>
    <name>dfs.client.use.datanode.hostname</name>
    <value>true</value>
  </property>
  <property>
    <name>dfs.datanode.use.datanode.hostname</name>
    <value>true</value>
  </property>
  <property>
    <name>dfs.datanode.hostname</name>
    <value>$host</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir.perm</name>
    <value>755</value>
  </property>
  <property>
    <name>dfs.datanode.address</name>
    <value>0.0.0.0:9092</value>
  </property>
  <property>
    <name>dfs.datanode.http.address</name>
    <value>0.0.0.0:9042</value>
  </property>
  <property>
    <name>dfs.datanode.keytab.file</name>
    <value>$hadoop_home_dir/etc/hadoop/hdfs.keytab</value>
  </property>
  <property>
    <name>dfs.datanode.kerberos.principal</name>
    <value>hdfs/$host@$krb_realm</value>
  </property>
  <property>
    <name>dfs.web.authentication.kerberos.principal</name>
    <value>hdfs/$host@$krb_realm</value>
  </property>
  <property>
    <name>dfs.client.use.datanode.hostname</name>
    <value>true</value>
  </property>

<property>
  <name>dfs.namenode.rpc-bind-host</name>
  <value>0.0.0.0</value>
  <description>
    The actual address the RPC server will bind to. If this optional address is
    set, it overrides only the hostname portion of dfs.namenode.rpc-address.
    It can also be specified per name node or name service for HA/Federation.
    This is useful for making the name node listen on all interfaces by
    setting it to 0.0.0.0.
  </description>
</property>

<property>
  <name>dfs.namenode.servicerpc-bind-host</name>
  <value>0.0.0.0</value>
  <description>
    The actual address the service RPC server will bind to. If this optional address is
    set, it overrides only the hostname portion of dfs.namenode.servicerpc-address.
    It can also be specified per name node or name service for HA/Federation.
    This is useful for making the name node listen on all interfaces by
    setting it to 0.0.0.0.
  </description>
</property>

<property>
  <name>dfs.namenode.http-bind-host</name>
  <value>0.0.0.0</value>
  <description>
    The actual adress the HTTP server will bind to. If this optional address
    is set, it overrides only the hostname portion of dfs.namenode.http-address.
    It can also be specified per name node or name service for HA/Federation.
    This is useful for making the name node HTTP server listen on all
    interfaces by setting it to 0.0.0.0.
  </description>
</property>

<property>
  <name>dfs.namenode.https-bind-host</name>
  <value>0.0.0.0</value>
  <description>
    The actual adress the HTTPS server will bind to. If this optional address
    is set, it overrides only the hostname portion of dfs.namenode.https-address.
    It can also be specified per name node or name service for HA/Federation.
    This is useful for making the name node HTTPS server listen on all
    interfaces by setting it to 0.0.0.0.
  </description>
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

install_kerboros(){
  yum install -y krb5-workstation krb5-server
  echo "[logging]
default = FILE:/var/log/krb5libs.log
kdc = FILE:/var/log/krb5kdc.log
admin_server = FILE:/var/log/kadmind.log

[libdefaults]
dns_lookup_realm = false
ticket_lifetime = 24h
#renew_lifetime = 7d
forwardable = true
rdns = false
default_realm = $krb_realm

[realms]
$krb_realm = {
  kdc = $host
  admin_server = $host
}

[domain_realm]
.$krb_realm = $krb_realm_lc
$krb_realm = $krb_realm_lc
" | tee /etc/krb5.conf >/dev/null
}


enable_kerberos_perm() {
  setfacl -R -m user:$hadoop_user:rwx /var/kerberos/
  setfacl -R -m user:$hadoop_user:rwx /var/log/
  echo "*/admin@$krb_realm   *
hduser@$krb_realm    *
hdfs/*@$krb_realm    *
HTTP/*@$krb_realm    *
" | tee /var/kerberos/krb5kdc/kadm5.acl >/dev/null
}
create_kerberos_principals() {
  su - $hadoop_user -c 'kdb5_util create -P chronos –r '$krb_realm' -s'
  enable_kerberos_perm
  service krb5kdc start
  service kadmin start
  sleep 10
echo "/sbin/kadmin.local -q "'"addprinc -pw chronos root/admin"'"
/sbin/kadmin.local -q "'"addprinc -pw chronos hduser/admin"'"
/sbin/kadmin.local -q "'"addprinc -pw chronos hdfs/'$host'"'"
/sbin/kadmin.local -q "'"addprinc -pw chronos HTTP/'$host'"'"
/sbin/kadmin.local -q "'"addprinc -pw chronos HTTP/0.0.0.0"'"
/sbin/kadmin.local -q "'"addprinc -pw chronos hdfs/0.0.0.0"'"
/sbin/kadmin.local -q "'"addprinc -pw chronos hdfs/localhost"'"
/sbin/kadmin.local -q "'"addprinc -pw chronos '$hadoop_user'"'"
/sbin/kadmin.local -q "'"addprinc -pw chronos root"'"
/sbin/kadmin.local ktadd -norandkey -k $hadoop_home_dir/etc/hadoop/hdfs.keytab root/admin hduser/admin hdfs/$host hdfs/localhost HTTP/$host hdfs/0.0.0.0 HTTP/0.0.0.0 $hadoop_user root" | tee /tmp/krb_princ.sh >/dev/null
chmod 775 /tmp/krb_princ.sh
su - $hadoop_user -c '/tmp/krb_princ.sh'
service krb5kdc restart
service kadmin restart
}

hive_install() {
  cd /tmp
  wget https://downloads.apache.org/hive/hive-$hive_version/apache-hive-$hive_version-bin.tar.gz
  tar -xf apache-hive-$hive_version-bin.tar.gz
  cp -r apache-hive-$hive_version-bin/* $hive_home_dir/
  rm -f $hive_home_dir/lib/guava-*.jar
  cp -rf $hadoop_home_dir/share/hadoop/hdfs/lib/guava* $hive_home_dir/lib/
  chown -R hduser:hadoop  $hive_home_dir/
  wget http://archive.apache.org/dist/db/derby/db-derby-10.4.2.0/db-derby-10.4.2.0-bin.tar.gz
  tar -xf db-derby-10.4.2.0-bin.tar.gz
  cp -r db-derby-10.4.2.0-bin/* $derby_home_dir/
  chown -R hduser:hadoop  $derby_home_dir/  

echo "<?xml version="'"1.0"'" encoding="'"UTF-8"'"?>
<?xml-stylesheet type="'"text/xsl"'" href="'"configuration.xsl"'"?>
<configuration>
    <property>
        <name>hive.server2.thrift.port</name>
        <value>10000</value>
    </property>
    <property>
        <name>hive.root.logger</name>
        <value>INFO,console</value>
    </property>
    <property>
        <name>hive.server2.authentication.kerberos.keytab</name>
        <value>$hadoop_home_dir/etc/hadoop/hdfs.keytab</value>
    </property>
    <property>
        <name>hive.server2.authentication.kerberos.principal</name>
        <value>hdfs/$host@$krb_realm</value>
    </property>
    <property>
        <name>hive.server2.authentication</name>
        <value>KERBEROS</value>
    </property>

</configuration>" | tee $hive_home_dir/conf/hive-site.xml >/dev/null

echo "<?xml version="'"1.0"'" encoding="'"UTF-8"'"?>
<?xml-stylesheet type="'"text/xsl"'" href="'"configuration.xsl"'"?>
<configuration>

    <!-- Site specific YARN configuration properties -->
    <property>
        <name>yarn.nodemanager.principal</name>
        <value>hdfs/$host@$krb_realm</value>
    </property>
    <property>
        <name>yarn.resourcemanager.principal</name>
        <value>hdfs/$host@$krb_realm</value>
    </property>
    <property>
        <name>yarn.nodemanager.keytab</name>
        <value>$hadoop_home_dir/etc/hadoop/hdfs.keytab</value>
    </property>
    <property>
        <name>yarn.resourcemanager.keytab</name>
        <value>/$hadoop_home_dir/etc/hadoop/hdfs.keytab</value>
    </property>

</configuration>" | tee $hadoop_home_dir/etc/hadoop/yarn-site.xml >/dev/null



}

start_cluster() {
    chown -R $hadoop_user $hadoop_home_dir/dfs/
    su - $hadoop_user -c 'y | hdfs namenode -format'
    sleep 10
    su - $hadoop_user -c ''$hadoop_home_dir'/sbin/start-dfs.sh'
    su - $hadoop_user -c '/usr/local/derby/bin/startNetworkServer -noSecurityManager -h '$host' > /usr/local/derby/logs/server.log &'
    su - $hadoop_user -c ''$hive_home_dir'/bin/schematool -initSchema -dbType derby'
    su - $hadoop_user -c ''$hive_home_dir'/bin/schematool -dbType derby -info'
    su - $hadoop_user -c ''$hadoop_home_dir'/sbin/start-yarn.sh'
    cd $hive_home_dir/bin/
    su - $hadoop_user -c 'nohup '$hive_home_dir'/bin/hive --service hiveserver2 --hiveconf hive.root.logger=INFO,console > /dev/null 2>&1 &'
    #sleep 60 && netstat -tulpn | grep 10000

}

create_qa_data() {
su - $hadoop_user -c 'kinit -k -t /usr/local/hadoop/etc/hadoop/hdfs.keytab hdfs/hadoop2.novalocal.com@TEST.COM'
su - $hadoop_user -c 'hdfs dfs -mkdir -p /user/hduser/test/'
su - $hadoop_user -c 'hdfs dfs -chown -R hduser:hadoop /user/hduser/'
su - $hadoop_user -c 'hdfs dfs -chmod -R 775 /user/hduser/'
su - $hadoop_user -c 'hdfs dfs -ls /user/hduser/test/'

#/tmp/hive-data-generator.sh simpletable 5000 hdfs/hadoop2.novalocal.com@TEST.COM
}

create_hadoop_user
setup_ssh
setup_java
hadoop_user_path
cluster_config
install_kerboros
enable_kerberos_perm
create_kerberos_principals
hive_install
start_cluster
create_qa_data