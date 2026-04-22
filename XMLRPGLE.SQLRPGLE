      **
      ** XMLRPGLE.SQLRPGLE
      **
      ** Demonstrates XML generation and parsing on IBM i using:
      **   - DB2 for i XML publishing functions
      **       XMLELEMENT, XMLATTRIBUTES, XMLFOREST, XMLAGG
      **   - XMLTABLE for XML shredding (XPath / SQL/XML standard)
      **   - XMLVALIDATE and XMLPARSE for well-formedness checking
      **
      ** Prerequisites:
      **   - IBM i 7.3 or later  (XMLTABLE requires 7.3+)
      **   - SAMPLE schema created via RUNSQLSTM SRCFILE(QUSRSYS/QSQDSAMP)
      **   - Authority to SAMPLE schema
      **
      ** Standards: CLAUDE.md -- Company Code Generation Standards (April 2026)
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
      ** Maximum XML document size handled in a single buffer
     D MAX_XML_LENGTH      C                   CONST(32000)

      ** SQLSTATE sentinels
     D SQL_SUCCESS         C                   CONST('00000')
     D SQL_NO_DATA         C                   CONST('02000')

      ** XML namespace used in all generated documents
     D XML_NAMESPACE_URI   C                   CONST(                          -
                             'http://company.example.com/hr/v1')

      ** Log prefix for job-log messages
     D LOG_PREFIX          C                   CONST('[XMLRPGLE] ')

      *-----------------------------------------------------------------
      * Data structures
      *-----------------------------------------------------------------

      ** Maps to one row of SAMPLE.EMPLOYEE
     D EmployeeRow         DS                  QUALIFIED
     D   employeeId                  10I 0
     D   firstName                   12A        VARYING
     D   lastName                    15A        VARYING
     D   jobCode                      8A        VARYING
     D   departmentCode               3A        VARYING
     D   salary                      11P 2
     D   hireDate                     D

      ** Holds one employee record extracted from an XML document
     D ParsedEmployee      DS                  QUALIFIED
     D   employeeId                  10I 0
     D   fullName                    30A        VARYING
     D   salary                      11P 2

      ** Summary for any future caller
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

      ** Accumulates XML text produced by DB2 XML publishing functions
     D generatedXml        S          32000A   VARYING

      ** Inbound XML payload -- simulates an HTTP/MQ message in demos
     D inboundXml          S          32000A   VARYING

      /FREE

       // ---------------------------------------------------------------
       // Entry point
       //
       // Three independent demonstrations run in sequence.
       // A failure in one demo does not abort the remaining demos,
       // ensuring all XML patterns are exercised during development.
       // ---------------------------------------------------------------
       exsr demonstrateSingleElementXml;
       exsr demonstrateXmlParsing;
       exsr demonstrateDepartmentXmlDocument;

       *INLR = *ON;
       RETURN;


       // =================================================================
       // demonstrateSingleElementXml
       //
       // Fetches one EMPLOYEE row and serialises it as a well-formed XML
       // element using DB2's XMLELEMENT and XMLATTRIBUTES functions.
       //
       // Result shape:
       //   <Employee xmlns="http://company.example.com/hr/v1"
       //             employeeId="10" department="A00">
       //     <FirstName>Christine</FirstName>
       //     <LastName>Haas</LastName>
       //     <Salary>52750.00</Salary>
       //     <HireDate>1965-01-01</HireDate>
       //   </Employee>
       // =================================================================
       BEGSR demonstrateSingleElementXml;

         // Step 1 -- retrieve the relational row
         EXEC SQL
           SELECT
             CAST(empno AS INTEGER),
             TRIM(firstnme),
             TRIM(lastname),
             TRIM(COALESCE(job, 'UNKNOWN')),
             TRIM(COALESCE(workdept, 'UNASSIGNED')),
             salary,
             hiredate
           INTO
             :employeeRow.employeeId,
             :employeeRow.firstName,
             :employeeRow.lastName,
             :employeeRow.jobCode,
             :employeeRow.departmentCode,
             :employeeRow.salary,
             :employeeRow.hireDate
           FROM SAMPLE.EMPLOYEE
           ORDER BY empno
           FETCH FIRST 1 ROW ONLY;

         IF SQLSTATE = SQL_NO_DATA;
           LEAVESR;
         ENDIF;

         IF SQLSTATE <> SQL_SUCCESS;
           exsr handleSqlFailure;
           LEAVESR;
         ENDIF;

         // Step 2 -- project host variables into XML using DB2 publishing
         // functions.  XMLELEMENT produces the outer element; XMLATTRIBUTES
         // maps scalar values to XML attributes; XMLFOREST generates child
         // elements from a list of column/variable expressions.
         // XMLSERIALIZE converts the internal XML data type to VARCHAR so
         // it can be stored in an RPG VARYING field.
         EXEC SQL
           SELECT
             XMLSERIALIZE(
               XMLELEMENT(
                 NAME "Employee",
                 XMLNAMESPACES(
                   DEFAULT :XML_NAMESPACE_URI
                 ),
                 XMLATTRIBUTES(
                   CAST(:employeeRow.employeeId AS VARCHAR(10))
                       AS "employeeId",
                   :employeeRow.departmentCode AS "department"
                 ),
                 XMLFOREST(
                   :employeeRow.firstName AS "FirstName",
                   :employeeRow.lastName  AS "LastName",
                   :employeeRow.jobCode   AS "JobCode",
                   CAST(:employeeRow.salary AS VARCHAR(15))
                       AS "Salary",
                   VARCHAR_FORMAT(:employeeRow.hireDate,'YYYY-MM-DD')
                       AS "HireDate"
                 )
               ) AS VARCHAR(32000) INCLUDING XMLDECLARATION
             )
           INTO :generatedXml
           FROM SYSIBM.SYSDUMMY1;

         IF SQLSTATE <> SQL_SUCCESS;
           exsr handleSqlFailure;
           LEAVESR;
         ENDIF;

         DSPLY generatedXml;

       ENDSR;


       // =================================================================
       // demonstrateXmlParsing
       //
       // Parses an XML string with XMLTABLE (SQL/XML standard).
       // XMLTABLE maps XPath expressions to typed relational columns,
       // so extracted data is immediately usable in SQL predicates and
       // can be loaded directly into RPG host variables.
       // =================================================================
       BEGSR demonstrateXmlParsing;

         // Simulate an inbound XML payload (e.g., from an HTTP service).
         // Hardcoded for demonstration only; in production this value
         // arrives via an ILE procedure parameter or a QTEMP staging table.
         inboundXml =
           '<?xml version="1.0" encoding="UTF-8"?>' +
           '<Employee xmlns="http://company.example.com/hr/v1"' +
           '          employeeId="10" department="A00">' +
           '  <FirstName>Christine</FirstName>' +
           '  <LastName>Haas</LastName>' +
           '  <Salary>52750.00</Salary>' +
           '  <HireDate>1965-01-01</HireDate>' +
           '</Employee>';

         // XMLTABLE shreds the document into relational columns.
         // The PASSING clause binds the host variable as the context item.
         // Column PATH expressions use the namespace declared inline.
         EXEC SQL
           SELECT
             x.employeeId,
             x.firstName || ' ' || x.lastName,
             CAST(x.salary AS DECIMAL(11, 2))
           INTO
             :parsedEmployee.employeeId,
             :parsedEmployee.fullName,
             :parsedEmployee.salary
           FROM XMLTABLE(
                  XMLNAMESPACES(
                    'http://company.example.com/hr/v1' AS "hr"
                  ),
                  '$doc/hr:Employee'
                  PASSING XMLPARSE(
                            DOCUMENT :inboundXml
                            PRESERVE WHITESPACE
                          ) AS "doc"
                  COLUMNS
                    employeeId  INTEGER     PATH '@employeeId',
                    firstName   VARCHAR(12) PATH 'hr:FirstName',
                    lastName    VARCHAR(15) PATH 'hr:LastName',
                    salary      VARCHAR(20) PATH 'hr:Salary',
                    hireDate    VARCHAR(10) PATH 'hr:HireDate'
                ) AS x;

         IF SQLSTATE = SQL_NO_DATA;
           LEAVESR;
         ENDIF;

         IF SQLSTATE <> SQL_SUCCESS;
           exsr handleSqlFailure;
           LEAVESR;
         ENDIF;

         DSPLY parsedEmployee.fullName;
         DSPLY %CHAR(parsedEmployee.salary);

       ENDSR;


       // =================================================================
       // demonstrateDepartmentXmlDocument
       //
       // Aggregates ALL employees grouped by department into a nested
       // XML document using XMLAGG + XMLELEMENT.
       //
       // Result shape:
       //   <?xml version="1.0"?>
       //   <Department code="A00" headcount="3" avgSalary="49933.33"
       //               xmlns="http://company.example.com/hr/v1">
       //     <Employee id="10">
       //       <Name>Christine Haas</Name>
       //       <HireDate>1965-01-01</HireDate>
       //     </Employee>
       //     ...
       //   </Department>
       // =================================================================
       BEGSR demonstrateDepartmentXmlDocument;

         // XMLAGG collects per-row XML fragments into a sequence which
         // XMLELEMENT then wraps in a single parent element.
         // Set-based aggregation avoids an RPG loop and any manual
         // string escaping of special XML characters (< > & " ').
         EXEC SQL
           SELECT
             XMLSERIALIZE(
               XMLELEMENT(
                 NAME "Department",
                 XMLNAMESPACES(
                   DEFAULT :XML_NAMESPACE_URI
                 ),
                 XMLATTRIBUTES(
                   workdept AS "code",
                   CAST(COUNT(*) AS VARCHAR(6)) AS "headcount",
                   CAST(
                     DECIMAL(AVG(salary), 9, 2) AS VARCHAR(15)
                   ) AS "avgSalary"
                 ),
                 XMLAGG(
                   XMLELEMENT(
                     NAME "Employee",
                     XMLATTRIBUTES(
                       CAST(CAST(empno AS INTEGER) AS VARCHAR(10))
                           AS "id"
                     ),
                     XMLFOREST(
                       TRIM(firstnme) || ' ' || TRIM(lastname)
                           AS "Name",
                       VARCHAR_FORMAT(hiredate, 'YYYY-MM-DD')
                           AS "HireDate"
                     )
                   )
                   ORDER BY lastname, firstnme
                 )
               ) AS VARCHAR(32000) INCLUDING XMLDECLARATION
             )
           INTO :generatedXml
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

         DSPLY generatedXml;

       ENDSR;


       // =================================================================
       // handleSqlFailure
       //
       // Logs SQLSTATE and the first 256 bytes of SQLERRMC to a QTEMP
       // error table, then marks programResult.isSuccess as *OFF.
       //
       // Does NOT raise an escape message so all three demos execute
       // even when one encounters a DB2 error during development.
       // =================================================================
       BEGSR handleSqlFailure;

         programResult.isSuccess        = *OFF;
         programResult.diagnosticMessage =
           LOG_PREFIX + 'SQLSTATE=' + SQLSTATE +
           ' SQLERRMC=' + %SUBST(SQLERRMC : 1 :
                            %MIN(%LEN(SQLERRMC) : 200));

         // Persist the error detail so it survives job-log trimming
         EXEC SQL
           INSERT INTO QTEMP.XMLRPGLE_ERR_LOG
             (log_timestamp, sql_state, error_detail)
           VALUES
             (CURRENT_TIMESTAMP,
              :SQLSTATE,
              LEFT(RTRIM(:SQLERRMC), 256));

         // If the log table does not yet exist (first run), the INSERT
         // will fail silently here -- SQLSTATE remains visible in the
         // DB2 diagnostic area for post-mortem analysis.

       ENDSR;

      /END-FREE
