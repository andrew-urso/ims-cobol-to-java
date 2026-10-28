# ims-cobol-to-java

## Getting Started

In this sample program, you will set up an IMS MPR region to run a COBOL application that uses the Java Native Interface (JNI) to communicate with Java.

You will learn how to run a 31-bit COBOL application that communicates with 64-bit Java™ in an IBM® IMS message processing region (MPR). This interoperability between 31-bit COBOL and 64-bit Java in an IMS dependent region is a new feature of IMS V15.

---

### Prerequisites

To complete this sample program in your environment, you need the following:

| Requirement | Details |
|---|---|
| Java | 8 or later (on z/OS) |
| COBOL | 6.4 or later |
| IDE | Any |
| z/OS access | 3270 connection or Zowe Explorer |
| RACF | Read authority on SMP/E installed IMS libraries |
| RACF | Update authority on the HLQs used for IMS instance libraries |

You also need familiarity with the following technologies:

| Technology | Level |
|---|---|
| Java programming | Beginner |
| SQL | Beginner |
| z/OS | Intermediate |
| IMS | Intermediate |
| COBOL | Beginner |

---

### Download the ims-java-jmp from GitHub

Download the ims-java-jmp project by clicking **Clone or Download** and then selecting **Download ZIP**.

---

## Part 1: Creating a JNI-enabled COBOL Program

Your COBOL application has already been provided in this repository. Refer to the Code Overview below for an explanation of how the application utilizes the Java Native Interface.

### Code Overview

The application performs the following high-level actions:

**1. Print progress messages**

Prints informational messages to SYSOUT throughout execution to indicate progress, as described in the following sections.

**2. Retrieve a message from the IMS message queue**

```cobol
CALL 'CBLTDLI' USING GU-FUNC, IOPCB, INPUT-MESSAGE
```

**3. Call Java code via JNI**

```cobol
CALL CallStaticVoidMethod USING BY VALUE JNIEnvPtr
                                BY VALUE CLASSID
                                BY VALUE METHODID
                                BY VALUE BUFFER-REF
```

**4. Insert a reply using the IOPCB**

```cobol
CALL 'CBLTDLI' USING ISRT-FUNC, IOPCB, OUTPUT-MESSAGE
```

**5. Loop until QC status**

Repeats steps 2–4 until IMS returns a QC status code indicating the application needs to terminate. 

For simplicity, the name of the COBOL program and the IMS transaction are both `CBLPARTS` — note that they do not have to be the same. The full name of the Java class is `mpr.apps.PartsDb` and the method called is `handle(ByteBuffer buf)`, located in `mpr/apps/PartsDb.java`.

The `handle` method expects a single `ByteBuffer` argument. The COBOL code wraps the `SHARED-BUFFER` working-storage variable in a direct byte buffer and passes it as that argument. Before the call, a GetUnique is issued against the IMS message queue to pull a message and populate `SHARED-BUFFER`.

**6. Supported message types**

The program accepts four command types:

```
CBLPARTS GET "PARTKEY"
CBLPARTS ADD "PARTKEY" "PARTNAME" "PARTDESC"
CBLPARTS DEL "PARTKEY"
CBLPARTS UPD "PARTKEY" "PARTNAME (New)" "PARTDESC (New)"
```

These messages are passed to `PartsDb.java` and translated into SQL calls against the Parts Database (`DI21PART`).

---

## Part 2: Creating a JNI-enabled Java Program

Your Java application has already been provided in this repository. Refer to the Code Overview below for an explanation of how the application utilizes the Java Native Interface.

### Code Overview

The application performs the following high-level actions:

**1. Read the buffer sent by CBLPARTS**

```java
public static void handle(ByteBuffer buf) {
    String reply;
    try {
        byte[] req = new byte[REQ_LEN];
        buf.position(0);
        buf.get(req);
        reply = process(new String(req, EBCDIC));
    }
```

**2. Open a JDBC connection to the CBLPARTS PSB**

More information on this PSB is detailed later in this readme. Before deploying to z/OS, update the `setUser` and `setPassword` fields with your z/OS credentials.

```java
private static synchronized Connection getConnection() throws SQLException {
    if (connection == null) {
        IMSDataSource ds = new IMSDataSource();
        ds.setDriverType(2);
        ds.setDatabaseName(CBLPARTS);
        ds.setUser("username");
        ds.setPassword("password");
        connection = ds.getConnection();
    }
    return connection;
}
```

**3. Execute SQL against the CBLPARTS PSB**

The messages received from `CBLPARTS.cbl` are used to construct SQL statements. For example, a `GET` command runs:

