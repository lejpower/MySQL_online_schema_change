#!/bin/sh
#
# OMLINE SCHEMA CHANGE
#
# created by uijun.lee - 2012/11/20
# updated by uijun.lee - 2013/12/02
#

################
# ARGUMENT
################

OPT=$1
PASSWD=$2

BASE_DIR=/mysql/${DBN}_percona
SOURCE_DIR=`pwd` 
## you should change the directory after downloading the source code!
## e.g.) cd MySQL_online_schema_change ; pwd

################
# ARGUMENT CHK
################
#arg_chk()
#{
if [ $# -ne 2 ] ; then
    echo "Usage: ./online_schema_change.sh -d|-e|-br|-bp"
    exit 9
fi
#}

################
# YES NO CHECK
################
yes_no() {
  if [ ${yn} = 'y' -o "${yn}" = 'yes' ]; then
    exit 2;
  elif [ ${yn} = 'n' -o "${yn}" = 'no' ]; then
    exit 3;
  else
    msg="#### You must imput only [y/n]! ####";
    exit 1;
  fi
}


################
# USAGE
################
usage()
{
    echo "Usage: ./online_schema_change.sh -d|-e|-br|-bp"
    exit 9
}

################
# INPUT ENV
################
input_env()
{
echo "#############CHECK ENV#############"
echo " ENV              : ${ENV}"
echo " YYYYMMDD         : ${YYYYMMDD}"
echo " HOST             : ${HOST}"
echo " PORT             : ${PORT_NUM}"
echo " DB               : ${DBN}"
echo " TABLE            : ${TBL}"
echo " ALTER SENTENCE   : ${ALTER_SENTENCE} "
echo ""
echo " CHUNK_TIME       : ${CHUNK_TIME}"
echo " LOCK WAIT TIMEOUT: ${INNODB_LOCK_WAIT_TIMEOUT}"
echo "###################################"
echo ""
echo -n "no problem? [y/n]:"; read yn
if [ ${yn} != "y" ]; then
    echo "Please check setting env!!!"
    exit 1
fi
}


input_env_back()
{
if [ ${OPT} = "-bp" ]; then
	echo "#############CHECK ENV#############"
	echo " ENV              : ${ENV}"
	echo " YYYYMMDD         : ${YYYYMMDD}"
	echo " HOST             : ${HOST}"
	echo " PORT             : ${PORT_NUM}"
	echo " DB               : ${DBN}"
	echo " TABLE            : ${TBL}"
	echo " BACK SENTENCE    : ${BACK_SENTENCE} "
	echo ""
	echo " CHUNK_TIME       : ${CHUNK_TIME}"
	echo " LOCK WAIT TIMEOUT: ${INNODB_LOCK_WAIT_TIMEOUT}"
	echo "###################################"
	echo ""
else
        echo "#############CHECK ENV#############"
        echo " ENV              : ${ENV}"
        echo " YYYYMMDD         : ${YYYYMMDD}"
        echo " HOST             : ${HOST}"
        echo " PORT             : ${PORT_NUM}"
        echo " DB               : ${DBN}"
        echo " TABLE            : ${TBL}"
        echo ""
        echo " CHUNK_TIME       : ${CHUNK_TIME}"
        echo " LOCK WAIT TIMEOUT: ${INNODB_LOCK_WAIT_TIMEOUT}"
        echo "###################################"
        echo ""
fi

echo -n "no problem? [y/n]:"; read yn
if [ ${yn} != "y" ]; then
    echo "Please check setting env!!!"
    exit 1
fi
}



################
# CREATE DIR
################
mk_directory()
{
 mkdir -p ${BASE_DIR}
 if [ "$?" != "0" ]; then
    echo "failure mkdir"
    exit 1
 fi
}


################
# CHANGE DIR
################
ch_directory()
{
 cd ${BASE_DIR}
 if [ "$?" != "0" ]; then
    echo "failure cddir"
    exit 1
 fi
}


################
# BEFORE SCHEMA CHECK
################
bf_schema_chk()
{
 echo "show create table ${TBL}\G" | mysql -h ${HOST} -P ${PORT_NUM} -u online_change_user -p${PASSWD} -N ${DBN} 2>&1 > ${BASE_DIR}/bf_schema_${TBL}_${ENV}.log
 if [ "$?" != "0" ]; then
    echo "failure bf_schema"
    exit 1
 else
    cat ${BASE_DIR}/bf_schema_${TBL}_${ENV}.log
    echo "*************************** 1. row ***************************"
 fi
 echo ""
}

bf_schema_chk_back()
{
 echo "show create table ${TBL}\G" | mysql -h ${HOST} -P ${PORT_NUM} -u online_change_user -p${PASSWD} -N ${DBN} 2>&1 > ${BASE_DIR}/back_bf_schema_${TBL}_${ENV}.log
 if [ "$?" != "0" ]; then
    echo "failure bf_schema"
    exit 1
 else
    cat ${BASE_DIR}/back_bf_schema_${TBL}_${ENV}.log
    echo "*************************** 1. row ***************************"
 fi
 echo ""
}

################
# DRY RUN
################
percona_dry_run()
{
 echo "##########dry-run##########"
 #dryrun=`. ${SOURCE_DIR}/pt-online-schema-change.sh -dry_run`
 pt-online-schema-change --dry-run --print --chunk-time ${CHUNK_TIME} --print --no-drop-old-table --set-vars innodb_lock_wait_timeout=${INNODB_LOCK_WAIT_TIMEOUT} --alter-foreign-keys-method none -h ${HOST} -P ${PORT_NUM} -u online_change_user -p ${PASSWD} --alter "${ALTER_SENTENCE}" D=${DBN},t=${TBL} 2>&1 > ${BASE_DIR}/percona_${YYYYMMDD}_${DBN}_${TBL}_check_${ENV}.log
 #pt-online-schema-change --dry-run --chunk-time ${CHUNK_TIME} --no-drop-old-table --lock-wait-timeout ${INNODB_LOCK_WAIT_TIMEOUT} -h ${HOST} -P ${PORT_NUM} -u online_change_user -p ${PASSWD} --alter "${ALTER_SENTENCE}" D=${DBN},t=${TBL} 2>&1 | tee ${BASE_DIR}/percona_${YYYYMMDD}_${DBN}_${TBL}_check_${ENV}.log
 if [ "$?" != "0" ]; then
    echo "failure dry-run"
    exit 1
 else
    cat ${BASE_DIR}/percona_${YYYYMMDD}_${DBN}_${TBL}_check_${ENV}.log
    echo "###########################"
 fi

 if [ "$?" = "1" ]; then
    echo $?
    exit 2
 fi

 echo ""
 echo "####dry-run error check####"
 egrep -i "Error|Cannot|PRIMARY" ./percona_${YYYYMMDD}_${DBN}_${TBL}_check_${ENV}.log  | egrep -v "FORCE INDEX" | egrep -v "PRIMARY KEY"  > ${BASE_DIR}/tmp_chk_err.log
 if [ -s ${BASE_DIR}/tmp_chk_err.log ]; then
    echo "EXIST ERROR"
    echo "###########################"
    exit 1
 else
    echo "NOTHING ERROR"
    echo "###########################"
 fi
 \rm ${BASE_DIR}/tmp_chk_err.log
 if [ "$?" != "0" ]; then
    echo "failure delete tmp_log"
    exit 1
 fi

 echo ""
}

percona_dry_run_back()
{
 echo "##########dry-run##########"
 pt-online-schema-change --dry-run --print --chunk-time ${CHUNK_TIME} --set-vars innodb_lock_wait_timeout=${INNODB_LOCK_WAIT_TIMEOUT} --alter-foreign-keys-method none -h ${HOST} -P ${PORT_NUM} -u online_change_user -p ${PASSWD} --alter "${BACK_SENTENCE}" D=${DBN},t=${TBL} 2>&1 > ${BASE_DIR}/back_percona_${YYYYMMDD}_${DBN}_${TBL}_check_${ENV}.log
 #pt-online-schema-change --dry-run --chunk-time ${CHUNK_TIME} --lock-wait-timeout ${INNODB_LOCK_WAIT_TIMEOUT} -h ${HOST} -P ${PORT_NUM} -u online_change_user -p ${PASSWD} --alter "${BACK_SENTENCE}" D=${DBN},t=${TBL} 2>&1 | tee ${BASE_DIR}/back_percona_${YYYYMMDD}_${DBN}_${TBL}_check_${ENV}.log
 if [ "$?" != "0" ]; then
    echo "failure dry-run"
    exit 1
 else
    cat ${BASE_DIR}/back_percona_${YYYYMMDD}_${DBN}_${TBL}_check_${ENV}.log
    echo "###########################"
 fi

 echo ""
 echo "####dry-run error check####"
 egrep -i "Error|Cannot|PRIMARY" ./percona_${YYYYMMDD}_${DBN}_${TBL}_check_${ENV}.log  | egrep -v "FORCE INDEX" | egrep -v "PRIMARY KEY"  > ${BASE_DIR}/tmp_chk_err.log
 if [ -s ${BASE_DIR}/tmp_chk_err.log ]; then
    echo "EXIST ERROR"
    echo "###########################"
    exit 1
 else
    echo "NOTHING ERROR"
    echo "###########################"
 fi
 \rm ${BASE_DIR}/tmp_chk_err.log
 if [ "$?" != "0" ]; then
    echo "failure delete tmp_log"
    exit 1
 fi

 echo ""
}

################
# EXECUTE
################
percona_execute()
{
 echo "##########execute##########"
 pt-online-schema-change --execute --print --chunk-time ${CHUNK_TIME} --no-drop-old-table --set-vars innodb_lock_wait_timeout=${INNODB_LOCK_WAIT_TIMEOUT} --alter-foreign-keys-method none -h ${HOST} -P ${PORT_NUM} -u online_change_user -p ${PASSWD} --alter "${ALTER_SENTENCE}" D=${DBN},t=${TBL} 2>&1 > ${BASE_DIR}/percona_${YYYYMMDD}_${DBN}_${TBL}_execute_${ENV}.log
 #pt-online-schema-change --execute --chunk-time ${CHUNK_TIME} --no-drop-old-table --lock-wait-timeout ${INNODB_LOCK_WAIT_TIMEOUT} -h ${HOST} -P ${PORT_NUM} -u online_change_user -p ${PASSWD} --alter "${ALTER_SENTENCE}" D=${DBN},t=${TBL} 2>&1 | tee ${BASE_DIR}/percona_${YYYYMMDD}_${DBN}_${TBL}_execute_${ENV}.log
 if [ "$?" != "0" ]; then
    echo ""
    echo "failure execute"
    echo ""
    echo "###########################"
    exit 1
 else
    cat ${BASE_DIR}/percona_${YYYYMMDD}_${DBN}_${TBL}_execute_${ENV}.log
    echo "###########################"
 fi

 echo ""
 echo "####execute error check####"
 egrep -i "Error|Cannot|PRIMARY" ./percona_${YYYYMMDD}_${DBN}_${TBL}_execute_${ENV}.log  | egrep -v "FORCE INDEX" | egrep -v "PRIMARY KEY"  > ${BASE_DIR}/tmp_chk_err.log
 if [ -s ${BASE_DIR}/tmp_chk_err.log ]; then
    echo "EXIST ERROR"
    echo "###########################"
    exit 1
 else
    echo "NOTHING ERROR"
    echo "###########################"
 fi
 \rm ${BASE_DIR}/tmp_chk_err.log
 if [ "$?" != "0" ]; then
    echo "failure delete tmp_log"
    exit 1
 fi

 echo ""
}

## Don't make old table!!!
percona_execute_back()
{
 echo "##########execute##########"
 pt-online-schema-change --execute --print --chunk-time ${CHUNK_TIME} --set-vars innodb_lock_wait_timeout=${INNODB_LOCK_WAIT_TIMEOUT} --alter-foreign-keys-method none -h ${HOST} -P ${PORT_NUM} -u online_change_user -p ${PASSWD} --alter "${BACK_SENTENCE}" D=${DBN},t=${TBL} 2>&1 > ${BASE_DIR}/back_percona_${YYYYMMDD}_${DBN}_${TBL}_execute_${ENV}.log
 #pt-online-schema-change --execute --chunk-time ${CHUNK_TIME} --lock-wait-timeout ${INNODB_LOCK_WAIT_TIMEOUT} -h ${HOST} -P ${PORT_NUM} -u online_change_user -p ${PASSWD} --alter "${BACK_SENTENCE}" D=${DBN},t=${TBL} 2>&1 | tee ${BASE_DIR}/back_percona_${YYYYMMDD}_${DBN}_${TBL}_execute_${ENV}.log
 if [ "$?" != "0" ]; then
    echo ""
    echo "failure execute"
    echo ""
    echo "###########################"
    exit 1
 else
    cat ${BASE_DIR}/back_percona_${YYYYMMDD}_${DBN}_${TBL}_execute_${ENV}.log
    echo "###########################"
 fi

 echo ""
 echo "####execute error check####"
 egrep -i "Error|Cannot|PRIMARY" ./percona_${YYYYMMDD}_${DBN}_${TBL}_execute_${ENV}.log  | egrep -v "FORCE INDEX" | egrep -v "PRIMARY KEY"  > ${BASE_DIR}/tmp_chk_err.log
 if [ -s ${BASE_DIR}/tmp_chk_err.log ]; then
    echo "EXIST ERROR"
    echo "###########################"
    exit 1
 else
    echo "NOTHING ERROR"
    echo "###########################"
 fi
 \rm ${BASE_DIR}/tmp_chk_err.log
 if [ "$?" != "0" ]; then
    echo "failure delete tmp_log"
    exit 1
 fi

 echo ""
}

################
# AFTER SCHEMA CHECK
################
af_schema_chk()
{
 echo "show create table ${TBL}\G" | mysql -h ${HOST} -P ${PORT_NUM} -u online_change_user -p${PASSWD} -N ${DBN} 2>&1 > ${BASE_DIR}/af_schema_${TBL}_${ENV}.log
 if [ "$?" != "0" ]; then
    echo "failure after schema check"
    exit 1
 else
    cat ${BASE_DIR}/af_schema_${TBL}_${ENV}.log
    echo "*************************** 1. row ***************************"
 fi
 echo ""
 
 echo "#####difference schema#####"
 diff bf_schema_${TBL}_${ENV}.log af_schema_${TBL}_${ENV}.log 2>&1 | tee ${BASE_DIR}/${ENV}_${TBL}_diff_schema.log
 echo "###########################"
 echo ""
}

af_schema_chk_back()
{
 echo "show create table ${TBL}\G" | mysql -h ${HOST} -P ${PORT_NUM} -u online_change_user -p${PASSWD} -N ${DBN} 2>&1 > ${BASE_DIR}/back_af_schema_${TBL}_${ENV}.log
 if [ "$?" != "0" ]; then
    echo "failure after schema check"
    exit 1
 else
    cat ${BASE_DIR}/back_af_schema_${TBL}_${ENV}.log
    echo "*************************** 1. row ***************************"
 fi
 echo ""

 echo "#####difference schema#####"
 diff back_bf_schema_${TBL}_${ENV}.log back_af_schema_${TBL}_${ENV}.log 2>&1 | tee ${BASE_DIR}/back_${ENV}_${TBL}_diff_schema.log
 echo "###########################"
 echo ""
}

################
# ROLL BACK (RENAME ver.)
################
rollback_rename()
{
  if [ -s ${BASE_DIR}/${ENV}_${TBL}_back_rename.log ]; then
     \rm ${BASE_DIR}/${ENV}_${TBL}_back_rename.log
  fi
  echo ""
  echo "" 
  echo "### START ROLL BACK ###"
  echo "LOCK TABLES _${TBL}_old WRITE , ${TBL} WRITE ;" | mysql -h ${HOST} -P ${PORT_NUM} -u online_change_user -p${PASSWD} -vvv ${DBN} 2>&1 >> ${BASE_DIR}/${ENV}_${TBL}_back_rename.log
 if [ "$?" != "0" ]; then
    echo "error rename"
    exit 1
 fi

  echo "ALTER TABLE ${TBL} RENAME TO ${TBL}_new; ALTER TABLE _${TBL}_old RENAME TO ${TBL};" | mysql -h ${HOST} -P ${PORT_NUM} -u online_change_user -p${PASSWD} -vvv ${DBN} 2>&1 >> ${BASE_DIR}/${ENV}_${TBL}_back_rename.log
 if [ "$?" != "0" ]; then
    echo "error rename"
    exit 1
 fi

  echo "UNLOCK TABLES;" | mysql -h ${HOST} -P ${PORT_NUM} -u online_change_user -p${PASSWD} -vvv ${DBN} 2>&1 >> ${BASE_DIR}/${ENV}_${TBL}_back_rename.log
 if [ "$?" != "0" ]; then
    echo "error rename"
    exit 1
 else
    cat ${BASE_DIR}/${ENV}_${TBL}_back_rename.log
 fi

  echo ""
  echo ""
  echo "### END ROLL BACK ###"
}



################
# DROP NEW TABLE (rename ver.)
################
rollback_new_drop()
{
echo -n "Do you want to delete new table?? [y/n]:"; read yn
if [ ${yn} = "y" ]; then
   echo ""
   echo ""
   echo " ### DROP NEW TABLE ### "
   echo "TRUNCATE TABLE ${TBL}_new;" | mysql -h ${HOST} -P ${PORT_NUM} -u online_change_user -p${PASSWD} -vvv ${DBN} 2>&1 >> ${BASE_DIR}/${ENV}_${TBL}_back_rename.log
   if [ "$?" != "0" ]; then
    echo "error truncate"
    exit 1
   fi

   echo "DROP TABLE ${TBL}_new;" | mysql -h ${HOST} -P ${PORT_NUM} -u online_change_user -p${PASSWD} -vvv ${DBN} 2>&1 >> ${BASE_DIR}/${ENV}_${TBL}_back_rename.log
   if [ "$?" != "0" ]; then
    echo "error drop"
    exit 1
   else
    cat ${BASE_DIR}/${ENV}_${TBL}_back_rename.log
    echo ""
    echo ""
    echo "ROLLBACK NEW_TABLE [OK]"
    echo "TRUNCATE NEW_TABLE [OK]"
    echo "DROP     NEW_TABLE [OK]"
   fi
else
    echo "" 2>&1 | tee -a ${BASE_DIR}/${ENV}_back_rename.log
    echo "" 2>&1 | tee -a ${BASE_DIR}/${ENV}_back_rename.log
    echo "Exist new table!!!" 2>&1 | tee -a ${BASE_DIR}/${ENV}_back_rename.log
    exit 1
fi

   echo ""
   echo " ### DROP NEW TABLE ### "
   echo ""
   echo "" 
}


################
# DROP OLD TABLE (percona ver.)
################
rollback_old_drop()
{
echo -n "Do you want to delete old table?? [y/n]:"; read yn
if [ ${yn} = "y" ]; then
   echo ""
   echo ""
   echo " ### DROP OLD TABLE ### "
  if [ -s ${BASE_DIR}/back_percona_${YYYYMMDD}_${DBN}_${TBL}_execute_${ENV}.log ]; then
     \rm ${BASE_DIR}/back_percona_${YYYYMMDD}_${DBN}_${TBL}_execute_${ENV}.log
  fi

   echo "" >> ${BASE_DIR}/back_percona_${YYYYMMDD}_${DBN}_${TBL}_execute_${ENV}.log
   echo "" >> ${BASE_DIR}/back_percona_${YYYYMMDD}_${DBN}_${TBL}_execute_${ENV}.log
   echo "" >> ${BASE_DIR}/back_percona_${YYYYMMDD}_${DBN}_${TBL}_execute_${ENV}.log
   echo " ### DROP OLD TABLE ###" >> ${BASE_DIR}/back_percona_${YYYYMMDD}_${DBN}_${TBL}_execute_${ENV}.log
   echo "" >> ${BASE_DIR}/back_percona_${YYYYMMDD}_${DBN}_${TBL}_execute_${ENV}.log
   echo "TRUNCATE TABLE _${TBL}_old;" | mysql -h ${HOST} -P ${PORT_NUM} -u online_change_user -p${PASSWD} -vvv ${DBN} 2>&1 >> ${BASE_DIR}/back_percona_${YYYYMMDD}_${DBN}_${TBL}_execute_${ENV}.log
   if [ "$?" != "0" ]; then
    echo "error truncate"
    exit 1
   fi

   echo "DROP TABLE _${TBL}_old;" | mysql -h ${HOST} -P ${PORT_NUM} -u online_change_user -p${PASSWD} -vvv ${DBN} 2>&1 >> ${BASE_DIR}/back_percona_${YYYYMMDD}_${DBN}_${TBL}_execute_${ENV}.log
   if [ "$?" != "0" ]; then
    echo "error drop"
    exit 1
   fi

else
    echo "" >> ${BASE_DIR}/back_percona_${YYYYMMDD}_${DBN}_${TBL}_execute_${ENV}.log
    echo "" >> ${BASE_DIR}/back_percona_${YYYYMMDD}_${DBN}_${TBL}_execute_${ENV}.log
    echo "Exist old table!!!" >> ${BASE_DIR}/back_percona_${YYYYMMDD}_${DBN}_${TBL}_execute_${ENV}.log
    exit 1
fi
cat ${BASE_DIR}/back_percona_${YYYYMMDD}_${DBN}_${TBL}_execute_${ENV}.log
   echo ""
   echo " ### DROP OLD TABLE ### "
   echo ""
   echo ""
}

#####CASE##########################################################


case "${OPT}" in
####################################################################
####################################################################
####################################################################
-e )

    input_env
    #mk_directory
    ch_directory
    bf_schema_chk
#    percona_dry_run
    percona_execute
    af_schema_chk
    ;;
####################################################################
####################################################################
####################################################################
-d )
    input_env
    mk_directory
    ch_directory
    #bf_schema_chk
    percona_dry_run
    #percona_execute
    #af_schema_chk

    ;;
####################################################################
####################################################################
####################################################################
-br )
    input_env_back
    ch_directory
    bf_schema_chk_back
    rollback_rename
    af_schema_chk_back
    rollback_new_drop
    ;;
####################################################################
####################################################################
####################################################################
-bp )
    input_env_back
    ch_directory
    bf_schema_chk_back
    percona_dry_run_back
    percona_execute_back
    af_schema_chk_back
    rollback_old_drop
    ;;
####################################################################
####################################################################
####################################################################
    #setenv TARGET_DIR /usr/local/rms/admin/work/pp_tools/drop_oldtbl
    #${TARGET_DIR}/droptbl.sh -p ${SVR} ${DBN}
    #${TARGET_DIR}/droptbl.sh -e ${SVR} ${DBN}
    #;;
####################################################################
####################################################################
####################################################################

* )
    usage
    ;;


esac

exit 0
