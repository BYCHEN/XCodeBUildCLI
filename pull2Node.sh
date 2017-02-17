#!/bin/bash -l
#
#
#
# version 0.0.1
# example :
# sh pull2Node.sh -host <NodeIP> -user <NodeUserName> -ProfilePath ~/Downloads/dis_UserFeedbackHelpLibrary.mobileprovision -CertificatePath ~/Downloads/ios_distribution.cer -k login.keychain-db -p <NodeUserPassword> -P <CertificatePassword>
#  
# Configurations Setting
##########################################################################
# Static Variables

REMOTE_SOURCE_PATH="Downloads"
KEYCHAIN_PATH="Library/Keychains"

########################################################################
if ( (( $# % 2 != 0 )) || (($# == 0)) ); then
	echo "Arguments not enought"
	exit 1
fi

index=1
while [ $index -le $# ]; do
	key=${*:$index:1}
	value=${*:$(($index + 1)):1}
	case $key in
	"-host")
		REMOTE_HOST=$value
	;;
	"-user")
		REMOTE_USER=$value
	;;
	"-ProfilePath")
		if [ ! -f "$value" ]; then
			echo "not found Profile : $PROFILE_PATH"
			exit 1
		fi
		PROFILE_PATH=$value
		PROFILE_NAME=$(basename "$PROFILE_PATH")
	;;
	"-CertificatePath")
		if [ ! -f "$value" ]; then
			echo "not found .p12 file : $CERTIFICATE_PATH"
			exit 1
		fi
		CERTIFICATE_PATH=$value
		CERTIFICATE_NAME=$(basename "$CERTIFICATE_PATH")
	;;
	"-k")
		REMOTE_KEYCHAIN_NAME=$value
	;;
	"-p")
		SYSTEM_PWD=$value
	;;
	"-P")
		CERTIFICATE_PWD=$value
	;;
	*)
		echo "No found Argument name: ${key}"
		exit 1
	;;
	esac
	((index+=2))
done

########################################################################
echo "Enter the Node Passwork ..."
SCP_CERTIFICATE_CMD="scp -r \
"\"$CERTIFICATE_PATH\"" \
"\"$PROFILE_PATH\"" \
"${REMOTE_USER}\@${REMOTE_HOST}\:\~\/${REMOTE_SOURCE_PATH}\/""

echo $SCP_CERTIFICATE_CMD
eval $SCP_CERTIFICATE_CMD
if [ $? != "0" ]; then
	echo "Upload Certificate and Profile failed"
	exit 1
fi
echo "-------------"
echo "Upload Files finished"
########################################################################
echo "Login the Node to setting the Profile and Certificate in Node System..."

ssh $REMOTE_USER@$REMOTE_HOST 'bash -s' << EOF

########################################################################


SYSTEM_PWD_MASK=$(echo ${SYSTEM_PWD} | sed "s/[[:graph:]]/*/g")
CERTIFICATE_PWD_MASK=$(echo ${CERTIFICATE_PWD} | sed "s/[[:graph:]]/*/g")
REMOTE_KEYCHAIN_PATH="\${HOME}/${KEYCHAIN_PATH}/${REMOTE_KEYCHAIN_NAME}"
########################################################################


#顯示Provisioning profile Information
PROVISIONING_PROFILE_INFO_CMD="ls \${HOME}/Library/MobileDevice/Provisioning\ Profiles/";

echo "INFO : Provisioning Profiles list Command : "
echo "\${PROVISIONING_PROFILE_INFO_CMD}"
echo ""
eval \${PROVISIONING_PROFILE_INFO_CMD}
echo "--------------"
########################################################################


OPEN_PROFILE_CMD="open \${HOME}/${REMOTE_SOURCE_PATH}/${PROFILE_NAME}"

echo "Open Provisioning Profile Command : "
echo "\${OPEN_PROFILE_CMD}"
eval \$OPEN_PROFILE_CMD

if [ \$? != "0" ]; then
	echo "Open Profile Failed"
	exit 1
fi
echo "--------------"
#######################################################################


if [ ! -f "\${REMOTE_KEYCHAIN_PATH}" ] 
then 
	echo "ERROR : Keychain not found : \${REMOTE_KEYCHAIN_PATH}"
	exit 2
fi
########################################################################


DEFAULT_KEYCHAIN_CMD="security default-keychain -d user -s "\${REMOTE_KEYCHAIN_PATH}""

echo "INFO : set Default Keychain : "
echo "\${DEFAULT_KEYCHAIN_CMD}"
#
eval \$DEFAULT_KEYCHAIN_CMD
if [ \$? != "0" ]; then
	echo "set Default Keychain command Failed"
	exit 1
fi
echo "--------------"
########################################################################


#顯示Certificate Information
CERTIFICATE_INFO_CMD="security find-identity"

echo "INFO : Certificates list Command : "
echo "\${CERTIFICATE_INFO_CMD}"
eval \$CERTIFICATE_INFO_CMD
if [ \$? != "0" ]; then
	echo "Certificates list Command Failed"
	exit 1
fi
echo "--------------"
########################################################################


UNLOCK_KEYCHAIN_CMD="security unlock-keychain \
-p "${SYSTEM_PWD}" \
"\${REMOTE_KEYCHAIN_PATH}""

UNLOCK_KEYCHAIN_MASK_CMD="security unlock-keychain \
-p "\${SYSTEM_PWD_MASK}" \
"\${REMOTE_KEYCHAIN_PATH}""

echo "INFO : Unlock Keychain command : "
echo "\${UNLOCK_KEYCHAIN_MASK_CMD}"
#
eval \$UNLOCK_KEYCHAIN_CMD
if [ \$? != "0" ]; then
	echo "Unlock Keychain command Failed"
	exit 1
fi
echo "--------------"
########################################################################


KEY_PARTITION_LIST_CMD="security set-key-partition-list \
-S apple-tool:,apple: \
-s -k "${SYSTEM_PWD}" "\${REMOTE_KEYCHAIN_PATH}""

KEY_PARTITION_LIST_MASK_CMD="security set-key-partition-list \
-S apple-tool:,apple: \
-s -k "\${SYSTEM_PWD_MASK}" "\${REMOTE_KEYCHAIN_PATH}""

echo "INFO : set Key partition list command : "
echo "\${KEY_PARTITION_LIST_MASK_CMD}"
#
eval \$KEY_PARTITION_LIST_CMD > /dev/null
if [ \$? != "0" ]; then
	echo "set Key partition list command Failed"
	exit 1
fi
echo "--------------"
########################################################################


KEY_PARTITION_LIST_CMD="security import \
"\${HOME}/${REMOTE_SOURCE_PATH}/${CERTIFICATE_NAME}" \
-k "\${REMOTE_KEYCHAIN_PATH}" \
-P "${CERTIFICATE_PWD}" \
-T /usr/bin/codesign"

KEY_PARTITION_LIST_MASK_CMD="security import \
"\${HOME}/${REMOTE_SOURCE_PATH}/${CERTIFICATE_NAME}" \
-k "\${REMOTE_KEYCHAIN_PATH}" \
-P "${CERTIFICATE_PWD_MASK}" \
-T /usr/bin/codesign"

echo "INFO : import Certificate command : "
echo "\${KEY_PARTITION_LIST_MASK_CMD}"
#
eval \$KEY_PARTITION_LIST_CMD
if [ \$? != "0" ]; then
	echo "import Certificate command Failed"
	exit 1
fi
echo "--------------"
########################################################################
echo "pull2Node Finished"
	exit 0
EOF





