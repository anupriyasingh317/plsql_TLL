CREATE OR REPLACE PROCEDURE Host_Command (p_command  IN VARCHAR2,p_return_cd  IN OUT NUMBER)
AS LANGUAGE JAVA
NAME 'Host.executeCommand (java.lang.String,int[])';
/
