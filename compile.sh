#!/bin/sh
# Build CBLPARTS (COBOL) and mpr.apps.PartsDb (Java) on z/OS USS.
# Copy newcbljni/* to $WORK_DIR first (keeping the mpr/apps folder).
export WORK_DIR="Path to..."/java3164/demo
export COBOL_HOME="Path to COBOL home"
export COB2=$COBOL_HOME/bin/cob2
export JAVA_HOME="Path to Java home"
export STEPLIB='Your COBOL HLQ.SIGYCOMP'. 
export SDFSRESL='Your IMS HLQ.SDFSRESL'
export MPRPGMLIB='Your IMS HLQ.PGMLIB'

export IMSUDB_JAR="Path to IMSUDB.jar"/imsudb.jar

echo ""
echo " Compile and link CBLPARTS"
${COB2} -v -comprc_ok=4 \
    -o "//'${MPRPGMLIB}(CBLPARTS)'" \
    -q"LIST,NODYNAM,MAP,APOST,XREF,THREAD,NOEXP,PGMNAME(LONGMIXED)" \
    -bLET,CASE=MIXED \
    -I "${COBOL_HOME}"/include \
    "${WORK_DIR}"/CBLPARTS.cbl \
    "${COBOL_HOME}"/lib/igzxjni2.x \
    "${JAVA_HOME}"/lib/s390x/j9vm/libjvm31.x \
    -l"//'${SDFSRESL}'"

echo ""
echo "Build mpr/apps/PartsDb.java"
${JAVA_HOME}/bin/javac -J-Xms16m -J-Xmx256m -J-Xnocompressedrefs -J-Xint \
    -d ${WORK_DIR} -cp "${IMSUDB_JAR}" \
    ${WORK_DIR}/mpr/apps/PartsDb.java

