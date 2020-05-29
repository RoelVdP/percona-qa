#!/bin/bash
# Created by Roel Van de Paar, MariaDB

# Terminate any other bug_report.sh scripts ongoing
# Does not work correctly
#ps -ef | grep -v $$ | grep bug_report | grep -v grep | grep -v mass_bug_report | awk '{print $2}' | xargs kill -9 2>/dev/null

ASAN_MODE=0
if [ "${1}" == "ASAN" ]; then
  MYEXTRA_OPT=""
  ASAN_MODE=1
else
  MYEXTRA_OPT="$*"
fi
SCRIPT_PWD=$(cd "`dirname $0`" && pwd)
RUN_PWD=${PWD}
TEXT=""  # Leave empty to look for corefiles, or set to look for a specific string in the error log instead

if [ ! -r bin/mysqld ]; then
  echo "Assert: bin/mysqld not available, please run this from a basedir which had the SQL executed against it an crashed"
  exit 1
fi

if [ ! -r ./all_no_cl ]; then  # Local
  echo "Assert: ./all_no_cl not available, please run this from a basedir which was prepared with ${SCRIPT_PWD}/startup.sh"
  exit 1
fi

if [ ! -r ../test_all ]; then  # Global
  echo "Assert: ../test_all not available - incorrect setup or structure"
  exit 1
fi

if [ ! -r ../kill_all ]; then  # Global
  echo "Assert: ../kill_all not available - incorrect setup or structure"
  exit 1
fi

if [ ! -r ../gendirs.sh ]; then  # Global
  echo "Assert: ../gendirs.sh not available - incorrect setup or structure"
  exit 1
fi

if [ ! -r ./in.sql ]; then  # Local
  echo "Assert: ./in.sql not available - incorrect setup or structure"
  exit 1
fi

echo 'Starting bug report generation for this SQL code (please check):'
echo '----------------------------------------------------------------'
cat in.sql | grep -v --binary-files=text '^$'
echo '----------------------------------------------------------------'
echo 'Note that any mysqld options need to be listed as follows on the first line above:'
echo '# mysqld options required for replay:  --someoption[=somevalue]'
sleep 2

RANDOM=`date +%s%N | cut -b14-19`  # Random entropy init
RANDF=$(echo $RANDOM$RANDOM$RANDOM$RANDOM | sed 's|.\(..........\).*|\1|')  # Random 10 digits filenr

grep --binary-files=text 'mysqld options required for replay:' ./in.sql | sed 's|.*mysqld options required for replay:[ ]||' > /tmp/options_bug_report.${RANDF}
echo ${MYEXTRA_OPT} >> /tmp/options_bug_report.${RANDF}
MYEXTRA_OPT_CLEANED=$(cat /tmp/options_bug_report.${RANDF} | sed 's|  | |g' | tr ' ' '\n' | sort -u | tr '\n' ' ')
if [ "$(echo "${MYEXTRA_OPT_CLEANED}" | sed 's|[ \t]||g')" != "" ]; then
  echo "Using the following options: ${MYEXTRA_OPT_CLEANED}"
  sleep 0.2  # For visual confirmation
fi

./all_no_cl ${MYEXTRA_OPT_CLEANED}
./test
./stop; sleep 0.2; ./kill 2>/dev/null; sleep 0.2

