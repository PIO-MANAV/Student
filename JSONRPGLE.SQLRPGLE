      **
      ** JSONRPGLE.SQLRPGLE
      **
      ** Demonstrates JSON generation and parsing on IBM i using:
      **   - DB2 for i JSON scalar functions (JSON_OBJECT, JSON_ARRAYAGG)
      **   - SYSTOOLS.JSON2 table function for JSON shredding / parsing
      **   - Best-practice embedded SQL patterns
      **
      ** Prerequisites:
      **   - IBM i 7.4 or later  (JSON_OBJECT / JSON_ARRAYAGG require 7.4+)
      **   - SAMPLE schema created via RUNSQLSTM SRCFILE(QUSRSYS/QSQDSAMP)
      **   - Authority to SYSTOOLS and SAMPLE
      **
      ** Standards: CLAUDE.md — Company Code Generation Standards (April 2026)
      **
      ** Author : Generated per CLAUDE.md
      ** Created: 2026-04-22
      **

      *-----------------------------------------------------------------
      * Control options
      *-----------------------------------------------------------------
     H OPTION(*NODEBUGIO : *SRCSTMT)
     H DFTACTGRP(*NO)
     H ACTGRP(*CALLER)
     H BNDDIR('QC2LE')

      *-----------------------------------------------------------------
      * Named constants
      *-----------------------------------------------------------------
      ** Maximum size of a JSON document we will handle in one buffer
     D MAX_JSON_LENGTH     C                   CONST(32000)

      ** SQLSTATE sentinel values
     D SQL_SUCCESS         C                   CONST('00000')
     D SQL_NO_DATA         C                   CONST('02000')

      ** Log message prefix — identifies messages from this program
     D LOG_PREFIX          C                   CONST('[JSONRPGLE] ')

      *-----------------------------------------------------------------
      * Data structures
      *-----------------------------------------------------------------

      ** Maps to one row of SAMPLE.EMPLOYEE
     D EmployeeRow         DS                  QUALIFIED
     D   employeeId                  10I 0
     D   firstName                   12A        VARYING
     D   lastName                    15A        VARYING
     D   emailAddress               100A        VARYING
     D   departmentCode               3A        VARYING
     D   salary                      11P 2
     D   hireDate                     D

      ** Holds one shredded field pair extracted by JSON2
     D ParsedEmployee      DS                  QUALIFIED
     D   department                  30A        VARYING
     D   salary                      11P 2

      ** Summary returned to any future caller
     D ProgramResult       DS                  QUALIFIED
     D   isSuccess                    N
     D   recordsProcessed            10I 0
     D   diagnosticMessage          256A        VARYING

      *-----------------------------------------------------------------
      * Standalone fields
      *-----------------------------------------------------------------
     D employeeRow         DS                  LIKEDS(EmployeeRow)
     D parsedEmployee      DS                  LIKEDS(ParsedEmployee)
     D programResult       DS                  LIKEDS(ProgramResult)

      ** Buffer that accumulates JSON text produced by DB2 functions
     D generatedJson       S          32000A   VARYING

      ** Inbound JSON payload — simulates an HTTP/MQ message in demos
     D inboundJson         S          32000A   VARYING

      /FREE

       // ---------------------------------------------------------------
       // Entry point
       //
       // Runs three self-contained demonstrations in sequence.
       // Each demo is independent; a failure in one does not prevent
       // the others from running so all patterns are exercised.
       // ---------------------------------------------------------------
       exsr demonstrateSingleRowJson;
       exsr demonstrateJsonParsing;
       exsr demonstrateDepartmentJsonArray;

       *INLR = *ON;
       RETURN;


       // =================================================================
       // demonstrateSingleRowJson
       //
       // Fetches one EMPLOYEE row and converts it to a JSON object using
       // DB2's JSON_OBJECT scalar function.  Avoids manual string
       // concatenation to eliminate any JSON-injection risk.
       // =================================================================
       BEGSR demonstrateSingleRowJson;

         // Step 1 – fetch the raw relational data
         EXEC SQL
           SELECT
             CAST(empno AS INTEGER),
             TRIM(firstnme),
             TRIM(lastname),
             TRIM(COALESCE(phoneNo, '')),
             TRIM(COALESCE(workdept, 'UNASSIGNED')),
             salary,
             hiredate
           INTO
             :employeeRow.employeeId,
             :employeeRow.firstName,
             :employeeRow.lastName,
             :employeeRow.emailAddress,
             :employeeRow.departmentCode,
             :employeeRow.salary,
             :employeeRow.hireDate
           FROM SAMPLE.EMPLOYEE
           ORDER BY empno
           FETCH FIRST 1 ROW ONLY;

         IF SQLSTATE = SQL_NO_DATA;
           // Table exists but is empty — not a program error
           LEAVESR;
         ENDIF;

         IF SQLSTATE <> SQL_SUCCESS;
           exsr handleSqlFailure;
           LEAVESR;
         ENDIF;

         // Step 2 – project the host variables into a JSON document.
         // JSON_OBJECT is a DB2 set function: it enforces proper quoting
         // and escaping so we never have to sanitize key or value text.
         EXEC SQL
           SELECT
             JSON_OBJECT(
               'employeeId' :
                   CAST(:employeeRow.employeeId AS VARCHAR(10)),
               'firstName'  : :employeeRow.firstName,
               'lastName'   : :employeeRow.lastName,
               'email'      : :employeeRow.emailAddress,
               'department' : :employeeRow.departmentCode,
               'salary'     :
                   CAST(:employeeRow.salary AS VARCHAR(15)),
               'hireDate'   :
                   VARCHAR_FORMAT(:employeeRow.hireDate, 'YYYY-MM-DD')
             )
           INTO :generatedJson
           FROM SYSIBM.SYSDUMMY1;

         IF SQLSTATE <> SQL_SUCCESS;
           exsr handleSqlFailure;
           LEAVESR;
         ENDIF;

         // Step 3 – write result to job log for verification
         DSPLY generatedJson;

       ENDSR;


       // =================================================================
       // demonstrateJsonParsing
       //
       // Parses a JSON string with SYSTOOLS.JSON2 (JSONPath shredding).
       // JSON2 exposes each JSON path as a typed relational column, so
       // the extracted data is immediately usable in SQL WHERE clauses
       // and can be loaded directly into RPG host variables.
       // =================================================================
       BEGSR demonstrateJsonParsing;

         // Simulate an inbound JSON payload (e.g. from an HTTP API).
         // Hardcoded here only because this is a demonstration program;
         // in production this value would come from an ILE procedure
         // parameter or a QTEMP staging table.
         inboundJson =
           '{"employeeId":10,"firstName":"Christine",' +
            '"lastName":"Haas","department":"A00",' +
            '"salary":52750.00,"hireDate":"1965-01-01",' +
            '"isActive":true}';

         // Shred the JSON document into relational columns.
         // The PATH expressions use lax mode so a missing key yields
         // NULL rather than raising an error — safer for untrusted input.
         EXEC SQL
           SELECT
             j.department,
             CAST(j.salary AS DECIMAL(11, 2))
           INTO
             :parsedEmployee.department,
             :parsedEmployee.salary
           FROM SYSTOOLS.JSON2(
                  :inboundJson,
                  'lax $'
                )
                WITH ORDINALITY AS j(
                  employeeId   BIGINT      PATH 'lax $.employeeId',
                  firstName    VARCHAR(12) PATH 'lax $.firstName',
                  lastName     VARCHAR(15) PATH 'lax $.lastName',
                  department   VARCHAR(30) PATH 'lax $.department',
                  salary       VARCHAR(20) PATH 'lax $.salary',
                  hireDate     VARCHAR(10) PATH 'lax $.hireDate',
                  isActive     VARCHAR(5)  PATH 'lax $.isActive',
                  ORDINALITY
                );

         IF SQLSTATE = SQL_NO_DATA;
           LEAVESR;
         ENDIF;

         IF SQLSTATE <> SQL_SUCCESS;
           exsr handleSqlFailure;
           LEAVESR;
         ENDIF;

         // Confirm parsed values to job log
         DSPLY parsedEmployee.department;
         DSPLY %CHAR(parsedEmployee.salary);

       ENDSR;


       // =================================================================
       // demonstrateDepartmentJsonArray
       //
       // Aggregates ALL employees grouped by department into a nested
       // JSON structure using JSON_ARRAYAGG + JSON_OBJECT.
       //
       // Result shape:
       //   {
       //     "department": "A00",
       //     "headcount":  3,
       //     "avgSalary":  "49933.33",
       //     "employees":  [
       //       { "id": "10", "name": "Christine Haas",
       //         "hireDate": "1965-01-01" },
       //       ...
       //     ]
       //   }
       // =================================================================
       BEGSR demonstrateDepartmentJsonArray;

         // A single SQL statement produces the fully nested document.
         // Set-based aggregation avoids an RPG loop that would require
         // manual JSON string building and escaping.
         EXEC SQL
           SELECT
             JSON_OBJECT(
               'department' : workdept,
               'headcount'  :
                   CAST(COUNT(*) AS VARCHAR(6)),
               'avgSalary'  :
                   CAST(DECIMAL(AVG(salary), 9, 2) AS VARCHAR(15)),
               'employees'  :
                   JSON_ARRAYAGG(
                     JSON_OBJECT(
                       'id'       :
                           CAST(CAST(empno AS INTEGER)
                                AS VARCHAR(10)),
                       'name'     :
                           TRIM(firstnme) || ' ' || TRIM(lastname),
                       'hireDate' :
                           VARCHAR_FORMAT(hiredate, 'YYYY-MM-DD')
                     )
                     ORDER BY lastname, firstnme
                   )
             )
           INTO :generatedJson
           FROM SAMPLE.EMPLOYEE
           WHERE
             workdept IS NOT NULL
             AND salary > 0
           GROUP BY workdept
           ORDER BY workdept
           FETCH FIRST 1 ROW ONLY;

         IF SQLSTATE = SQL_NO_DATA;
           LEAVESR;
         ENDIF;

         IF SQLSTATE <> SQL_SUCCESS;
           exsr handleSqlFailure;
           LEAVESR;
         ENDIF;

         DSPLY generatedJson;

       ENDSR;


       // =================================================================
       // handleSqlFailure
       //
       // Logs SQLSTATE and the first 256 bytes of SQLERRMC to a QTEMP
       // error table, then marks programResult.isSuccess as *OFF.
       //
       // Does NOT raise an escape message so all three demos run even
       // when one encounters a DB2 error during development.
       // =================================================================
       BEGSR handleSqlFailure;

         programResult.isSuccess        = *OFF;
         programResult.diagnosticMessage =
           LOG_PREFIX + 'SQLSTATE=' + SQLSTATE +
           ' SQLERRMC=' + %SUBST(SQLERRMC : 1 :
                            %MIN(%LEN(SQLERRMC) : 200));

         // Persist the error detail so it survives job-log trimming
         EXEC SQL
           INSERT INTO QTEMP.JSONRPGLE_ERR_LOG
             (log_timestamp, sql_state, error_detail)
           VALUES
             (CURRENT_TIMESTAMP,
              :SQLSTATE,
              LEFT(RTRIM(:SQLERRMC), 256));

         // If the log table itself does not exist yet (first run),
         // the INSERT will fail — that is acceptable here because
         // SQLSTATE will still be visible in the DB2 diagnostic area.

       ENDSR;

      /END-FREE
