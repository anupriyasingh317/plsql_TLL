CREATE OR REPLACE FUNCTION Func_Get_Process_Date

 RETURN DATE AS

 ld_process_date date;

BEGIN

 SELECT  SYSDATE
 INTO  ld_process_date
 FROM  dual ;

 RETURN  ld_process_date;

 EXCEPTION
  WHEN OTHERS THEN
   RETURN  NULL;



END Func_Get_Process_Date;
/

