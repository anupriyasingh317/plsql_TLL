CREATE OR REPLACE FUNCTION UNIQUEKEY
 RETURN VARCHAR2 AS

 ld_number number(30);

BEGIN
--Commented and utilize the functionality of 19C upgrade by Prasanna on 16-10-2020 
-- SELECT  BATCH_GRP_ID_SEQ.nextval
-- INTO  ld_number
-- FROM  dual ;
 
 ld_number:=BATCH_GRP_ID_SEQ.nextval;

 RETURN  ld_number;

 EXCEPTION
  WHEN OTHERS THEN
   RETURN  NULL;


END UNIQUEKEY;
/
