#!/bin/bash

# Oracle DB INSTALLATION
# Define the variables

data_path=/data
oracle_pass=Symbol12!
project_name=test
installation_file=linuxx64_12201_database.zip
oracle_version=12.2.0
gdbName=test
SID=test
pdbName=test_OLTP

kernel_params() {
    echo "
fs.file-max = 6815744
kernel.sem = 250 32000 100 128
kernel.shmmni = 4096
kernel.shmall = 1073741824
kernel.shmmax = 4398046511104
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
fs.aio-max-nr = 1048576
net.ipv4.ip_local_port_range = 9000 65500
kernel.panic_on_oops = 1" >> /etc/sysctl
    /sbin/sysctl -p
}
security_limits() {
    echo "
oracle   soft   nofile    1024
oracle   hard   nofile    65536
oracle   soft   nproc    2047
oracle   hard   nproc    16384
oracle   soft   stack    10240
oracle   hard   stack    32768" >> /etc/security/limits.conf
}
dependencies() {
    yum install binutils -y
    yum install compat-libcap1 -y
    yum install compat-libstdc++-33 -y
    yum install compat-libstdc++-33.i686 -y
    yum install gcc -y
    yum install gcc-c++ -y
    yum install glibc -y
    yum install glibc.i686 -y
    yum install glibc-devel -y
    yum install glibc-devel.i686 -y
    yum install ksh -y
    yum install libgcc -y
    yum install libgcc.i686 -y
    yum install libstdc++ -y
    yum install libstdc++.i686 -y
    yum install libstdc++-devel -y
    yum install libstdc++-devel.i686 -y
    yum install libaio -y
    yum install libaio.i686 -y
    yum install libaio-devel -y
    yum install libaio-devel.i686 -y
    yum install libXext -y
    yum install libXext.i686 -y
    yum install libXtst -y
    yum install libXtst.i686 -y
    yum install libX11 -y
    yum install libX11.i686 -y
    yum install libXau -y
    yum install libXau.i686 -y
    yum install libxcb -y
    yum install libxcb.i686 -y
    yum install libXi -y
    yum install libXi.i686 -y
    yum install make -y
    yum install sysstat -y
    yum install unixODBC -y
    yum install unixODBC-devel -y
    yum update -y
}
selinux() {
    echo "
# This file controls the state of SELinux on the system.
# SELINUX= can take one of these three values:
#     enforcing - SELinux security policy is enforced.
#     permissive - SELinux prints warnings instead of enforcing.
#     disabled - No SELinux policy is loaded.
SELINUX=disabled
# SELINUXTYPE= can take one of three values:
#     targeted - Targeted processes are protected,
#     minimum - Modification of targeted policy. Only selected processes are protected.
#     mls - Multi Level Security protection.
SELINUXTYPE=disabled" | tee /etc/selinux/config > /dev/null
    setenforce disabled
}
oracle_user_creation() {
    groupadd -g 54321 oinstall
    groupadd -g 54322 dba
    groupadd -g 54323 oper
    useradd -u 54321 -g oinstall -G dba,oper oracle
    echo "oracle:$oracle_pass" | chpasswd
    echo "
# Default limit for number of user's processes to prevent
# accidental fork bombs.
# See rhbz #432903 for reasoning.
*          -    nproc     16384
root       soft    nproc     unlimited" | tee /etc/security/limits.d/20-nproc.conf > /dev/null
}
oracle_directory_creation() {
    mkdir -p /u01/app/oracle/product/$oracle_version/dbhome_1
    chown -R oracle:oinstall /u01
    chmod -R 775 /u01
}
oracle_user_path() {
    su - oracle -c 'echo "
#Oracle Settings
export TMP=/tmp
export TMPDIR=$TMP
export ORACLE_HOSTNAME=localhost.localdomain
export ORACLE_UNQNAME=DMIP
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/'$oracle_version'/dbhome_1
export ORACLE_SID=DMIP
export PATH=/usr/sbin:/u01/app/oracle/product/'$oracle_version'/dbhome_1/bin/
export PATH=/usr/sbin:/u01/app/oracle/product/'$oracle_version'/dbhome_1/bin/:$PATH
export LD_LIBRARY_PATH=/u01/app/oracle/product/'$oracle_version'/dbhome_1/lib:/lib:/usr/lib
export CLASSPATH=/u01/app/oracle/product/'$oracle_version'/dbhome_1/jlib:/u01/app/oracle/product/'$oracle_version'/dbhome_1/rdbms/jlib" | tee -a /home/oracle/.bash_profile >> /home/oracle/.bashrc'
}
oracle_installation(){
    cd /tmp
    unzip $installation_file
    chown -R oracle:oinstall database
    su - oracle -c 'echo "
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v'$oracle_version'
oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=/u01/app/oraInventory
ORACLE_HOME=/u01/app/oracle/product/'$oracle_version'/dbhome_1
ORACLE_BASE=/u01/app/oracle
oracle.install.db.InstallEdition=EE
oracle.install.db.OSDBA_GROUP=dba
oracle.install.db.OSOPER_GROUP=oper
oracle.install.db.OSBACKUPDBA_GROUP=dba
oracle.install.db.OSDGDBA_GROUP=dba
oracle.install.db.OSKMDBA_GROUP=dba
oracle.install.db.OSRACDBA_GROUP=dba
SECURITY_UPDATES_VIA_MYORACLESUPPORT=false
DECLINE_SECURITY_UPDATES=true
oracle.install.db.config.starterdb.globalDBName='$project_name'
oracle.install.db.config.starterdb.SID='$project_name'" | tee /tmp/database/response/db.rsp >/dev/null'
    cd /tmp/database/
    su - oracle -c "/tmp/database/runInstaller -silent -responseFile /tmp/database/response/db.rsp"
    sleep 180
    /u01/app/oraInventory/orainstRoot.sh
    /u01/app/oracle/product/$oracle_version/dbhome_1/root.sh
}
oracle_network_config() {
    su - oracle -c "mv /u01/app/oracle/product/12.2.0/dbhome_1/rdbms/lib/config.o /u01/app/oracle/product/12.2.0/dbhome_1/rdbms/lib/config.bad"
    su - oracle -c "relink all"
    sleep 15
    su - oracle -c 'cat << 'EOF' > /tmp/database/response/netca.rsp
[GENERAL]
RESPONSEFILE_VERSION="12.2"
CREATE_TYPE="CUSTOM"
[oracle.net.ca]
INSTALLED_COMPONENTS={"server","net8","javavm"}
INSTALL_TYPE=""typical""
LISTENER_NUMBER=1
LISTENER_NAMES={"LISTENER"}
LISTENER_PROTOCOLS={"TCP;1521"}
LISTENER_START=""LISTENER""
NAMING_METHODS={"TNSNAMES","ONAMES","HOSTNAME"}
NSN_NUMBER=1
NSN_NAMES={"EXTPROC_CONNECTION_DATA"}
NSN_SERVICE={"PLSExtProc"}
NSN_PROTOCOLS={"TCP;HOSTNAME;1521"}
EOF
'
    su - oracle -c "netca -silent -responseFile /tmp/database/response/netca.rsp"
}
oracle_listener() {
    ht=`hostname`
    sleep 60
    su - oracle -c 'echo "
# listener.ora Network Configuration File: /u01/app/oracle/product/'$oracle_version'/dbhome_1/network/admin/listener.ora
# Generated by Oracle configuration tools.

LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = '$ht')(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )" | tee /u01/app/oracle/product/'$oracle_version'/dbhome_1/network/admin/listener.ora >/dev/null'
    
    su - oracle -c "lsnrctl stop LISTENER"
    sleep 10
    su - oracle -c "lsnrctl start LISTENER"
}
oracle_db_setup() {
    mkdir $data_path/flash_recovery_area/
    chown -R oracle:oinstall /$data_path
    su - oracle -c 'echo "
gdbName='$gdbName'
sid='$SID'
createAsContainerDatabase=true
numberOfPDBs=1
pdbName='$pdbName'
pdbAdminPassword='$oracle_pass'
templateName=General_Purpose.dbc
sysPassword='$oracle_pass'
systemPassword='$oracle_pass'
emConfiguration=DBEXPRESS
emExpressPort=5500
dbsnmpPassword='$oracle_pass'
datafileDestination='$data_path'
recoveryAreaDestination='$data_path'/flash_recovery_area
storageType=FS
characterSet=AL32UTF8
nationalCharacterSet=AL16UTF16
listeners=LISTENER
sampleSchema=FALSE
databaseType=OLTP
automaticMemoryManagement=FALSE
totalMemory=20000" | tee /tmp/database/response/dbca_new.rsp > /dev/null'
    su - oracle -c "relink all"
    su - oracle -c "dbca -silent -createDatabase -responseFile /tmp/database/response/dbca_new.rsp"
}


