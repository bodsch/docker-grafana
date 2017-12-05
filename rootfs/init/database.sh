

if [ "${DATABASE_TYPE}" == "sqlite3" ]
then
  return
fi

. /init/database/mysql.sh
