CREATE OR REPLACE PACKAGE Pkg_Batch_Logger
AS-- {
/*---------------------------------------------------------------------------------------------*/
/*  Name                  :     PKG_BATCH_LOGGER                                               */
/*  Author                :     Hexaware Technologies                                          */
/*  Purpose               :     This package is executed for every logging onto the Out file   */
/*                                                                                             */
/*  Revision History    :                                                                      */
/*  <<Ver No>>        <<Modified By>>      <<Modified Date>>                                   */
/*      1.0             Vijay Poondy         Nov-2003                                          */
/*      Initial Version                                                                        */
/*---------------------------------------------------------------------------------------------*/
/*      1.1             Venkatachalam        03-May-2004                                       */
/*      Added Sql error messages on exception                                                  */
/*---------------------------------------------------------------------------------------------*/
/*      2.0             Venkatachalam        04-Nov-2004                                       */
/*      Changes in the Message Formatter to avoid Line buffer Overflow                         */
/*---------------------------------------------------------------------------------------------*/
/*      3.0             Venkatachalam        09-Dec-2004                                       */
/*      Added Warning Loglevel in Proc_Log Procedure                                           */
/*      Added Return Code 4 for Warning completion                                             */
/*---------------------------------------------------------------------------------------------*/

	FUNCTION FUNC_OPEN_LOG (
		p_program_name   IN   VARCHAR2)
	RETURN UTL_FILE.FILE_TYPE;
	Procedure PROC_LOG (
		p_file_handle 	IN   UTL_FILE.FILE_TYPE,
		p_logprofile    IN   VARCHAR2,
		p_error_code   	IN   VARCHAR2,
		p_substitute   	IN   VARCHAR2,
		p_identifier	IN   VARCHAR2 );
	Procedure PROC_CLOSE_LOG (
		p_file_handle 	IN    UTL_FILE.FILE_TYPE);
	Procedure PROC_LOG_STATUS (
		p_file_handle 	IN    UTL_FILE.FILE_TYPE,
		p_status	IN   VARCHAR2);
	FUNCTION FUNC_DML_STATUS (
		p_dml	IN	UC_BATCH_PRMTR_MS.CD_VALUE%TYPE)
	RETURN VARCHAR2;
END Pkg_Batch_Logger; -- }
/
CREATE OR REPLACE PACKAGE BODY Pkg_Batch_Logger AS -- {
	--Forward declaration of Message Formatter method
	FUNCTION MESSAGE_FORMATTER (
		p_error_code   IN   VARCHAR2,
		p_substitute   IN   VARCHAR2)
	RETURN VARCHAR2;
	--Forward declaration of log level retrieval function
	FUNCTION GET_LOG_LEVEL RETURN NUMBER;
	FUNCTION MESSAGE_FORMATTER (
		p_error_code   IN   VARCHAR2,
		p_substitute    IN   VARCHAR2)
	RETURN VARCHAR2
	/*
	||	Author 			: Hexaware Technologies
	||	Purpose			: This function substitutes the placeholders in the error messages.
	||	Parameters		: p_error_code,p_substitute
	||
	||	Dependencies		:
	||	Modification History	:
	||     2.0             Venkatachalam        04-Nov-2004                                     
	||     Changes in the Message Formatter to avoid Line buffer Overflow
	||
	*/
	AS
	lv_tmpstr   	VARCHAR2(2000) := NULL;
	ln_cnt    	    NUMBER(3)      := 0;
	ln_end_pos  	NUMBER(3)      := 0;
	lv_TempStr  	VARCHAR2(500)  := ' ';
	lv_position    	VARCHAR2(5)    := ' ';
	lv_errormsg  	VARCHAR2(500)  := ' ';
    lv_lang_cd      VARCHAR2(1) DEFAULT 'E';
    BEGIN -- {
       lv_tmpstr := p_substitute||',';
       BEGIN
          SELECT NVL(CD_VALUE,'E')
          INTO   lv_lang_cd
          FROM   UC_BATCH_PRMTR_MS
          WHERE  PRMTR_CD ='LANG_LOG';
       EXCEPTION
          WHEN NO_DATA_FOUND THEN
             lv_lang_cd      := 'E';
             dbms_output.put_line('Language parameter' || ' - ' ||SYSDATE);
             dbms_output.put_line('Log - No data found in UC_BATCH_PRMTR_MS');
          WHEN TOO_MANY_ROWS THEN
             dbms_output.put_line('Language parameter' || ' - ' ||SYSDATE);
             dbms_output.put_line('Log - Too Many Rows in UC_BATCH_PRMTR_MS');
          WHEN OTHERS THEN
             dbms_output.put_line('Language parameter' || ' - ' ||SYSDATE);
             dbms_output.put_line('Log - Fatal Oracle Error in Selecting in UC_BATCH_PRMTR_MS');
             dbms_output.put_line(SQLERRM);
       END;

       BEGIN --{
          SELECT ERR_TXT
          INTO   lv_errormsg
          FROM   UC_BATCH_ERROR_MS
          WHERE  ERR_CD     = p_error_code
          AND    ERR_LNGUGE = lv_lang_cd;
		--DBMS_OUTPUT.PUT_LINE(l_errormsg);
       EXCEPTION
          WHEN NO_DATA_FOUND THEN
             lv_errormsg := ' ';
             dbms_output.put_line('Error Log' || ' - ' ||SYSDATE);
             dbms_output.put_line('Log - No data found in UC_BATCH_ERROR_MS for ' || p_error_code || ' ' || lv_lang_cd);
          WHEN TOO_MANY_ROWS THEN
             lv_errormsg := ' ';
             dbms_output.put_line('Error Log' || ' - ' ||SYSDATE);
             dbms_output.put_line('Log - Too many Rows in UC_BATCH_ERROR_MS');
          WHEN OTHERS THEN
             lv_errormsg := ' ';
             dbms_output.put_line('Error Log' || ' - ' ||SYSDATE);
             dbms_output.put_line('Log - Fatal Oracle Error in Selecting in UC_BATCH_ERROR_MS');
             dbms_output.put_line(SQLERRM);
       END; --}

       BEGIN --{
          WHILE lv_tmpstr <> ','
          LOOP -- {
              ln_end_pos  := INSTR(lv_tmpstr,',',1,1) - 1 ;
              lv_TempStr  := SUBSTR(lv_tmpstr,1,ln_end_pos);
              lv_position := '{'||ln_cnt||'}';
              lv_errormsg := REPLACE(lv_errormsg, lv_position, lv_TempStr);
              lv_tmpstr   := SUBSTR(lv_tmpstr,ln_end_pos + 2);
              ln_cnt      := ln_cnt + 1;
          END LOOP; -- }
       EXCEPTION
          WHEN OTHERS THEN
             lv_errormsg := ' ';
             dbms_output.put_line('Error Log' || ' - ' ||SYSDATE);
             dbms_output.put_line('Log - Error in Subsituting Values');
             dbms_output.put_line(SQLERRM);
       END; --}

       RETURN lv_errormsg;
       END MESSAGE_FORMATTER;
	FUNCTION FUNC_DML_STATUS (
		p_dml	IN	UC_BATCH_PRMTR_MS.CD_VALUE%TYPE)
		RETURN VARCHAR2
	/*
	||	Author 			: Hexaware Technologies
	||	Purpose			: This function returns the INSERT/UPDATE/DELETE status.
	||				  This function is included for testing purposes.
	||	Parameters		: p_dml
	||
	||	Dependencies		:
	||	Modification History	:
	||
	*/
	AS
		lv_status UC_BATCH_PRMTR_MS.CD_VALUE%TYPE;
	BEGIN
		IF UPPER(p_dml) = 'I' THEN
			SELECT 	CD_VALUE
			INTO 	lv_status
			FROM 	UC_BATCH_PRMTR_MS
			WHERE 	PRMTR_CD = 'INSERT_FLAG';
		END IF;
		IF UPPER(p_dml) = 'U' THEN
			SELECT 	CD_VALUE
			INTO 	lv_status
			FROM 	UC_BATCH_PRMTR_MS
			WHERE 	PRMTR_CD = 'UPDATE_FLAG';
		END IF;
		IF UPPER(p_dml) = 'D' THEN
			SELECT 	CD_VALUE
			INTO 	lv_status
			FROM 	UC_BATCH_PRMTR_MS
			WHERE 	PRMTR_CD = 'DELETE_FLAG';
		END IF;
		RETURN  lv_status;
		EXCEPTION
			WHEN OTHERS THEN
				RETURN  NULL;
	END FUNC_DML_STATUS;
	Procedure PROC_LOG (
			p_file_handle 	IN   UTL_FILE.FILE_TYPE,
			p_logprofile    IN   VARCHAR2,
			p_error_code   	IN   VARCHAR2,
			p_substitute   	IN   VARCHAR2,
			p_identifier	IN   VARCHAR2 )
		/*
		||	Author 			: Hexaware Technologies
		||	Purpose			: This function writes the given message in the given file
		||				  (the file is fetched through file handle).
		||	Parameters		: p_message,p_file_handle
		||
		||	Dependencies		:
		||	Modification History	:
		||
		||      Date : 26-Feb-2004     Modified By : Venkatachalam
		||      Description : 1. Size of the formatted message is increased
		||                    2. Flush the file immediately after logging		
		||      Date : 09-Dec-2004     Modified By : Venkatachalam
        ||      Description : Added Warning Loglevel in Proc_Log Procedure
		*/
		AS
		lv_formatted_msg VARCHAR2(4000);
		ln_current_log_level NUMBER(1) := 0 ;
		ln_maintained_log_level NUMBER;
		BEGIN -- {
			ln_maintained_log_level := GET_LOG_LEVEL;
			IF UPPER(p_logprofile) = 'DEBUG'
				THEN
					ln_current_log_level := 1;
			ELSIF UPPER(p_logprofile) = 'INFO'
				THEN
					ln_current_log_level := 2;
			ELSIF UPPER(p_logprofile) = 'ERROR'
				THEN
					ln_current_log_level := 3;
			ELSIF UPPER(p_logprofile) = 'FATAL'
				THEN
					ln_current_log_level := 4;
			ELSIF UPPER(p_logprofile) = 'REPORT'
				THEN
					ln_current_log_level := 5;
			ELSIF UPPER(p_logprofile) = 'WARNING'
				THEN
					ln_current_log_level := 6;
            ELSE
					ln_current_log_level := 1;
			END IF;
			IF ( ln_current_log_level >= ln_maintained_log_level )
				THEN
				IF (ln_current_log_level NOT IN (1,5,6) )
					THEN
					lv_formatted_msg := MESSAGE_FORMATTER (p_error_code,p_substitute);
				ELSIF (ln_current_log_level = 6 )
					THEN
					lv_formatted_msg := 'WARNING : ' || p_error_code; 
				ELSE
					lv_formatted_msg := p_error_code;
				END IF;
				IF (p_identifier IS NOT NULL)
					THEN
					lv_formatted_msg := lv_formatted_msg || ' ['||p_identifier||'] ';
				END IF;
				UTL_FILE.PUT_LINE(p_file_handle, lv_formatted_msg);
				UTL_FILE.FFLUSH(p_file_handle);
			END IF;
		EXCEPTION
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE(SQLERRM);
	END PROC_LOG;
	FUNCTION GET_LOG_LEVEL
		/*
		||	Author 			: Hexaware Technologies
		||	Purpose			: This function retrieves the log level maintained in Parameter table
		||	Parameters		: None
		||
		||	Dependencies		:
		||	Modification History	:
		||
		*/
		RETURN NUMBER
		AS
		ln_maintained_log_level NUMBER DEFAULT 0;
		BEGIN
			BEGIN --{
				SELECT TO_NUMBER(CD_VALUE)
				INTO   ln_maintained_log_level
				FROM   UC_BATCH_PRMTR_MS
				WHERE  PRMTR_CD = 'LGLVL_CNST';
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					dbms_output.put_line('LOG LEVEL' || ' - '||SYSDATE);
					dbms_output.put_line('Log - No data found for log level');
				WHEN TOO_MANY_ROWS THEN
					dbms_output.put_line('LOG LEVEL' || ' - ' ||SYSDATE);
					dbms_output.put_line('Log - Too many Rows for log level');
				WHEN OTHERS THEN
					dbms_output.put_line('LOG LEVEL'|| ' - ' ||SYSDATE);
					dbms_output.put_line('Error while selecting log level' || ' - ' || SQLERRM);
			END;
		RETURN ln_maintained_log_level;
	END GET_LOG_LEVEL;
	FUNCTION FUNC_OPEN_LOG (
			p_program_name   IN   VARCHAR2)
			RETURN UTL_FILE.FILE_TYPE
			/*
			||	Author 			: Hexaware Technologies
			||	Purpose			: This function creates a log file for the given program in Append mode.
			||	Parameters		: p_program_name
			||
			||	Dependencies		:
			||	Modification History	:
			||    03-may-2004   Venkatachalam R
            ||       Added Sql error messages on exception
			*/
			AS
			lv_file_name VARCHAR2(100);
			lf_file_handle UTL_FILE.FILE_TYPE;
			BEGIN -- {
			lv_file_name  := UPPER(p_program_name) || '.out';
            /*----------------------------------------------------------*/
            /* Spool Directory not mentioned properly in the database   */
            /* Once it has rectified, we need to revert to the old code */
            /*----------------------------------------------------------*/
			BEGIN
		           lf_file_handle := UTL_FILE.FOPEN('SPOOL_DIR',lv_file_name,'A');
		           RETURN lf_file_handle;
	                EXCEPTION
                             WHEN utl_file.invalid_path THEN
                                  dbms_output.put_line('utl_file.invalid_path : <' || SQLERRM || '>');
				  RAISE;
                             WHEN utl_file.invalid_mode THEN
                                  dbms_output.put_line('utl_file.invalid_mode : <' || SQLERRM || '>');
				  RAISE;
                             WHEN utl_file.invalid_filehandle THEN
                                  dbms_output.put_line('utl_file.invalid_filehandle : <' || SQLERRM || '>');
 				  RAISE;
                             WHEN utl_file.invalid_operation THEN
                                  dbms_output.put_line('utl_file.invalid_operation : <' || SQLERRM || '>');
 				  RAISE;
                             WHEN utl_file.read_error THEN
                                  dbms_output.put_line('utl_file.read_error : <' || SQLERRM || '>');
 				  RAISE;
                             WHEN utl_file.write_error THEN
                                  dbms_output.put_line('utl_file.write_error : <' || SQLERRM || '>');
 				  RAISE;
                             WHEN utl_file.internal_error THEN
                                  dbms_output.put_line('utl_file.internal_error : <' || SQLERRM || '>');
 				  RAISE;
                             WHEN OTHERS THEN
                                  dbms_output.put_line('utl_file.other_error : <' || SQLERRM || '>');
 				  RAISE;
                        END;
	END FUNC_OPEN_LOG;
	Procedure PROC_CLOSE_LOG (
		p_file_handle 	IN  UTL_FILE.FILE_TYPE)
		/*
		||	Author 			: Hexaware Technologies
		||	Purpose			: This function closes the given UTL_FILE
		||	Parameters		: p_program_name
		||
		||	Dependencies		:
		||	Modification History	:
		||
		*/
		AS
		lf_file_handle UTL_FILE.FILE_TYPE;
		BEGIN -- {
		lf_file_handle := p_file_handle;
	--	UTL_FILE.FCLOSE(lf_file_handle);
		EXCEPTION
			WHEN OTHERS THEN
        		UTL_FILE.FCLOSE_ALL;
	END PROC_CLOSE_LOG;
	Procedure PROC_LOG_STATUS (
		p_file_handle 	IN  UTL_FILE.FILE_TYPE,
		p_status	IN   VARCHAR2)
		/*
		||	Author 			: Hexaware Technologies
		||	Purpose			: This function writes the return code to log file and closes the log file.
		||
		||	Parameters		: p_message,p_file_handle
		||
		||	Dependencies		:
		||	Modification History	:
		||      Date : 09-Dec-2004     Modified By : Venkatachalam
        ||      Description : Added Return Code 4 for Warning completion
		*/
		AS
		lv_status_msg VARCHAR2(50);
		BEGIN -- {
			IF UPPER(p_status) = 'B'
				THEN
				lv_status_msg := 'RETURN CODE : 1';
			ELSIF UPPER(p_status) = 'C'
				THEN
				lv_status_msg := 'RETURN CODE : 0';
			ELSIF UPPER(p_status) = 'S'
				THEN
				lv_status_msg := 'RETURN CODE : 2';
			ELSIF UPPER(p_status) = 'W'
				THEN
				lv_status_msg := 'RETURN CODE : 4';
			END IF;
			UTL_FILE.PUT_LINE(p_file_handle, lv_status_msg);
			PROC_CLOSE_LOG(p_file_handle);
		EXCEPTION
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE(SQLERRM);
	END PROC_LOG_STATUS;
END Pkg_Batch_Logger; -- }
/

