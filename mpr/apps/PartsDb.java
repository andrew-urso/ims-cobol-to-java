package mpr.apps;
import com.ibm.ims.jdbc.IMSDataSource;
import java.nio.ByteBuffer;
import java.nio.charset.Charset;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.util.Arrays;

/**
 * Called from COBOL (PARTSCBL) through JNI. COBOL owns the IMS message
 * queue; this class only runs the SQL for one request.
 *
 * Shared direct buffer layout (must match SHARED-BUFFER in PARTSCBL.cbl):
 *   bytes   0..79   request (EBCDIC): cmd(4) partkey(17) partname(12)
 *                   partdesc(21), preceded by any number of blanks
 *   bytes  80..279  reply (EBCDIC, blank padded), written by this class
 */
public class PartsDb {

    private static final String PSB_NAME = "CBLPARTS";
    private static final String TABLE_NAME = "DBPCB01.PARTROOT";
    private static final Charset EBCDIC = Charset.forName("Cp1047");
    private static final int REQ_LEN = 80;
    private static final int REPLY_LEN = 200;
    private static final int REQ_FIELDS_LEN = 54;

    private static Connection connection = null;

    public static void handle(ByteBuffer buf) {
        String reply;
        try {
            byte[] req = new byte[REQ_LEN];
            buf.position(0);
            buf.get(req);
            reply = process(new String(req, EBCDIC));
        } catch (Throwable t) {
            log("Exception: " + t);
            connection = null;
            reply = "ERROR: " + t;
        }

        byte[] out = new byte[REPLY_LEN];
        Arrays.fill(out, (byte) 0x40);
        byte[] r = reply.getBytes(EBCDIC);
        System.arraycopy(r, 0, out, 0, Math.min(r.length, REPLY_LEN));
        buf.position(REQ_LEN);
        buf.put(out);
    }

    private static String process(String request) throws SQLException {
        int i = 0;
        while (i < request.length() && request.charAt(i) == ' ') {
            i++;
        }
        StringBuilder sb = new StringBuilder(request.substring(i));
        while (sb.length() < REQ_FIELDS_LEN) {
            sb.append(' ');
        }
        String s = sb.toString();

        String cmd = s.substring(0, 4).trim();
        String key = s.substring(4, 21).trim();
        String name = s.substring(21, 33).trim();
        String desc = s.substring(33, 54).trim();

        if (key.isEmpty()) {
            return "ERROR: PARTKEY IS REQUIRED";
        }

        Connection c = getConnection();
        if (cmd.equalsIgnoreCase("ADD")) {
            return addPart(c, key, name, desc);
        } else if (cmd.equalsIgnoreCase("UPD")) {
            return updatePart(c, key, name, desc);
        } else if (cmd.equalsIgnoreCase("DEL")) {
            return deletePart(c, key);
        } else if (cmd.equalsIgnoreCase("GET")) {
            return getPart(c, key);
        }
        return "ERROR: INVALID COMMAND WAS SPECIFIED";
    }

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

    private static String addPart(Connection c, String key, String name, String desc)
            throws SQLException {
        String sql = "INSERT INTO " + TABLE_NAME + " (PARTKEY, PARTNAME, PARTDESC) VALUES ('"
                + q(key) + "', '" + q(name) + "', '" + q(desc) + "')";
        int count = update(c, sql);
        return count > 0
                ? "INFO: PART WITH PARTKEY " + key + " WAS SUCCESSFULLY ADDED, COUNT = " + count
                : "ERROR: PART WITH PARTKEY " + key + " WAS NOT ADDED SUCCESSFULLY";
    }

    private static String updatePart(Connection c, String key, String name, String desc)
            throws SQLException {
        String sql = "UPDATE " + TABLE_NAME + " SET PARTNAME = '" + q(name)
                + "', PARTDESC = '" + q(desc) + "' WHERE PARTKEY = '" + q(key) + "'";
        int count = update(c, sql);
        return count > 0
                ? "INFO: PART WITH PARTKEY " + key + " WAS SUCCESSFULLY UPDATED, COUNT = " + count
                : "ERROR: PART WITH PARTKEY " + key + " WAS NOT UPDATED SUCCESSFULLY";
    }

    private static String deletePart(Connection c, String key) throws SQLException {
        String sql = "DELETE FROM " + TABLE_NAME + " WHERE PARTKEY = '" + q(key) + "'";
        int count = update(c, sql);
        return count > 0
                ? "INFO: PART WITH PARTKEY " + key + " WAS SUCCESSFULLY DELETED, COUNT = " + count
                : "ERROR: PART WITH PARTKEY " + key + " WAS NOT DELETED SUCCESSFULLY";
    }

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

    private static int update(Connection c, String sql) throws SQLException {
        log("SQL: " + sql);
        try (Statement st = c.createStatement()) {
            return st.executeUpdate(sql);
        }
    }

    private static String q(String s) {
        return s.replace("'", "''");
    }

    private static void log(String text) {
        System.out.println(" " + new Timestamp(System.currentTimeMillis()) + " " + text);
    }
}