sql_script() {
    su - oracle -c 'echo -e "
/$"ORACLE_HOME"/bin/sqlplus '"'/as sysdba'"' << EOF
whenever sqlerror exit sql.sqlcode
set echo off
set heading off

prompt =================================
prompt *** Changing Parameter Values ***
prompt =================================
@/tmp/database/response/config.sql

exit
EOF
" | tee /tmp/database/response/config_db.sh > /dev/null'
    chmod u+x config_db.sh
}

oracle_db_config() {
    su - oracle -c 'echo -e "
alter system set max_string_size = extended  scope=spfile;

alter system set client_result_cache_size=2G scope=spfile;

alter system set open_cursors=1000 scope=both;

shutdown immediate

startup upgrade

alter pluggable database '$pdbName' open upgrade;

alter session set container=PDB$"SEED";

@?/rdbms/admin/utl32k.sql

alter session set container='$pdbName';

@?/rdbms/admin/utl32k.sql

alter session set container=CDB$"ROOT";

@?/rdbms/admin/utl32k.sql

CREATE OR REPLACE TRIGGER open_pdbs
  AFTER STARTUP ON DATABASE
BEGIN
   EXECUTE IMMEDIATE '"'ALTER PLUGGABLE DATABASE ALL OPEN'"';
END open_pdbs;
/

shutdown immediate

startup

EXIT; " | tee /tmp/database/response/config.sql > /dev/null'

      su - oracle -c "/tmp/database/response/config_db.sh"
}

### Setting up the kernerl parameters
echo "Setting up the kernerl parameters"
kernel_params

###Setting up the security limits
echo "Setting up the security limits"
security_limits

###Setting up the dependencies
echo "Setting up the dependencies"
dependencies

### Setting up the selinux 
echo "Setting up the selinux"
selinux

### Setting up oracle user
echo "Setting up oracle user"
oracle_user_creation

### Setting up oracle directory and permission
echo "Setting up oracle directory and permission"
oracle_directory_creation
oracle_user_path

### Installing Oracle Database Server
echo "Installing Oracle Database Server"
oracle_installation

### Setting up Oracle DB Network
echo "Setting up Oracle DB Network"
oracle_network_config

### Setting up Oracle DB Listner
echo "Setting up Oracle DB Listner"
oracle_listener

### Creating Databases
echo "Creating Databases"
oracle_db_setup

### Configuring Databases
echo "Configuring Databases"
sql_script
oracle_db_config

echo " Oracle Database Installation is Complete"
