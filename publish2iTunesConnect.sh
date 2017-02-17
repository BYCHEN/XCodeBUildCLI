#!/bin/bash -l
#
#
#
# version 0.0.1
#
#
# Configurations Setting
##########################################################################
WORKSPACE="<SET Workspace name>"
SCHEME="<SET Scheme name>"
DISTRIBUTION_PROVISIONING_PROFILE="<SET Provisioning profile UUID>"
DISTRIBUTION_CERTIFICATE_NAME="<SET Certificate name>"
CONFIGURATION="<SET build coniguration for building target>"
METHOD="<SET Publish type>"
SYSTEM_PWD="<SET system password>"
ITUNES_CONNECT_ACCOUNT="<SET iTunes connect account>"
ITUNES_CONNECT_PASSWORD="<SET iTunes connect password>"
KEYCHAIN_NAME="<SET system keychain name>"

##########################################################################
#Static Variables

BUILD_PATH="build"
BUILD_HOME=${PWD}
ALTOOL_PATH="/usr/local/bin/altool"
ITMS_PATH="/usr/local/itms"
KEYCHAIN_PAHT="${HOME}/Library/Keychains/${KEYCHAIN_NAME}"
SYSTEM_PWD_MASK=$(echo ${SYSTEM_PWD} | sed "s/[[:graph:]]/*/g")
##########################################################################


if [ ! -f "${KEYCHAIN_PAHT}" ] 
then 
	echo "ERROR : Keychain not found : ${KEYCHAIN_PAHT}"
	exit 2
fi

KEY_PARTITION_LIST_CMD="security set-key-partition-list -S apple-tool:,apple: -s -k "${SYSTEM_PWD}" "${KEYCHAIN_PAHT}""

KEY_PARTITION_LIST_MASK_CMD="security set-key-partition-list -S apple-tool:,apple: -s -k "${SYSTEM_PWD_MASK}" "${KEYCHAIN_PAHT}""

echo "INFO : set Key partition list command : \n${KEY_PARTITION_LIST_MASK_CMD}\n"
#
eval $KEY_PARTITION_LIST_CMD
if [ $? != "0" ]; then
	echo "set Key partition list command Failed"
	exit 1
fi

DEFAULT_KEYCHAIN_CMD="security default-keychain -d user -s "${KEYCHAIN_PAHT}""

echo "INFO : set Default Keychain : \n${DEFAULT_KEYCHAIN_CMD}\n"
#
eval $DEFAULT_KEYCHAIN_CMD
if [ $? != "0" ]; then
	echo "set Default Keychain command Failed"
	exit 1
fi

UNLOCK_KEYCHAIN_CMD="security unlock-keychain -p "${SYSTEM_PWD}" "${KEYCHAIN_PAHT}""

UNLOCK_KEYCHAIN_MASK_CMD="security unlock-keychain -p "${SYSTEM_PWD_MASK}" "${KEYCHAIN_PAHT}""

echo "INFO : Unlock Keychain command : \n${UNLOCK_KEYCHAIN_MASK_CMD}\n"
#
eval $UNLOCK_KEYCHAIN_CMD
if [ $? != "0" ]; then
	echo "Unlock Keychain command Failed"
	exit 1
fi
##########################################################################

echo "INFO : Created Build Folder"
mkdir $BUILD_PATH
echo "--------------"
##########################################################################


echo "INFO : Workspace Name : ${WORKSPACE}"
echo "INFO : Scheme Name : ${SCHEME}"
echo "INFO : Archive Path : ${BUILD_HOME}/${BUILD_PATH}/${SCHEME}.xcarchive"
echo "--------------"
##########################################################################


#顯示Certificate Information
CERTIFICATE_INFO_CMD="security find-identity -p codesigning -v"

echo "INFO : Certificates list Command : \n${CERTIFICATE_INFO_CMD}\n"
eval $CERTIFICATE_INFO_CMD
if [ $? != "0" ]; then
	echo "Certificates list Command Failed"
	exit 1
fi
echo "--------------"
##########################################################################


#顯示Provisioning profile Information
PROVISIONING_PROFILE_INFO_CMD="ls ${HOME}/Library/MobileDevice/Provisioning\ Profiles/"

echo "INFO : Provisioning Profiles list Command : \n${PROVISIONING_PROFILE_INFO_CMD}\n"
eval $PROVISIONING_PROFILE_INFO_CMD
echo "--------------"
##########################################################################


#顯示Project Information
PROJECT_INFO_CMD="xcodebuild -workspace "${WORKSPACE}.xcworkspace" \
-list"

echo "INFO : Project Info Command : \n${PROJECT_INFO_CMD}\n"
eval $PROJECT_INFO_CMD
if [ $? != "0" ]; then
	echo "Project Info Command Failed"
	exit 1
