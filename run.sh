if [ $# -eq 0 ]
then 
    mvn -q exec:java@gig
else
    if [ $1 == "reset" ]
    then
        D=$(date +"%Y%m%d-%H%M%S")
	if [ "$2" == "-f" ]
	then
			echo "Resetting cwk schema with schema.sql"
        	/modules/cs258/bin/psql cwk < schema.sql
			echo "Resetting cwk schema with reset-data.sql"
	        /modules/cs258/bin/psql cwk < reset-data.sql 
			echo "Inserting test data from $3"
        	/modules/cs258/bin/psql cwk < $3
	else
		#If a number was provided, generate data (based on the provided seed number)
		if [ "$2" == "-r" ]
		then
			test -d tmp || mkdir tmp
			echo "Generating test data based on seed $3"
        	mvn -e -q compile exec:java@test -Dexec.args="reset $3" > tmp/testData-$D-$3.sql
			echo "Resetting cwk schema with schema.sql"
       		/modules/cs258/bin/psql cwk < schema.sql
			echo "Resetting cwk schema with reset-data.sql"
	        /modules/cs258/bin/psql cwk < reset-data.sql
			echo "Inserting test data from tmp/testData-$D-$3.sql" 
       		/modules/cs258/bin/psql cwk < tmp/testData-$D-$3.sql
		fi

	fi
    elif [ $1 == "test" ]
    then
        mvn -e -q compile exec:java@test -Dexec.args="test $2"
    fi
fi
