import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Properties;

import java.time.LocalDateTime;
import java.sql.Timestamp;
import java.util.Vector;

public class GigSystem {

    public static void main(String[] args) {

        // You should only need to fetch the connection details once
        // You might need to change this to either getSocketConnection() or getPortConnection() - see below
        Connection conn = getSocketConnection();

        boolean repeatMenu = true;
        
        while(repeatMenu){
            System.out.println("_________________________");
            System.out.println("________GigSystem________");
            System.out.println("_________________________");

            
            System.out.println("q: Quit");

            String menuChoice = readEntry("Please choose an option: ");

            if(menuChoice.length() == 0){
                //Nothing was typed (user just pressed enter) so start the loop again
                continue;
            }
            char option = menuChoice.charAt(0);

            /**
             * If you are going to implement a menu, you must read input before you call the actual methods
             * Do not read input from any of the actual option methods
             */
            switch(option){
                case '1':
                    break;

                case '2':
                    break;
                case '3':
                    break;
                case '4':
                    break;
                case '5':
                    break;
                case '6':
                    break;
                case '7':
                    break;
                case '8':
                    break;
                case 'q':
                    repeatMenu = false;
                    break;
                default: 
                    System.out.println("Invalid option");
            }
        }
    }

    /*
     * You should not change the names, input parameters or return types of any of the predefined methods in GigSystem.java
     * You may add extra methods if you wish (and you may overload the existing methods - as long as the original version is implemented)
     */


    /*
     * In the SELECT query I joined tables act and act_gig and selected the columns where gigid is equal to the given gigid.
     * Start time timestamp was casted to time.
     * End time was calculated by adding the duration as interval to the start time and casted to time.
     */
    public static String[][] option1(Connection conn, int gigID){
        String[][] result = null;
        String selectQuery = "SELECT act.actname, act_gig.ontime::timestamp::time, (act_gig.ontime::timestamp + act_gig.duration * interval '1 minute')::time AS offTime FROM act_gig INNER JOIN act ON act_gig.actID = act.actID WHERE gigID = ? ORDER BY ontime ASC";
        try{
            PreparedStatement preparedStatement = conn.prepareStatement(selectQuery);
            preparedStatement.setInt(1, gigID);
            ResultSet rs = preparedStatement.executeQuery();
            result = convertResultToStrings(rs);
            preparedStatement.close();
            rs.close();
        } catch (SQLException e) {
            System.err.format("SQL State: %s\n%s\n", e.getSQLState(), e.getMessage());
            e.printStackTrace();
        }
        return result;
    }


    /*
     * First I added all acts to new table newacts where constraints are checked.
     * Then we need to check all specified constrains listed in the description.
     * Function in sqlschema.sql checks all the specified constraints and inserts the acts, gig and ticket.
     * First we create a gig and get the new gigid. Then we insert ticket details into gig_ticket. If both insertions are successful, we proceed to checking the requirements listed in the description.
     * 
     * We use for loop to iterate through all the acts in the newacts table.
     * Every act is checked for the specified constraints.
     * If the act is valid, we insert the act into act_gig table.
     * If the act is not valid, we delete all the acts from the newacts table, delete inserted acts from act_gig table, delete the gig_ticket and gig from corresponding tables and break the loop.
     */
    public static void option2(Connection conn, String venue, String gigTitle, int[] actIDs, int[] fees, LocalDateTime[] onTimes, int[] durations, int adultTicketPrice){
        try {
            String deleteActs = "DELETE FROM newacts";
            PreparedStatement preparedStatement1 = conn.prepareStatement(deleteActs);
            preparedStatement1.executeUpdate();
            preparedStatement1.close();

            for (int i = 0; i < actIDs.length; i++) {
                String insertActs = "INSERT INTO newacts (actID, ontime, duration, actfee) VALUES (?, ?, ?, ?)";
                PreparedStatement preparedStatement2 = conn.prepareStatement(insertActs);
                preparedStatement2.setInt(1, actIDs[i]);
                preparedStatement2.setTimestamp(2, Timestamp.valueOf(onTimes[i]));
                preparedStatement2.setInt(3, durations[i]);
                preparedStatement2.setInt(4, fees[i]);
                preparedStatement2.executeUpdate();
                preparedStatement2.close();
            }

            String cc = "SELECT checkAllConditions(?, ?, ?, ?);";
            PreparedStatement preparedStatement3 = conn.prepareStatement(cc);
            preparedStatement3.setString(1, venue);
            preparedStatement3.setInt(2, adultTicketPrice);
            preparedStatement3.setTimestamp(3, Timestamp.valueOf(onTimes[0]));
            preparedStatement3.setString(4, gigTitle);
            ResultSet rs = preparedStatement3.executeQuery();
            preparedStatement3.close();
            rs.close();
        } catch (SQLException e) {
            System.err.format("SQL State: %s\n%s\n", e.getSQLState(), e.getMessage());
            e.printStackTrace();
        }
    }


