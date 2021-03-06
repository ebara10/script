#!/bin/sh
PREFIX="ebaraEC2-"
CURRENTTIME=`date '+%Y%m%d%H%M'`
EXPIRATIONDATE=`date "-d${TIME_LIMIT} days ago" '+%Y%m%d%H%M'`
HEAD_LOGFILE="/tmp/head_create_ami.log"
BODY_LOGFILE="/tmp/body_create_ami.log"
END_LOGFILE="/tmp/end_create_ami.log"
# API
REGULAR_API_URL="https://api.chatwork.com/v1/rooms/${REGULAR_ROOM}/messages"
ERROR_API_URL="https://api.chatwork.com/v1/rooms/${ERROR_ROOM}/messages"

#設定ファイル読み出し
. /usr/local/aws/bin/setting.sh

#戻り値のチェック
is_check_return_value(){
   if [ $? = 1 ]; then
        echo "エラーが発生しました。終了します" >> ${BODY_LOGFILE} 2>&1
        LOG_DETAIL=`cat ${HEAD_LOGFILE} ${BODY_LOGFILE}`
        #異常ログをchatworkに連携
        RESULT=`curl -X POST -H "X-ChatWorkToken: $TOKEN" -d "body=${LOG_DETAIL}" $ERROR_API_URL`
        delete_logfile
        exit 1
   fi
return 0
}

delete_logfile(){
    cat /dev/null > ${HEAD_LOGFILE}
    cat /dev/null > ${BODY_LOGFILE}
    cat /dev/null > ${END_LOGFILE}
}
#ログのヘッダ部分作成
echo "** create ami backup and delete old ami" >> ${HEAD_LOGFILE} 2>&1
echo "** `date '+%Y-%m-%d %H:%M:%S'` - START"  >> ${HEAD_LOGFILE} 2>&1

#amiを作成
AMI_ID=`aws ec2 create-image  --instance-id ${INSTANCE_ID} --name "${PREFIX}${CURRENTTIME}" --no-reboot | jq -r '.ImageId'`>> ${BODY_LOGFILE} >&2
echo "create AMI->${PREFIX}${CURRENTTIME}/${AMI_ID}" >> ${BODY_LOGFILE} 2>&1

#amiの一覧を取得
AMI_ID=`aws ec2 describe-images --owners self --filters "Name=name,Values=${PREFIX}${EXPIRATIONDATE}" | jq '.Images[]' | jq -r '.ImageId'`
if [ -z ${AMI_ID} ]; then
    echo "削除するものはありませんでした。" >> ${BODY_LOGFILE} 2>&1
else
    #削除
    aws ec2 deregister-image --image-id ${AMI_ID} >> ${BODY_LOGFILE} 2>&1
    is_check_return_value
    echo "deleted-> ${AMI_ID}" > ${BODY_LOGFILE} 2>&1
fi

echo "SUCCESS!** `date '+%Y-%m-%d %H:%M:%S'` - END" >> ${END_LOGFILE} 2>&1
LOG_DETAIL=`cat ${HEAD_LOGFILE} ${BODY_LOGFILE} ${END_LOGFILE}`

#chatworkに結果を連携
RESULT=`curl -X POST -H "X-ChatWorkToken: $TOKEN" -d "body=${LOG_DETAIL}" $REGULAR_API_URL`
delete_logfile
