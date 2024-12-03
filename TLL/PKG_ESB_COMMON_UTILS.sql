CREATE OR REPLACE PACKAGE PKG_ESB_COMMON_UTILS AS
   /*****************************************************************************************************************************
      NAME:       PKG_ESB_COMMON_UTILS
      PURPOSE:    Common utility for ESB batch service
      REVISIONS:
      Ver        Date        Author           Description
      ---------  ----------  ---------------  ------------------------------------
      1.0                    Kalimuthu        1. Created
   *****************************************************************************************************************************/
	TYPE esb_header_typ IS RECORD
	(
		prog_id			 VARCHAR2 (100),
		batch_typ		 VARCHAR2 (20),
		requestInstanceId	 VARCHAR2 (100),
		repost_flag		 boolean ,--true or false
		applicationName		 VARCHAR2 (100),
		batch_grp_id		 tll_esb_batch_trnsfr_cntrl_tx.BATCH_GRP_ID%TYPE,
		batch_job_num		 TLL_ESB_BATCH_TRNSFR_DET_TP.BATCH_JOB_NUM%TYPE,
		prcss_dt		 DATE,
		batch_end		 boolean ,
		batch_seq_num		 NUMBER(20) 
	);

	FUNCTION FN_START_SAP_BATCH_PROCESS(v_esb_header_rec in esb_header_typ, if_file_handle IN UTL_FILE.FILE_TYPE ) return boolean;
	FUNCTION FN_END_SAP_BATCH_PROCESS(v_esb_header_rec in esb_header_typ , if_file_handle IN UTL_FILE.FILE_TYPE) return boolean;
	FUNCTION FN_GET_ESB_HEADER(v_esb_header_rec in esb_header_typ , if_file_handle IN UTL_FILE.FILE_TYPE) return XMLType;
	FUNCTION FN_CLEANUP_SAP_BATCH_PROCESS(v_esb_header_rec in esb_header_typ, if_file_handle IN UTL_FILE.FILE_TYPE ) return boolean;

