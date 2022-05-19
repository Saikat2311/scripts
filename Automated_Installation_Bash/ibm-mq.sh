#========================================================================================
# INSTALLATION
#========================================================================================

public_dns=`ec2-metadata --public-hostname | cut -f2- -d: | xargs`
public-ip=`ec2-metadata --public-ipv4 | cut -f2- -d: | xargs`
tar -xvf WSMQ_9.0.0.4_TRIAL_LNX_ON_X86_64_.tar.gz
cd /apps/MQServer
./mqlicense.sh -text_only
rpm -ivh MQSeries*.rpm

# Default install location is /opt/mqm
/opt/mqm/bin/setmqinst -i -p /opt/mqm

# switch to MQADMIN user
su mqm

cd /opt/mqm/bin
crtmqm -u SYSTEM.DEAD.LETTER.QUEUE TESTQueueManager
strmqm TESTQueueManager
runmqsc TESTQueueManager
# copy the below commands on the same window without exiting the previous command.
DEFINE LISTENER(TEST.LDAP.TCP.LISTENER) TRPTYPE(TCP) CONTROL(QMGR) PORT(1414)
START LISTENER(TEST.LDAP.TCP.LISTENER)
DEFINE CHANNEL(TESTMQ.CHANNEL) CHLTYPE(SVRCONN) SHARECNV(10)

#DEFINE LOCAL QUEUE
DEFINE QLOCAL('TESTQUEUE.QL')
DEFINE CHANNEL(TESTMQ.CHANNEL) CHLTYPE(CLNTCONN) TRPTYPE(TCP) CONNAME('$public-ip') QMNAME('TESTQueueManager')
END

#============================================================================================
# LDAP SECURITY
#============================================================================================
runmqsc TESTQueueManager
DEFINE AUTHINFO('USE.LDAP') AUTHTYPE(IDPWLDAP) CONNAME('$public-ip(1389)') SHORTUSR('uid') BASEDNU('ou=People,dc=test,dc=com') CHCKCLNT(OPTIONAL) CHCKLOCL(OPTIONAL) CLASSUSR('person') SECCOMM(NO)
SET CHLAUTH(TESTMQ.CHANNEL) TYPE(ADDRESSMAP) ADDRESS(*) USERSRC(CHANNEL)
SET CHLAUTH(TESTMQ.CHANNEL) TYPE(BLOCKUSER) USERLIST('nobody')
ALTER QMGR CONNAUTH(USE.LDAP)
REFRESH SECURITY TYPE(CONNAUTH)
DISPLAY QMSTATUS ALL
END


# Exit the comamnd and switch to root.
# Add group - TESTmqusers
groupadd TESTmqusers

# Add users to the system under TESTmqusers group.
useradd -G TESTmqusers qaroot3

# Switch to mqm user
# Run the below command to assign authorization to the user to access queue manager and queue with all permissions indicated by +all. Read MQ documentation on authorization details.
/opt/mqm/bin/setmqaut -m TESTQueueManager -t qmgr -g TESTmqusers -p qaroot3 +all
/opt/mqm/bin/setmqaut -m TESTQueueManager -t q -n TESTQUEUE.QL -g TESTmqusers -p qaroot3 +all


# Run the below command to check if the user can access the queue manager. (TEST - host on which the MQ Server is installed)
# The below command should give after entering the password. If you get other than this check the /var/mqm/errors folder containing logs.
# bash-4.1$ /opt/mqm/samp/bin/amqscnxc -u qaroot1 TESTQueueManager
#	Sample AMQSCNXC start
#	Connecting to queue manager TESTQueueManager
#	with no client connection information specified.
#	Enter password: qaroot1234@
#	Connection established to queue manager TESTQueueManager
#	Sample AMQSCNXC end

export MQSERVER="TESTMQ.CHANNEL/TCP/simulator.novalocal.com(1414)"
/opt/mqm/samp/bin/amqscnxc -u qaroot3 TESTQueueManager

#============================================================================================

#============================================================================================
 DISABLE SECURITY
#============================================================================================
runmqsc TESTQueueManager
ALTER QMGR CHLAUTH(DISABLED)
ALTER AUTHINFO(SYSTEM.DEFAULT.AUTHINFO.IDPWOS) AUTHTYPE(IDPWOS) CHCKCLNT(OPTIONAL)
ALTER CHL(TESTMQ.CHANNEL) CHLTYPE(SVRCONN) MCAUSER('mqm')
REFRESH SECURITY TYPE(CONNAUTH)
#============================================================================================

#============================================================================================
CONFIGURE JMS QUEUE CONNECTION FACTORY - WITH LDAP CONNECTION FACTORY.
Edit TESTMQ LDAP HOST and BASEDN details.
#============================================================================================
#Log in as root
cd /opt/mqm/java/bin/
./setjmsenv
./JMSAdmin -cfg /tools/TESTMQLdap.config
DISPLAY CTX
DEFINE QCF(TESTCONNFACTORY) TRAN(CLIENT) HOST(simulator.novalocal.com) CHAN(TESTMQ.CHANNEL) QMGR(TESTQueueManager) CROPT(QMGR) CRT(600)
DEFINE QCF(TESTCONNFACTORY_NO_RECONNECT) TRAN(CLIENT) HOST(simulator.novalocal.com) CHAN(TESTMQ.CHANNEL) QMGR(TESTQueueManager)
DEFINE Q(TESTQUEUE) QUEUE(TESTQUEUE.QL) QMGR(TESTQueueManager)
DISPLAY CTX
END

#========================================================================================

#============================================================================================
CONFIGURE JMS QUEUE CONNECTION FACTORY - WITH FILE BASED CONNECTION FACTORY.
Edit TESTMQ LDAP HOST and BASEDN details.
#============================================================================================
#Log in as root
cd /opt/mqm/java/bin/
./setjmsenv
./JMSAdmin -cfg /tools/TESTMQFile.config
DISPLAY CTX
DEFINE QCF(FTESTCONNFACTORY) TRAN(CLIENT) HOST(simulator.novalocal.com) CHAN(TESTMQ.CHANNEL) QMGR(TESTQueueManager) CROPT(QMGR) CRT(600)
DEFINE QCF(FTESTCONNFACTORY_NO_RECONNECT) TRAN(CLIENT) HOST(simulator.novalocal.com) CHAN(TESTMQ.CHANNEL) QMGR(TESTQueueManager)
DEFINE Q(TESTQUEUE) QUEUE(TESTQUEUE.QL) QMGR(TESTQueueManager)
DISPLAY CTX
END

#========================================================================================


# UNINSTALLATION
#========================================================================================
# switch to user mqm
dspmq -o installation
endmqlsr -m TESTQueueManager -w
endmqm TESTQueueManager
endmqm -r TESTQueueManager
exit

#login as root
rpm -qa | grep MQSeries | xargs rpm -ev

rm -rf /var/mqm/

=========================================================================================