    /*
     * We created the function in sqlschema.sql that checks the specified constraints and inserts the ticket into the table if the constraints are met.
     * Constraints: check ticketType, check venue capacity(we check if the number of tickets is less than the capacity of the venue), check if the gig is Going ahead.
     */
    public static void option3(Connection conn, int gigid, String name, String email, String ticketType){
        String selectQuery = "SELECT checkTicketConditions(?, ?, ?, ?)";
        try {
            PreparedStatement preparedStatement = conn.prepareStatement(selectQuery);
            preparedStatement.setInt(1, gigid);
            preparedStatement.setString(2, ticketType);
            preparedStatement.setString(3, name);
            preparedStatement.setString(4, email);
            ResultSet rs = preparedStatement.executeQuery();
            if (rs.next()) {
                if (rs.getBoolean(1)) {
                    System.out.println("Ticket successfully purchased");
                } else {
                    System.out.println("Ticket purchase failed");
                }
            }
            preparedStatement.close();
            rs.close();
        } catch (SQLException e) {
            System.err.format("SQL State: %s\n%s\n", e.getSQLState(), e.getMessage());
            e.printStackTrace();
        }
    }


    /*
     * For option 4 we created a function in sqlschema.sql that checks if act can be safely deleted without breaking any constraints. Otherwise function deletes the whole gig.
     * First we check if the act that we want to delete is in the gig.
     * Then we check if the act is the headline and act is the first act in the gig
     * We also need to check the case when the act we want to delete is in between two other acts and has a duration more than 20 minutes. In this case whole gig should be cancelled because there will be a gap of more than 20 minutes between acts.
     * If act can be safely deleted, we delete it from act_gig table. Otherwise we set ticket price to 0, change gig status to 'Cancelled' and delete all acts in this gig from act_gig.
     * We return query that has affected emails.
     */
    public static String[] option4(Connection conn, int gigID, String actName){
        try {
            String selectQuery = "SELECT * FROM checkGigConditions(?, ?);";
            PreparedStatement preparedStatement = conn.prepareStatement(selectQuery, ResultSet.TYPE_SCROLL_SENSITIVE, ResultSet.CONCUR_UPDATABLE);
            preparedStatement.setInt(1, gigID);
            preparedStatement.setString(2, actName);
            ResultSet rs = preparedStatement.executeQuery();
            int rowCount = 0;
            if (rs.last()) {
                rowCount = rs.getRow();
                rs.beforeFirst();
            }
            String [] result = new String[rowCount];
            int i = 0;
            while (rs.next()) {
                result[i] = rs.getString(1);
                i++;
            }
            preparedStatement.close();
            rs.close();
            return result;
        } catch (SQLException e) {
            System.err.format("SQL State: %s\n%s\n", e.getSQLState(), e.getMessage());
            e.printStackTrace();
        }
        return null;
    }


    /*
     * For option 5 I created a view which shows all gigs and number of tickets needed to sell.
     * In the query we took data from tables gig and venue to get venue hirecost.
     * To find the number of tickets needed to sell we sum all the act fees and add the venue hirecost. Then we divide this value by the price of the ticket of 'A' type.
     * Finally we subtract the number of tickets sold for the gig.
     */
    public static String[][] option5(Connection conn){
        String [][] result = null;
        String getTQuery = "SELECT * FROM tickets_to_sell;";
        try {
            PreparedStatement preparedStatement = conn.prepareStatement(getTQuery);
            ResultSet rs = preparedStatement.executeQuery();
            result = convertResultToStrings(rs);
            preparedStatement.close();
            rs.close();
        } catch (SQLException e) {
            System.err.format("SQL State: %s\n%s\n", e.getSQLState(), e.getMessage());
            e.printStackTrace();
        }
        return result;
    }


    /*
     * For option 6 I created a set of views that will help us get the desired result.
     * First we select all the gigs that are headlines. We get that for every gig selected we will have only one act.
     * Then we select total number of tickets sold by each act in specific year. Columns include act name, year in text format and number of tickets sold this year.
     * Then we select total number of tickets sold by each act from all years. Columns include act name, 'Total', and number of tickets sold.
     * Finall we combine the two quiries and get the result, which we sort using partitions.
     */
    public static String[][] option6(Connection conn){
        String [][] result = null;
        String ticketsSoldQuery = "SELECT * FROM combined_tickets ORDER BY MAX(tcount) OVER(PARTITION BY actName) ASC, actName ASC, actYear ASC;";
        try {
            PreparedStatement preparedStatement = conn.prepareStatement(ticketsSoldQuery);
            ResultSet rs = preparedStatement.executeQuery();
            result = convertResultToStrings(rs);
            preparedStatement.close();
            rs.close();
        } catch (SQLException e) {
            System.err.format("SQL State: %s\n%s\n", e.getSQLState(), e.getMessage());
            e.printStackTrace();
        }
        return result;
    }