```java
private static String getPart(Connection c, String key) throws SQLException {
    String sql = "SELECT * FROM " + TABLE_NAME + " WHERE PARTKEY = '" + q(key) + "'";
    log("SQL: " + sql);
    String msg = "ERROR: NO PART WITH PARTKEY " + key + " WAS FOUND";
    try (Statement st = c.createStatement(); ResultSet rs = st.executeQuery(sql)) {
        while (rs.next()) {
            msg = "PARTKEY: " + rs.getString("PARTKEY")
                    + ", PARTNAME: " + rs.getString("PARTNAME")
                    + ", PARTDESC: " + rs.getString("PARTDESC");
        }
    }
    return msg;
}
```

**4. Return the result to COBOL**

The SQL result is written back into the shared buffer, returned to `CBLPARTS.cbl`, and printed as an IMS output message:

```
PARTSCBL: Request  :  GET 027618032P101
PARTSCBL: Calling Java
PARTSCBL: Reply    : PARTKEY: 027618032P101    , PARTNAME:          CAP, PARTDESC:       CAPACITOR
```

---

## Part 3: Compiling and Deploying the Programs

### Compiling CBLPARTS.cbl and PartsDb.java

1. A script called `compile.sh` is provided in this repository. You may need to update the path variables for your environment. FTP/transfer this file to the root of your USS user directory.

2. A configuration file called `stdenv01.cfg` is provided in this repository. It sets the classpath and libpath for your Java program. You may need to update the path variables for your environment. FTP this file to USS and note the directory in which it is stored.

3. Create the following directory structure on USS and place the source files accordingly:

   ```
   java3164/
   └── demo/
       ├── CBLPARTS.cbl
       └── mpr/
           └── apps/
               └── PartsDb.java
   ```

   This ensures that the classpath specified in the COBOL program resolves correctly.

4. Compile both programs by running the following from the root of your USS user directory:

   ```sh
   ./compile.sh
   ```

   You should see a message confirming successful compilation. The outputs will be:

   | Artifact | Location |
   |---|---|
   | Compiled Java class | `java3164/demo/mpr/apps/PartsDb.class` |
   | Compiled COBOL load module | Your IMS program library PDS (as specified in `compile.sh`) |

---

### Configure IMS to Run CBLPARTS

1. `PartsDb.java` uses the DBD `DI21PART`. If field metadata has not been populated, the DDL to do so can be found in `DDL/DI21PART.ddl`.

2. Create a new PSB named `CBLPARTS`. The DDL can be found in `DDL/CBLPARTS.ddl`.

3. Define a PGM resource:

   ```
   CREATE PGM NAME(CBLPARTS) SET(FP(N) BMPTYPE(N) GPSB(N))
   ```

4. Define a Transaction. Note that `CLASS(XXX)` is a placeholder — take note of the class you assign here, as it is needed in the next step.

   ```
   CREATE TRAN NAME(CBLPARTS) SET(FP(N) PGM(CBLPARTS) MSGTYPE(SNGLSEG) RESP(Y) WFI(Y) CLASS(XXX))
   ```

5. Create the MPR startup job using the `CBLPARTS.jcl` template provided in this repository. Supply the class chosen above to the `CL1`, `CL2`, `CL3`, and `CL4` parameters on line 5, then copy the job to `"Your IMSHLQ".JOBS` on z/OS.

---

## Part 4: Run and Interact with CBLPARTS

1. Ensure the DBD (`DI21PART`), PGM (`CBLPARTS`), and Transaction (`CBLPARTS`) resources are all started.

2. Start the MPR by submitting the following command in SDSF:

   ```
   /R XX,/START REGION CBLPARTS
   ```

3. A message confirming the region started successfully should appear in your SDSF/IMS logs.

4. Submit transactions using the commands below. After each command, issue `/R XX,.` to view the IMS response.

   **Add a part:**
   ```
   /R XX,CBLPARTS RUNPARTS ADD 027618032P101    CAT 6 ETHERNET
   ```

   **Retrieve the part:**
   ```
   /R XX,CBLPARTS RUNPARTS GET 027618032P101
   ```
   IMS will return the `PARTNAME` and `PARTDESC` associated with the specified `PARTKEY`.

   **Update the part:**
   ```
   /R XX,CBLPARTS RUNPARTS UPD 027618032P101    CAT 6 ETHERNET
   ```

   **Delete the part:**
   ```
   /R XX,CBLPARTS RUNPARTS DEL 027618032P303
   ```

---

You have successfully set up an IMS MPR region running a COBOL application that communicates with Java through the JNI. This sample demonstrates how 31-bit COBOL and 64-bit Java can work together in an IMS dependent region to process transactions and execute SQL against an IMS database.