fi
echo "--------------"
##########################################################################


#檢測Team ID
DEVELOPMENT_TEAM_TEXT=$(xcodebuild \
-workspace "${WORKSPACE}".xcworkspace \
-scheme "${SCHEME}" \
-showBuildSettings \
| grep 'DEVELOPMENT_TEAM')
#注意：有四個空白
DEVELOPMENT_TEAM=${DEVELOPMENT_TEAM_TEXT//"    DEVELOPMENT_TEAM = "/""}
echo "INFO : Team ID : ${DEVELOPMENT_TEAM}\n"
if [ $DEVELOPMENT_TEAM == "" ]; then
	echo "get Developement Team ID Failed"
	exit 1
fi
echo "--------------"
##########################################################################


##把Project的 Provisioning Style 改成 Manual
echo "INFO : change ProvidioningStyle Automatic to Manual"
echo "INFO : change file name : ${WORKSPACE}.xcodeproj/project.pbxproj\n"
sed -i '' 's/ProvisioningStyle = Automatic;/ProvisioningStyle = Manual;/' ${WORKSPACE}.xcodeproj/project.pbxproj
if [ $? != "0" ]; then
	echo "change ProvidioningStyle Failed"
	exit 1
fi
echo "--------------"
##########################################################################


#執行Archive Command
echo "INFO : Building Archive File..."
ARCHIVE_CMD="xcodebuild -workspace "${WORKSPACE}.xcworkspace" \
-scheme "${SCHEME}" \
-archivePath "${BUILD_PATH}/${WORKSPACE}.xcarchive" \
-configuration "${CONFIGURATION}" \
clean \
archive \
CODE_SIGN_IDENTITY=\"${DISTRIBUTION_CERTIFICATE_NAME}\" \
PROVISIONING_PROFILE_SPECIFIER=\"${DISTRIBUTION_PROVISIONING_PROFILE}\""

echo "INFO : Archive Command : \n${ARCHIVE_CMD}\n"

#Executing Archive command
eval $ARCHIVE_CMD
if [ $? != "0" ]; then
	echo "Build Archive Failed"
	exit 1
fi
##########################################################################


#產生 exportOption plist file
echo "INFO : Generating exportOption plist file"
cat > ${BUILD_PATH}/exportOptions.plist <<EOM
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>${METHOD}</string>
    <key>teamID</key>
    <string>${DEVELOPMENT_TEAM}</string>
</dict>
</plist>
EOM
echo "INFO : Finished...\n"
##########################################################################


#產生 exportOption plist file
echo "INFO : Generating ipa file"
IPA_CMD="xcodebuild \
-exportArchive \
-archivePath "${BUILD_PATH}/${WORKSPACE}.xcarchive" \
-exportOptionsPlist "${BUILD_PATH}/exportOptions.plist" \
-exportPath build/"

echo "INFO : Generate ipa Command : \n${IPA_CMD}\n"

#Executing ipa command
eval $IPA_CMD
if [ $? != "0" ]; then
	echo "Generate ipa Command Failed"
	exit 1
fi
##########################################################################


# 檢測alttol 和 itms 是否存在 /usr/local

if [ ! -L "${ALTOOL_PATH}" ] 
then 
	echo $SYSTEM_PWD | sudo -S ln -s /Applications/Xcode.app/Contents/Applications/Application\ Loader.app/Contents/Frameworks/ITunesSoftwareService.framework/Versions/A/Support/altool /usr/local/bin
	echo "INFO : Create a symbolic link for [ altool ] command"
fi
#echo $SYSTEM_PWD
if [ ! -L "$ITMS_PATH" ] 
then 
	echo $SYSTEM_PWD | sudo -S ln -s /Applications/Xcode.app/Contents/Applications/Application\ Loader.app/Contents/itms /usr/local
	echo "INFO : Create a symbolic link for [ itms ] command"
fi
##########################################################################


#產生 upload to iTunes Connect
echo "INFO : Upload to iTunes Connect"
UPLOAD_ITUNES_CONNECT_CMD="altool \
--upload-app \
-f "${BUILD_PATH}/${WORKSPACE}.ipa" \
-u "${ITUNES_CONNECT_ACCOUNT}" \
-p "${ITUNES_CONNECT_PASSWORD}""

echo "INFO : Upload to iTunes Connect Command : \n${UPLOAD_ITUNES_CONNECT_CMD}\n"

#Executing Upload to iTunes Connect Command
eval $UPLOAD_ITUNES_CONNECT_CMD
if [ $? != "0" ]; then
	echo "Upload to iTunes Connect Failed"
	exit 1
fi
##########################################################################