if [ ${ASAN_MODE} -eq 0 ]; then
  CORE_COUNT=$(ls data/*core* 2>/dev/null | wc -l)
  if [ ${CORE_COUNT} -eq 0 ]; then
    echo "INFO: no cores found at data/*core*"
  elif [ ${CORE_COUNT} -gt 1 ]; then
    echo "Assert: too many (${CORE_COUNT}) cores found at data/*core*, this should not happen (as ./all_no_cl was used which should have created a clean data directory)"
    exit 1
  else
    gdb -q bin/mysqld $(ls data/*core*) >/tmp/${RANDF}.gdba 2>&1 << EOF
     set pagination off
     bt
     quit
EOF
  fi
fi

rm -f ../in.sql
if [ -r ../in.sql ]; then echo "Assert: ../in.sql still available after it was removed!"; exit 1; fi
cp in.sql ..
if [ ! -r ../in.sql ]; then echo "Assert: ../in.sql not available after copy attempt!"; exit 1; fi
cd ..
echo "Testing all..."
if [ ${ASAN_MODE} -eq 0 ]; then
  ./test_all ${MYEXTRA_OPT_CLEANED}
else
  ./test_all ASAN ${MYEXTRA_OPT_CLEANED}
fi
echo "Ensuring all servers are gone..."
if [ ${ASAN_MODE} -eq 0 ]; then
  ./kill_all  # NOTE: Can not be executed as ../kill_all as it requires ./gendirs.sh
else
  ./kill_all ASAN
fi
if [ -z "${TEXT}" ]; then
  echo "TEXT not set, scanning for corefiles..."
  if [ ${ASAN_MODE} -eq 0 ]; then
    CORE_OR_TEXT_COUNT_ALL=$(./gendirs.sh | xargs -I{} echo "ls {}/data/*core* 2>/dev/null" | xargs -I{} bash -c "{}" | wc -l)
  else
    echo "Assert: ASAN mode is enabled, but TEXT variable is not set!"
    exit 1
  fi
else
  if [ ${ASAN_MODE} -eq 0 ]; then
    echo "TEXT set to '${TEXT}', searching error logs for the same"
    CORE_OR_TEXT_COUNT_ALL=$(set +H; ./gendirs.sh | xargs -I{} echo "grep --binary-files=text '${TEXT}' {}/log/master.err 2>/dev/null" | xargs -I{} bash -c "{}" | wc -l)
  else
    echo "TEXT set to '${TEXT}', searching error logs for the same (ASAN mode enabled)"
    CORE_OR_TEXT_COUNT_ALL=$(set +H; ./gendirs.sh ASAN | xargs -I{} echo "grep --binary-files=text '${TEXT}' {}/log/master.err 2>/dev/null" | xargs -I{} bash -c "{}" | wc -l)
  fi
fi
cd - >/dev/null || exit 1

SOURCE_CODE_REV="$(grep -om1 --binary-files=text "Source control revision id for MariaDB source code[^ ]\+" bin/mysqld 2>/dev/null | tr -d '\0' | sed 's|.*source code||;s|Version||;s|version_source_revision||')"
SERVER_VERSION="$(bin/mysqld --version | grep -om1 '[0-9\.]\+-MariaDB' | sed 's|-MariaDB||')"

echo '-------------------- BUG REPORT --------------------'
echo '{noformat}'
cat in.sql | grep -v --binary-files=text '^$'
echo -e '{noformat}\n'
echo -e 'Leads to:\n'
# Assumes (which is valid for the pquery framework) that 1st assertion is also the last in the log
if [ ${ASAN_MODE} -eq 0 ]; then
  ERROR_LOG=$(ls log/master.err 2>/dev/null | head -n1)
  if [ ! -z "${ERROR_LOG}" ]; then
    ASSERT="$(grep --binary-files=text -m1 'Assertion.*failed.$' ${ERROR_LOG} | head -n1)"
    if [ -z "${ASSERT}" ]; then
      ASSERT="$(grep --binary-files=text -m1 'Failing assertion:' ${ERROR_LOG} | head -n1)"
    fi
    if [ ! -z "${ASSERT}" ]; then
      echo -e "{noformat:title=${SERVER_VERSION} ${SOURCE_CODE_REV}}\n${ASSERT}\n{noformat}\n"
    fi
  fi

  echo "{noformat:title=${SERVER_VERSION} ${SOURCE_CODE_REV}}"
  NOCORE=0
  if [ -r /tmp/${RANDF}.gdba ]; then
    grep --binary-files=text -A999 'Core was generated by' /tmp/${RANDF}.gdba | grep --binary-files=text -v '^(gdb)[ \t]*$' | grep --binary-files=text -v '^[0-9]\+.*No such file or directory.$' | sed 's|(gdb) (gdb) |(gdb) bt\n|'
  else
    NOCORE=1
    echo "THIS TESTCASE DID NOT CRASH ${SERVER_VERSION} (the version of the basedir in which you started this script), SO NO BACKTRACE IS SHOWN HERE. YOU CAN RE-EXECUTE THIS SCRIPT FROM ONE OF THE 'Bug confirmed present in' DIRECTORIES BELOW TO OBTAIN ONE, OR EXECUTE ./all_no_cl; ./test; ./gdb FROM WITHIN THAT DIRECTORY TO GET A BACKTRACE MANUALLY!"
  fi
  echo -e '{noformat}\n'
fi
if [ -z "${TEXT}" ]; then
  if [ -r ../test.results ]; then
    cat ../test.results
  else
    echo "--------------------------------------------------------------------------------------------------------------"
    echo "ERROR: expected ../test.results to exist, but it did not. Running:  ./findbug+ 'signal'  though this may fail."
    echo "--------------------------------------------------------------------------------------------------------------"
    cd ..; ./findbug+ 'signal'; cd -
  fi
else
  cd ..; ./findbug+ "${TEXT}"; cd -
fi
echo '-------------------- /BUG REPORT --------------------'
if [ ${ASAN_MODE} -eq 0 ]; then
  echo "TOTAL CORES SEEN ACCROSS ALL VERSIONS: ${CORE_OR_TEXT_COUNT_ALL}"
else
  echo "TOTAL ASAN OCCURENCES SEEN ACCROSS ALL VERSIONS: ${CORE_OR_TEXT_COUNT_ALL}"
fi
if [ ${ASAN_MODE} -eq 0 ]; then
  if [ ${CORE_OR_TEXT_COUNT_ALL} -gt 0 ]; then
    echo 'Remember to action:'
    echo '1) If no engine is specified, add ENGINE=InnoDB'
    echo '2) Double check noformat version strings for non-10.5 issues'
    if [ ${NOCORE} -ne 1 ]; then
      echo '3A) Add bug to known.strings, as follows:'
      cd ${RUN_PWD}
      TEXT="$(${SCRIPT_PWD}/new_text_string.sh)"
      echo "${TEXT}"
      echo '3B) Checking if this bug is already known:'
      set +H  # Disables history substitution and avoids  -bash: !: event not found  like errors
      FINDBUG="$(grep -Fi --binary-files=text "${TEXT}" ${SCRIPT_PWD}/known_bugs.strings)"
      if [ ! -z "${FINDBUG}" ]; then
        if [ "$(echo "${FINDBUG}" | sed 's|[ \t]*\(.\).*|\1|')" != "#" ]; then  # If true, then this is not a previously fixed bugs. If false (i.e. leading char is "#") then this is a previouly fixed bug remarked with a leading '#' in the known bugs file.
          # Do NOT change the text in the next echo line, it is used by mariadb-qa/move_known.sh
          echo "FOUND: This is an already known, and not fixed yet, bug!"
          echo "${FINDBUG}"
        else
          echo "*** FOUND: This is an already known bug, but it was previously fixed! Research further! ***"
          echo "${FINDBUG}"
        fi
      else
        echo "NOT FOUND: Bug not found yet in known_bugs.strings!"
        echo "*** THIS IS POSSIBLY A NEW BUG; BUT CHECK #4 BELOW FIRST! ***"
      fi
      FINDBUG=
    else
      echo "3) Add bug to known.strings, using ${SCRIPT_PWD}/new_text_string.sh in the basedir of a crashed instance"
    fi
    echo '4) Check for duplicates before logging bug by executing ~/tt from within the basedir of a crashed instance and following the search url/instructions there'
  fi
fi

# OLD
#  if [ ${NOCORE} -ne 1 ]; then
#    cd ${RUN_PWD}
#    FIRSTFRAME=$(${SCRIPT_PWD}/new_text_string.sh FRAMESONLY | sed 's/|.*//')
#    echo "https://jira.mariadb.org/browse/MDEV-21938?jql=text%20~%20%22%5C%22${FIRSTFRAME}%5C%22%22%20ORDER%20BY%20status%20ASC"
#    echo "https://www.google.com/search?q=site%3Amariadb.org+%22${FIRSTFRAME}%22"
#  else
#    echo "https://jira.mariadb.org/browse/MDEV-21938?jql=text%20~%20%22%5C%22\${FIRSTFRAME}%5C%22%22"
#    echo "https://www.google.com/search?q=site%3Amariadb.org+%22\${FIRSTFRAME}%22"
#    echo "Please swap \${FIRSTFRAME} in the above to the first frame name. Regrettably this script could not obtain it for you (ref 'THIS TESTCASE DID NOT...' note above), but you can choose to re-run it from one of the 'Bug confirmed present in' directories, and it will produce ready-made URL's for you."
#  fi
