       IDENTIFICATION DIVISION.
       PROGRAM-ID. 'CBLPARTS' RECURSIVE.
      *****************************************************
      * IMS MPP: COBOL owns the message queue (GU / ISRT).*
      * Each request is handed to Java (mpr.apps.PartsDb) *
      * through JNI. Java runs the SQL against the parts  *
      * database and writes the reply text back into the  *
      * shared buffer.                                    *
      *                                                   *
      * Request text (after the transaction code), blank  *
      * delimited start, then fixed columns:              *
      *   cmd(4) partkey(17) partname(12) partdesc(21)    *
      *   cmd = ADD / UPD / DEL / GET                     *
      *****************************************************

       ENVIRONMENT DIVISION.

       CONFIGURATION SECTION.

       DATA DIVISION.

       WORKING-STORAGE SECTION.
       77  QC                     PIC X(2) VALUE 'QC'.
       77  GU-FUNC                PIC X(4) VALUE 'GU  '.
       77  ISRT-FUNC              PIC X(4) VALUE 'ISRT'.

       01  INPUT-MESSAGE.
           03  IN-LL              PIC S9(4) COMP.
           03  IN-ZZ              PIC S9(4) COMP.
           03  IN-TRANCODE        PIC X(8).
           03  IN-DATA            PIC X(80).

       01  OUTPUT-MESSAGE.
           02  OUT-LL             PIC S9(4) COMP VALUE +204.
           02  OUT-ZZ             PIC S9(4) COMP VALUE +0.
           02  OUT-DATA           PIC X(200) VALUE SPACES.

      *****************************************************
      * Buffer shared with Java: request first, then      *
      * reply. Must match REQ_LEN / REPLY_LEN in PartsDb. *
      *****************************************************
       01  SHARED-BUFFER.
           02  SB-REQUEST         PIC X(80).
           02  SB-REPLY           PIC X(200).

       LOCAL-STORAGE SECTION.

       01  BUFFER-PTR             USAGE POINTER.
       01  BUFFER-LEN             PIC S9(18) COMP-5.
       01  BUFFER-REF             PIC 9(18) COMP-5.

       01  CLASS-NAME-UTF8        PIC X(64).
       01  METHOD-NAME-UTF8       PIC X(64).
       01  METHOD-SIG-UTF8        PIC X(64).

       01  CLASSID                PIC 9(18) COMP-5.
       01  METHODID               PIC 9(18) COMP-5.

       01  ERR-FLAG               PIC X(1) VALUE X'00'.

       LINKAGE SECTION.
           COPY JNI.

       01  IOPCB.
           02  IO-LTERM           PIC X(8).
           02  IO-RESV            PIC X(2).
           02  IO-STATUS          PIC X(2).
           02  IO-PREF            PIC X(12).
           02  IO-MODN            PIC X(8).
           02  IO-USERID          PIC X(8).
           02  IO-GROUPID         PIC X(8).

       PROCEDURE DIVISION USING IOPCB.

           DISPLAY 'CBLPARTS: Execution begin'.

           PERFORM READ-MESSAGE.
           PERFORM UNTIL IO-STATUS NOT = SPACES
               PERFORM PROCESS-MESSAGE
               PERFORM SEND-REPLY
               PERFORM READ-MESSAGE
           END-PERFORM.

           IF IO-STATUS NOT = QC
               DISPLAY 'CBLPARTS: Unexpected IO-STATUS: ' IO-STATUS
           END-IF.

           DISPLAY 'CBLPARTS: Execution end'.
           GOBACK.

      *****************************************************
       READ-MESSAGE.
           MOVE SPACES TO IN-DATA.
           CALL 'CBLTDLI' USING GU-FUNC, IOPCB, INPUT-MESSAGE.

      *****************************************************
       PROCESS-MESSAGE.
           DISPLAY 'CBLPARTS: Request  : ' IN-DATA.
           MOVE IN-DATA TO SB-REQUEST.
           MOVE SPACES  TO SB-REPLY.
           PERFORM GET-JAVA-OBJECTS.
           IF METHODID NOT = 0
               DISPLAY 'CBLPARTS: Calling Java'
               CALL CallStaticVoidMethod USING BY VALUE JNIEnvPtr
                                               BY VALUE CLASSID
                                               BY VALUE METHODID
                                               BY VALUE BUFFER-REF
               PERFORM CHECK-JAVA-ERROR
               CALL DeleteLocalRef USING BY VALUE JNIEnvPtr
                                         BY VALUE BUFFER-REF
               CALL DeleteLocalRef USING BY VALUE JNIEnvPtr
                                         BY VALUE CLASSID
               MOVE SB-REPLY TO OUT-DATA
           ELSE
               MOVE 'ERROR: COULD NOT FIND JAVA METHOD' TO OUT-DATA
           END-IF.
           DISPLAY 'CBLPARTS: Reply    : ' OUT-DATA.

      *****************************************************
       SEND-REPLY.
           CALL 'CBLTDLI' USING ISRT-FUNC, IOPCB, OUTPUT-MESSAGE.
           IF IO-STATUS NOT = SPACES
               DISPLAY 'CBLPARTS: ISRT IO-STATUS: ' IO-STATUS
           END-IF.

      *****************************************************
       GET-JAVA-OBJECTS.
           MOVE 0 TO METHODID.

           SET ADDRESS OF JNIEnv             TO JNIEnvPtr.
           SET ADDRESS OF JNINativeInterface TO JNIEnv.

           STRING FUNCTION DISPLAY-OF(N'mpr/apps/PartsDb', 1208)
                  X'00'
                  DELIMITED BY SIZE
                  INTO CLASS-NAME-UTF8.

           CALL FindClass USING BY VALUE JNIEnvPtr
                                BY VALUE ADDRESS OF CLASS-NAME-UTF8
                          RETURNING CLASSID.
           PERFORM CHECK-JAVA-ERROR.

           STRING FUNCTION DISPLAY-OF(N'handle', 1208)
                  X'00'
                  DELIMITED BY SIZE
                  INTO METHOD-NAME-UTF8.

           STRING FUNCTION DISPLAY-OF(N'(Ljava/nio/ByteBuffer;)V',
                                      1208)
                  X'00'
                  DELIMITED BY SIZE
                  INTO METHOD-SIG-UTF8.

           CALL GetStaticMethodID USING
                                  BY VALUE JNIEnvPtr
                                  BY VALUE CLASSID
                                  BY VALUE ADDRESS OF METHOD-NAME-UTF8
                                  BY VALUE ADDRESS OF METHOD-SIG-UTF8
                                  RETURNING METHODID.
           PERFORM CHECK-JAVA-ERROR.

           COMPUTE BUFFER-LEN = LENGTH OF SHARED-BUFFER.
           SET BUFFER-PTR TO ADDRESS OF SHARED-BUFFER.

           CALL NewDirectByteBuffer USING
                            BY VALUE JNIEnvPtr
                            BY VALUE BUFFER-PTR
                            BY VALUE BUFFER-LEN
                            RETURNING BUFFER-REF.
           PERFORM CHECK-JAVA-ERROR.

      *****************************************************
       CHECK-JAVA-ERROR.
           CALL ExceptionCheck USING BY VALUE JNIEnvPtr
                                 RETURNING ERR-FLAG.
           IF ERR-FLAG = X'01'
               DISPLAY 'CBLPARTS: Unhandled Java exception'
               CALL ExceptionDescribe USING BY VALUE JNIEnvPtr
               CALL ExceptionClear USING BY VALUE JNIEnvPtr
               GOBACK
           END-IF.
           MOVE X'00' TO ERR-FLAG.
