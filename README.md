# Database management system

The majority of the solution's code is in the schema.sql file, with the java code mainly used for database interaction and executing sorted queries. To ensure a reliable and user-friendly solution, I employed FUNCTIONS and VIEWS in PostgreSQL. In the java code, I use try-catch blocks to handle errors and ensure that prepared statements and result sets are properly closed after use.

I'm proud to say that my program successfully passed all of the provided test cases, including scenarios with invalid inputs and queries. In cases where errors occur, the database remains unchanged. Overall, I believe that my solution is both robust and effective.

## Getting started
You will need a database called cwk. First, you should start your postgres-server (as you did in labs). Then you should connect to the postgres database, then create the cwk database:

`$ /modules/cs258/bin/psql postgres`
<br>
`postgres=# CREATE DATABASE cwk;
CREATE DATABASE
postgres=# \q` 
You should not include a CREATE DATABASE statement in your schema.sql file. When the system is assessed, we will create a database for you.

Make sure the dependencies are installed by running:

`$ mvn install`
<br>
Make sure the run.sh file is executable by running:

`$ chmod u+x run.sh`
<br>
To run your program (starting with the main method in GigSystem.java), you can run:

`$ ./run.sh`
<br>
Getting Started with Testing
We have provided you with a test suite in GigTester.java. There is a testOption method for each of the options, but not all are fully implemented, and you may like to extend the existing ones to think about different cases.

There is no need to submit your GigTester.java file, however we strongly recommend that you do write tests. The coursework will be marked using a similar framework to GigTester.java. If an option does not work in the test suite, it is likely to score 0 when marked.

There are two data files provided:

`tests/testbig.sql` – a sample of 50 gigs with randomly assigned acts
`tests/testsmall.sql` – a sample of 5 gigs, chosen specifically to help you experiment with options 7 and 8
The `tests/testbig.sql` and `tests/testsmall.sql` files do not violate the stated rules, but generating random test data may randomly violate some of the rules.

Then you can use run.sh to populate your database with test data. For example:

`$ ./run.sh reset -f tests/testsmall.sql` 
<br>
This script will do the following:

Execute `schema.sql` to reload the schema
Execute `reset-data.sql` to reset sequences to 10001
Execute the `tests/testsmall.sql` datafile to load the test data.
You can generate some new data (based on a specified random seed) like this:

`$ ./run.sh reset -r 42`
<br>
This will generate random data (based on generateTestDataMain from GigTester.java) - with the file stored in the tmp folder. The filename has the date/time of generation and the seed number supplied so that you can reproduce tests if you need to (i.e. you can reload a file using the "reset -f" method described above). If you supply -1 as the seed, a seed will be chosen for you.

To run testOption1 with the current database state, run:

`$ ./run.sh test 1`
<br>
Please note that option 1, 2, 3, 4, 5 and 6 have sample tests with expected output that is based on the data in tests/testbig.sql, whereas options 7 and 8 have expected output based on the data in tests/testsmall.sql. If you want to make sure that you’re running with the right data, you could run the reset and the test option at the same time. For example, you can run any of the following:

`$ ./run.sh reset -f tests/testbig.sql && ./run.sh test 1
$ ./run.sh reset -f tests/testbig.sql && ./run.sh test 2
$ ./run.sh reset -f tests/testbig.sql && ./run.sh test 3
$ ./run.sh reset -f tests/testbig.sql && ./run.sh test 4
$ ./run.sh reset -f tests/testbig.sql && ./run.sh test 5
$ ./run.sh reset -f tests/testbig.sql && ./run.sh test 6
$ ./run.sh reset -f tests/testsmall.sql && ./run.sh test 7
$ ./run.sh reset -f tests/testsmall.sql && ./run.sh test 8`
Note, resetting the database will not necessarily clear all objects from your database. If you want to be certain that all previous objects have been deleted, you will need to put your own DROP TABLE, DROP VIEW, etc. statements in your schema.sql to make sure you delete everything.

Alternatively, you could DROP DATABASE cwk; CREATE DATABASE cwk; but be warned that dropping and recreating the database may cause postgres to run an admin task (https://stackoverflow.com/questions/52170028/postgres-database-drop-is-very-slow), which takes a bit of time, so we advise you don’t do that very often. If you really want this every time you reset the database, alter the reset process in run.sh to add this line before the "Resetting cwk schema with schema.sql" line:

echo "DROP DATABASE cwk; CREATE DATABASE cwk;" | /modules/cs258/bin/psql postgres
If you want to test anything specific, it is a good idea to generate a file, import it and modify the data in the database. You could then make a copy of your database using this:

`$ /modules/cs258/bin/pg_dump cwk --data-only > databasestate.sql`
<br>
which you can then load again at any time using

`$ ./run.sh reset -f databasestate.sql`
The reset-data.sql file (called by run.sh reset) automatically sets all sequences to be 10001. This is to ensure that test data can be inserted with IDs between 1 and 10000. Please make sure that your system does not rely on any values below 10000, as these may contain test data.
