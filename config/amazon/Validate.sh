 #!/bin/bash
 
## echo off
 
if [[ $EUID = 0 ]]; then
   echo "You can't be logged as root to run this script." 1>&2
   exit 100
fi

export IS_INTERACTIVE=$1

read_param(){
	PARAM_NAME=$1
	DEFAULT_VALUE=$2
	DESCRIPTION=$3
	eval PARAM_VALUE='$'$PARAM_NAME
	 if [ ! -n "$PARAM_VALUE" ] ; then
		
		if [ "$IS_INTERACTIVE" = "-i" ] ; then
			if [ ! -n "$DEFAULT_VALUE" ] ; then
				echo "Please insert Service $PARAM_NAME : "
				eval read $PARAM_NAME
				eval PARAM_VALUE='$'$PARAM_NAME
				if [ "$PARAM_VALUE" = "" ]; then
					echo "[ $PARAM_NAME ]   : Not specified"
					exit 1
				fi	
			else
				echo "Please insert Service $DESCRIPTION [Default : $DEFAULT_VALUE ] :"
				eval read $PARAM_NAME
				eval PARAM_VALUE='$'$PARAM_NAME
				if [ "$PARAM_VALUE" = "" ]; then
					export "$PARAM_NAME"="$DEFAULT_VALUE"
					eval echo "[Default $PARAM_NAME ] :"'$'$PARAM_NAME
				else
					export "$PARAM_NAME"="$PARAM_VALUE"
				fi
			fi
		else
					echo "[ERROR! $PARAM_NAME ]   : Not specified"
					exit 1
		fi

	else
		echo "[ $PARAM_NAME ] : $PARAM_VALUE"
	fi
}

read_password(){
	PARAM_NAME=$1
	DESCRIPTION=$2
	eval PARAM_VALUE='$'$PARAM_NAME
	 if [ ! -n "$PARAM_VALUE" ] ; then
		
		if [ "$IS_INTERACTIVE" = "-i" ] ; then
				echo "Please insert $DESCRIPTION : "
				eval read -s $PARAM_NAME
				eval PARAM_VALUE='$'$PARAM_NAME
				if [ "$PARAM_VALUE" = "" ]; then
					echo "[ $PARAM_NAME ]   : Not specified"
					exit 1
				else
					export "$PARAM_NAME"="$PARAM_VALUE"
				fi	
				
				
		else
					echo "[ERROR! $PARAM_NAME ]   : Not specified"
					exit 1
		fi

	fi
}

export CURRENT_DIR=`pwd`

if [ "$IS_INTERACTIVE" = "-ex" ] ; then
	source $CURRENT_DIR/ExportProperties.sh
else

	if [ "$IS_INTERACTIVE" = "-help" ] ; then
		echo "[Usage] : ./RunScriptsAddTenant.sh [OPTION]"
		echo " "
		echo "   OPTION : [-i/-ex] "
		echo "            -i : Interactive mode"
		echo "            -ex : Read ExportProperties.sh"
		echo "            -help : Help"
		exit 0
	fi
fi


echo "################# Validate  ###################"
echo " "
echo "Parameter List:"

## Installation Parmeters defined by provisioning tool in bash environment.

## Tenant Id to be installed [Customer privisioning]
read_param "TENANT_ID" 

## Host machine on which tenant to be installed [Stack privisioning]
read_param "DB_HOST" "localhost" "Host machine anme or IP"

## Port of the Host machine on which tenant to be installed [Stack privisioning]
read_param  "DB_PORT" "1433" "Port"

## Db names that are already exist in stack machine on which tenant to be installed [Stack privisioning]
## db names has to be in lowwer case!
read_param  "CRE_DB_NAME" "rsa_core_$TENANT_ID" "Core DB"

read_password "CRE_DB_PASSWORD" "Core DB Password"

read_param  "RPT_DB_NAME" "rsa_common" "Common DB"

read_password "RPT_DB_PASSWORD" "Common DB Password"



read_param  "SYSTEM_NAME" "rsa_cm_$TENANT_ID" "Case Management DB"

read_password "SYSTEM_PASSWORD" "Case Management DB Password"

## GeoIP parameters
read_param  "REP_USER" "rsa_rpl_"$TENANT_ID "Replication user"

read_password "REP_PASSWORD" "Replication Password"
read_param  "MDF_DIR"
read_param  "LDF_DIR"
read_param  "CRE_MDF_FILE"
read_param  "CRE_LDF_FILE"
read_param  "RPT_MDF_FILE"
read_param  "RPT_LDF_FILE"
read_param  "MDF_FILE_SIZE"
read_param  "LDF_FILE_SIZE"
read_param  "MDF_FILE_GROWTH"
read_param  "LDF_FILE_GROWTH"
read_param "PARTITION_START_DATE"
read_param "INITIAL_PARTITION_NUMBER"
read_param "CRE_TENANT_CREDENTIALS"
read_param "RPT_TENANT_CREDENTIALS"
read_param "OS_USER"
read_password "OS_PASSWORD"

export CURRENT_VERSION="12"
export CURRENT_VERSION_DESC="12 Installed by DBA scripts."

## This parameter should not be modified
export CURRENT_DIR=`pwd`

## The directory where we place the db scripts
export DB_BASE_DIR=$CURRENT_DIR

## ------------------------------------
## Validation
## ------------------------------------

## Validate connectivity and database existance.


 res=`sqlcmd -S $DB_HOST,$DB_PORT -U $SYSTEM_NAME -P $SYSTEM_PASSWORD -d master  -h-1 -W -Q "SET NOCOUNT ON;select count(*) from sys.databases where name='$CRE_DB_NAME';"`

  ERR_RESULT="$?" 
  	if [ "$ERR_RESULT" != 0 ] ; then 
		echo " [ ERROR ] : No connection to $DB_HOST,$DB_PORT instance"
		exit "$ERR_RESULT"
	fi
	res=`echo  $res | sed '#\\r##g'`	
	if [ "$res" != 0 ] ; then 
		echo " [ ERROR ] :   $CRE_DB_NAME database already exist "
		exit 1
	fi


 res=`sqlcmd -S    $DB_HOST,$DB_PORT -U $SYSTEM_NAME -P $SYSTEM_PASSWORD -d master  -h-1 -W -Q "SET NOCOUNT ON;select count(*) from sys.databases where name='$RPT_DB_NAME';"`
  ERR_RESULT="$?" 
  	if [ "$ERR_RESULT" != 0 ] ; then 
		echo " [ ERROR ] : No connection to $DB_HOST,$DB_PORT instance"
		exit "$ERR_RESULT"
	fi
	res=`echo  $res | sed '#\\r##g'`	
	if [ "$res" != 0 ] ; then 
		echo " [ ERROR ] :   $RPT_DB_NAME database already exist"
		exit 1
	fi		
	
	


echo "Finished Validating tenant install"

exit 0

