END PKG_ESB_COMMON_UTILS;
/
CREATE OR REPLACE PACKAGE BODY PKG_ESB_COMMON_UTILS AS

	v_pkg_id                      VARCHAR2(30)    := 'PKG_ESB_COMMON_UTILS'; -- Variable to Store Package Name
	v_prog_id                     VARCHAR2(30)    := 'PKG_ESB_COMMON_UTILS';
	v_pkg_prog_id                 VARCHAR2(100)   := v_pkg_id || ',' || v_prog_id; --variable to store package and program name
	if_file_handle                UTL_FILE.FILE_TYPE;
	v_file_open_err               EXCEPTION;

	FUNCTION FN_GET_ESB_HEADER(v_esb_header_rec IN esb_header_typ, if_file_handle IN UTL_FILE.FILE_TYPE )
	RETURN XMLType
	IS
		v_xmltype		XMLTYPE;
		v_batch_grp_id		tll_esb_batch_trnsfr_cntrl_tx.BATCH_GRP_ID%TYPE;
		v_repost_flag		VARCHAR2(5);
		v_batchend_flag		VARCHAR2(5);
		v_batch_function	VARCHAR2(50);
	BEGIN
		IF(v_esb_header_rec.repost_flag = TRUE)
		THEN
			v_repost_flag := 'true';
		ELSE
			v_repost_flag := 'false';
		END IF;

		IF(v_esb_header_rec.batch_end = TRUE)
		THEN
			v_batchend_flag := 'true';
		ELSE
			v_batchend_flag := 'false';
		END IF;
					
		IF(v_esb_header_rec.batch_typ = 'BKG')
		THEN
			v_batch_function := 'Y_ADD_RFC_I860';
		ELSIF(v_esb_header_rec.batch_typ = 'SPK')
		THEN
			v_batch_function := 'Z_BAPI_SPARKASSEN_FILL';
		ELSIF(v_esb_header_rec.batch_typ = 'ADV')
		THEN
			v_batch_function := 'Z_DL_UCS_IR_OPEN_ITEMS_IR';
		ELSIF(v_esb_header_rec.batch_typ = 'TLL')
		THEN
			v_batch_function := 'Z_DL_UCS_TRIGONIS';
		END IF;

		SELECT XMLElement("ESBHeader",
			 XMLAttributes('false' as "CallBack" ,'1.0' as "ServiceVersion" ,v_batch_function as "ServiceName", v_esb_header_rec.applicationName as "applicationName", 
			 to_char(sysdate,'YYYYMMDDHH24:MI:SS') as  "beginTime", 
			 'false' as "isRequestResponse" ,'En' as "locale" ,v_esb_header_rec.batch_typ || '::'||uniquekey as "messageId"  ,'NEW' as "messageState", 
			 v_esb_header_rec.requestInstanceId as "requestInstanceId"

			 ),
			    XMLELEMENT("PrivHeader",
				XMLElement("UBCEventHeader",
				    XMLElement("BatchGroupId",v_esb_header_rec.batch_grp_id),
				    XMLElement("TechRepostFlag",v_repost_flag),
   				    XMLElement("BatchEnd",v_batchend_flag),
   				    XMLElement("BatchSeqNo",v_esb_header_rec.batch_seq_num),
				    XMLElement("BatchJobNum",v_esb_header_rec.batch_job_num)
				) 
			   )  
		   ) esbheader
		into v_xmltype
		FROM DUAL;
		
		return v_xmltype;

	END FN_GET_ESB_HEADER;

	FUNCTION FN_START_SAP_BATCH_PROCESS(v_esb_header_rec IN esb_header_typ , if_file_handle IN UTL_FILE.FILE_TYPE)
	RETURN boolean
	IS
		v_xmltype       XMLTYPE;
		v_batch_grp_id	tll_esb_batch_trnsfr_cntrl_tx.BATCH_GRP_ID%TYPE;
	BEGIN
	      -- Getting Environment information


                Pkg_Batch_Logger.proc_log(if_file_handle, 'DEBUG', 'FN_START_SAP_BATCH_PROCESS::Group ID='||v_esb_header_rec.batch_grp_id ,'','');

		INSERT INTO TLL_ESB_BATCH_TRNSFR_CNTRL_TX
		(
			BATCH_GRP_ID,
			PRCSS_DT, 
			INSTANCE_ID, 
			BATCH_TYP,  
			TRNSFR_STAT, 
			CRDT_DT, 
			CRDT_USR
		)
		VALUES( v_esb_header_rec.batch_grp_id,
			v_esb_header_rec.prcss_dt,
			v_esb_header_rec.requestInstanceId,
			v_esb_header_rec.batch_typ,
			'E',
			sysdate,
			v_esb_header_rec.prog_id
		);
                Pkg_Batch_Logger.proc_log(if_file_handle, 'DEBUG', 'FN_START_SAP_BATCH_PROCESS::Success Group ID='||v_esb_header_rec.batch_grp_id ,'','');

		return true;
	END FN_START_SAP_BATCH_PROCESS;

	FUNCTION FN_CLEANUP_SAP_BATCH_PROCESS(v_esb_header_rec IN esb_header_typ , if_file_handle IN UTL_FILE.FILE_TYPE)
	RETURN boolean
	IS
	v_no_of_cleanup_days number := 2;

	BEGIN
                Pkg_Batch_Logger.proc_log(if_file_handle, 'DEBUG', 'FN_CLEANUP_SAP_BATCH_PROCESS::Batch Type ='||v_esb_header_rec.batch_typ ,'','');

		IF(v_esb_header_rec.batch_typ = 'BKG')
		THEN
			v_no_of_cleanup_days := 7;

			DELETE FROM TLL_ESB_BATCH_TRNSFR_DET_TP
			WHERE batch_grp_id in (
				SELECT batch_grp_id FROM tll_esb_batch_trnsfr_cntrl_tx
				WHERE PRCSS_DT <= (v_esb_header_rec.prcss_dt-v_no_of_cleanup_days)
				and INSTANCE_ID =  v_esb_header_rec.requestInstanceId
				and batch_typ  = v_esb_header_rec.batch_typ

			);

		
			DELETE FROM tll_esb_batch_trnsfr_cntrl_tx 
			WHERE PRCSS_DT <= (v_esb_header_rec.prcss_dt-v_no_of_cleanup_days)
			and INSTANCE_ID =  v_esb_header_rec.requestInstanceId
			and batch_typ  = v_esb_header_rec.batch_typ;

		ELSIF(v_esb_header_rec.batch_typ = 'SPK')
		THEN
			v_no_of_cleanup_days := 2;

			DELETE FROM TLL_ESB_BATCH_TRNSFR_DET_TP
			WHERE batch_grp_id in (
				SELECT batch_grp_id FROM tll_esb_batch_trnsfr_cntrl_tx
				WHERE instance_id = v_esb_header_rec.requestInstanceId
				and batch_typ  = v_esb_header_rec.batch_typ
			);

			DELETE FROM tll_esb_batch_trnsfr_cntrl_tx 
			WHERE instance_id = v_esb_header_rec.requestInstanceId
			and batch_typ  = v_esb_header_rec.batch_typ;

		ELSIF(v_esb_header_rec.batch_typ = 'ADV')
		THEN
			
			DELETE FROM TLL_ESB_BATCH_TRNSFR_DET_TP
			WHERE batch_grp_id in (
				SELECT batch_grp_id FROM tll_esb_batch_trnsfr_cntrl_tx
				WHERE instance_id = v_esb_header_rec.requestInstanceId
				and batch_typ  = v_esb_header_rec.batch_typ
			);

			DELETE FROM tll_esb_batch_trnsfr_cntrl_tx 
			WHERE instance_id = v_esb_header_rec.requestInstanceId
			and batch_typ  = v_esb_header_rec.batch_typ;

		ELSIF(v_esb_header_rec.batch_typ = 'TLL')
		THEN
			v_no_of_cleanup_days := 0;

			DELETE FROM TLL_ESB_BATCH_TRNSFR_DET_TP
			WHERE batch_grp_id in (
				SELECT batch_grp_id FROM tll_esb_batch_trnsfr_cntrl_tx
				WHERE INSTANCE_ID =  v_esb_header_rec.requestInstanceId
				and batch_typ  = v_esb_header_rec.batch_typ
			);

		
			DELETE FROM tll_esb_batch_trnsfr_cntrl_tx 
			WHERE INSTANCE_ID =  v_esb_header_rec.requestInstanceId
			and batch_typ  = v_esb_header_rec.batch_typ;

		END IF;
                Pkg_Batch_Logger.proc_log(if_file_handle, 'DEBUG', 'FN_CLEANUP_SAP_BATCH_PROCESS::Success:Batch Type ='||v_esb_header_rec.batch_typ ,'','');
		RETURN true;
	END FN_CLEANUP_SAP_BATCH_PROCESS;
	
	FUNCTION FN_END_SAP_BATCH_PROCESS(v_esb_header_rec IN esb_header_typ, if_file_handle IN UTL_FILE.FILE_TYPE)
	RETURN boolean
	IS
		v_xmltype       XMLTYPE;
		v_batch_grp_id	tll_esb_batch_trnsfr_cntrl_tx.BATCH_GRP_ID%TYPE;
		v_proc_err            EXCEPTION;
	BEGIN
                Pkg_Batch_Logger.proc_log(if_file_handle, 'DEBUG', 'FN_END_SAP_BATCH_PROCESS::Group ID='||v_esb_header_rec.batch_grp_id ,'','');

		UPDATE tll_esb_batch_trnsfr_cntrl_tx
		SET trnsfr_stat = 'R'
		WHERE v_esb_header_rec.batch_grp_id = v_esb_header_rec.batch_grp_id;

		IF( SQL%ROWCOUNT = 0)
		THEN
			Pkg_Batch_Logger.proc_log(if_file_handle, 'DEBUG', 'FN_END_SAP_BATCH_PROCESS::No Record updated in uc_esb_batch_trnsfr_cntrl_tx','','');
			RAISE v_proc_err;
		END IF;

		UPDATE tll_esb_batch_trnsfr_cntrl_tx
		SET trnsfr_stat = 'R'
		WHERE trnsfr_stat = 'E'
		and batch_typ	= v_esb_header_rec.batch_typ
		and instance_id = v_esb_header_rec.requestInstanceId;

		Pkg_Batch_Logger.proc_log(if_file_handle, 'DEBUG', 'FN_END_SAP_BATCH_PROCESS::Sucessfully Updated transfer status to Ready status for Group ID='||v_esb_header_rec.batch_grp_id ,'','');

		return true;
	END FN_END_SAP_BATCH_PROCESS;
END PKG_ESB_COMMON_UTILS;
/