    /*
     * For option 7 we created a set of views that will help us get the desired result.
     * First create a view that shows customers who bought tickets acts, with act name and year and number of tickets bought. This data is selected from headliner acts.
     * Then we create a view that shows actNames and in how many distinct years this act performed
     * Then we create a view that shows in how many distinct years customer bought tickets for specific acts.
     * After that we create a view that filters out customers who didn't buy tickets every year that act performed.
     * Additionally we created a view for acts that doesn't have any regular customers and fill customer name column with 'None'.
     * Finally we combine the two views and get the result, which we order by act name and ticket count.
     */
    public static String[][] option7(Connection conn){
        String [][] result = null;
        String regularCustomersQuery = "SELECT actN, custN FROM regularCustomers ORDER BY actN ASC, tcount DESC, custN ASC;";
        try{
            PreparedStatement preparedStatement = conn.prepareStatement(regularCustomersQuery);
            ResultSet rs = preparedStatement.executeQuery();
            result = convertResultToStrings(rs);
            preparedStatement.close();
            rs.close();
        } catch (SQLException e) {
            System.err.format("SQL State: %s\n%s\n", e.getSQLState(), e.getMessage());
            e.printStackTrace();
        }
        return result;
    }


    /*
     * For option 8 we created a set of views that will help us get the desired result.
     * First one computes the average ticket price by dividing the total price sum of all tickets sold by the total number of tickets sold for the specific gig.
     * Then we create a view that returns a table of feasible acts, where we mark act as feasible if number of tickets that needs to be sold is less than or equal than venue capacity.
     * Finally we order the result by venue name and number of tickets that needs to be sold.
     */
    public static String[][] option8(Connection conn){
        String [][] result = null;
        String feasibleQuery = "SELECT * FROM feasible_act ORDER BY vName ASC, ticketC DESC;";
        try{
            PreparedStatement preparedStatement = conn.prepareStatement(feasibleQuery);
            ResultSet rs = preparedStatement.executeQuery();
            result = convertResultToStrings(rs);
            preparedStatement.close();
            rs.close();
        } catch (SQLException e) {
            System.err.format("SQL State: %s\n%s\n", e.getSQLState(), e.getMessage());
            e.printStackTrace();
        }
        return result;
    }

    /**
     * Prompts the user for input
     * @param prompt Prompt for user input
     * @return the text the user typed
     */

    private static String readEntry(String prompt) {
        
        try {
            StringBuffer buffer = new StringBuffer();
            System.out.print(prompt);
            System.out.flush();
            int c = System.in.read();
            while(c != '\n' && c != -1) {
                buffer.append((char)c);
                c = System.in.read();
            }
            return buffer.toString().trim();
        } catch (IOException e) {
            return "";
        }

    }
     
    /**
    * Gets the connection to the database using the Postgres driver, connecting via unix sockets
    * @return A JDBC Connection object
    */
    public static Connection getSocketConnection(){
        Properties props = new Properties();
        props.setProperty("socketFactory", "org.newsclub.net.unix.AFUNIXSocketFactory$FactoryArg");
        props.setProperty("socketFactoryArg",System.getenv("HOME") + "/cs258-postgres/postgres/tmp/.s.PGSQL.5432");
        Connection conn;
        try{
          conn = DriverManager.getConnection("jdbc:postgresql://localhost/cwk", props);
          return conn;
        }catch(Exception e){
            e.printStackTrace();
        }
        return null;
    }

    /**
     * Gets the connection to the database using the Postgres driver, connecting via TCP/IP port
     * @return A JDBC Connection object
     */
    public static Connection getPortConnection() {
        
        String user = "postgres";
        String passwrd = "password";
        Connection conn;

        try {
            Class.forName("org.postgresql.Driver");
        } catch (ClassNotFoundException x) {
            System.out.println("Driver could not be loaded");
        }

        try {
            conn = DriverManager.getConnection("jdbc:postgresql://127.0.0.1:5432/cwk?user="+ user +"&password=" + passwrd);
            return conn;
        } catch(SQLException e) {
            System.err.format("SQL State: %s\n%s\n", e.getSQLState(), e.getMessage());
            e.printStackTrace();
            System.out.println("Error retrieving connection");
            return null;
        }
    }

    public static String[][] convertResultToStrings(ResultSet rs){
        Vector<String[]> output = null;
        String[][] out = null;
        try {
            int columns = rs.getMetaData().getColumnCount();
            output = new Vector<String[]>();
            int rows = 0;
            while(rs.next()){
                String[] thisRow = new String[columns];
                for(int i = 0; i < columns; i++){
                    thisRow[i] = rs.getString(i+1);
                }
                output.add(thisRow);
                rows++;
            }
            // System.out.println(rows + " rows and " + columns + " columns");
            out = new String[rows][columns];
            for(int i = 0; i < rows; i++){
                out[i] = output.get(i);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return out;
    }

    public static void printTable(String[][] out){
        int numCols = out[0].length;
        int w = 20;
        int widths[] = new int[numCols];
        for(int i = 0; i < numCols; i++){
            widths[i] = w;
        }
        printTable(out,widths);
    }

    public static void printTable(String[][] out, int[] widths){
        for(int i = 0; i < out.length; i++){
            for(int j = 0; j < out[i].length; j++){
                System.out.format("%"+widths[j]+"s",out[i][j]);
                if(j < out[i].length - 1){
                    System.out.print(",");
                }
            }
            System.out.println();
        }
    }

}
