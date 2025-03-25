USE [Agresso]
GO
/****** Object:  StoredProcedure [Loan].[proc_GetEventRecords]    Script Date: 7/1/2020 9:24:00 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*******************************************************************************************
 PROCEDURE:		 [Loan].[proc_GetEventRecords]
 PURPOSE:		 Get records from [hcaloevents]

 REVISIONS:

 DATE		AUTHOR				DESCRIPTION
 ---------- ------------------- --------------------------------------------------------
 2/03/2019	FaPeng Xiong	  Created.
 7/2/2020   Mike Crowell      Add 31+ loan balance check for client DR
*******************************************************************************************/
ALTER PROCEDURE [Loan].[proc_GetEventRecords]
	@inClient						VARCHAR(2),
	@inMinBalance		    		Decimal(10),
	@inRepeatRun            		bit,
	@inInactiveDistList				NVARCHAR(100)

AS
	DECLARE @ErrorNumber	        INTEGER,
			@ErrorMessage	        NVARCHAR(2500)
			

BEGIN TRY

DECLARE @Client VARCHAR(2) = @inClient

IF @Client = 'HC' Or @Client = 'RC'
	BEGIN
		SELECT 
			A.LOAN, 
			'TOCALL' AS [EVENT] 
		FROM HCALOLOAN A 
		INNER JOIN HCALOTERMPLAN B  
			ON B.LOAN = A.LOAN 
			AND B.CLIENT = A.CLIENT 
			AND A.COUNTER BETWEEN B.TERM_FROM AND B.TERM_TO 
		LEFT OUTER JOIN HCALOEVENTS C  
			ON C.LOAN = A.LOAN 
			AND C.CLIENT = A.CLIENT 
			AND C.EVENT_TYPE = 'COLLECT' 
			AND (C.DIM_VALUE = 'TOCALL' OR DATEDIFF(Day ,C.ACTION_DATE,GetDate()) < 0) 
		LEFT OUTER JOIN BRELATIONS_CUSTOMER H 
			ON A.CLIENT = H.CLIENT 
			AND A.LOAN = H.CUSTOMERNO
		LEFT OUTER JOIN BRELATIONS_DISTRIBUTOR E
			ON A.CLIENT = E.CLIENT 
			AND A.DIM_1 = E.DISTRIBUTORNO	
		WHERE A.CLIENT = @Client
			AND  A.AMOUNT_6 > @inMinBalance
			AND B.CUR_AMOUNT > 0
			AND 
			(
				(
					A.LOAN_GROUP NOT IN ('DISTFI','DISTCE') 
					AND RIGHT(ISNULL(RTRIM(E.FINANCINGPLAN), ' '),3) <> 'STD' 
					AND (COALESCE(E.TERMINATIONDATE,'12/31/2099',CONVERT(DATETIME,E.TERMINATIONDATE)) > GetDate() OR ISNULL(E.ASSUMINGDISTRIBUTOR,'')<>'') 
					AND A.DIM_1 NOT IN (@inInactiveDistList)
					AND 
						(
							(
								ISNULL(H.REPURCHASEDATE, ' ') BETWEEN
								(CONVERT(VARCHAR,DATEADD(dd,-(DAY(GetDate())-1),GetDate()),101))
								AND (CONVERT(VARCHAR,DATEADD(dd,-(DAY(DATEADD(mm,1,GetDate()))),DATEADD(mm,1,GetDate())),101)) 
							)   
							OR  
							( 
								(A.AMOUNT_2 + A.AMOUNT_3 + A.AMOUNT_4 + A.AMOUNT_5) >= (B.CUR_AMOUNT * 1.5)
								OR (A.AMOUNT_3 + A.AMOUNT_4 + A.AMOUNT_5) > (A.AMOUNT_2 * .5)
							) 
						) 
				)  
				OR
				( 
					(A.LOAN_GROUP IN ('DISTFI','DISTCE') 
					OR RIGHT(ISNULL(RTRIM(E.FINANCINGPLAN), ' '),3) = 'STD') 
					AND A.DIM_1 NOT IN (@inInactiveDistList) 
					AND H.TRANSFERTODFPDATE IS NULL 
					AND 
						( 
							(A.AMOUNT_2 + A.AMOUNT_3 + A.AMOUNT_4 + A.AMOUNT_5) >= (B.CUR_AMOUNT * 1.5) 
							OR (A.AMOUNT_3 + A.AMOUNT_4 + A.AMOUNT_5) > (A.AMOUNT_2 * .5) 
						) 
				) 
				OR 
				( 
					(COALESCE(E.TERMINATIONDATE, '12/31/2099',CONVERT(DATETIME,E.TERMINATIONDATE)) <= GetDate() 
					OR A.DIM_1 IN (@inInactiveDistList))
					AND H.TRANSFERTODFPDATE IS NULL 
					AND 
						(
							(A.AMOUNT_2 + A.AMOUNT_3 + A.AMOUNT_4 + A.AMOUNT_5) >= (B.CUR_AMOUNT * 1.5) 
							OR (A.AMOUNT_4 + A.AMOUNT_5) > (A.AMOUNT_3 * .5) 
						)
				)
			) 
			AND C.LOAN IS NULL
			AND ((@inRepeatRun = 1 AND dbo.StripTime(C.LAST_UPDATE) <> dbo.StripTime(GetDate()) OR C.LAST_UPDATE IS NULL))
		GROUP BY A.LOAN
	END

	ELSE IF @Client = 'BR'
		BEGIN
			SELECT 
				A.LOAN, 
				'TOCALL' AS [EVENT] 
			FROM HCALOLOAN A 
			INNER JOIN HCALOTERMPLAN B  
				ON B.LOAN = A.LOAN 
				AND B.CLIENT = A.CLIENT 
				AND A.COUNTER BETWEEN B.TERM_FROM AND B.TERM_TO 
			LEFT OUTER JOIN HCALOEVENTS C  
				ON C.LOAN = A.LOAN 
				AND C.CLIENT = A.CLIENT 
				AND C.EVENT_TYPE = 'COLLECT' 
				AND (C.DIM_VALUE = 'TOCALL' OR DATEDIFF(Day ,C.ACTION_DATE,GetDate()) < 0) 
			LEFT OUTER JOIN BRELATIONS_CUSTOMER H 
				ON A.CLIENT = H.CLIENT 
				AND A.LOAN = H.CUSTOMERNO
			WHERE A.CLIENT = @Client 
				AND A.AMOUNT_6 > @inMinBalance
				AND B.CUR_AMOUNT > 0
				AND 
				(
					(A.AMOUNT_2 + A.AMOUNT_3 + A.AMOUNT_4 + A.AMOUNT_5) >= (B.CUR_AMOUNT * 1.5)
					OR (A.AMOUNT_3 >= (A.AMOUNT_2 * .5) AND A.AMOUNT_2 > 0)
					OR (A.AMOUNT_3 + A.AMOUNT_4 + A.AMOUNT_5) > (A.AMOUNT_2 * .5)
				) 
				AND C.LOAN IS NULL 
				AND H.TRANSFERTODFPDATE IS NULL
				AND ((@inRepeatRun = 1 AND dbo.StripTime(C.LAST_UPDATE) <> dbo.StripTime(GetDate()) OR C.LAST_UPDATE IS NULL))
			GROUP BY A.LOAN 
		END
	ELSE IF @Client = 'MX' OR  @Client ='BZ' OR  @Client = 'BA' OR @Client = 'PE' OR @Client = 'CO' OR @Client = 'EC'
		BEGIN
			SELECT 
				A.LOAN, 
				'TOCALL' AS [EVENT] 
			FROM HCALOLOAN A 
			INNER JOIN HCALOTERMPLAN B  
				ON B.LOAN = A.LOAN 
				AND B.CLIENT = A.CLIENT 
				AND A.COUNTER BETWEEN B.TERM_FROM AND B.TERM_TO 
			LEFT OUTER JOIN HCALOEVENTS C  
				ON C.LOAN = A.LOAN 
				AND C.CLIENT = A.CLIENT 
				AND C.EVENT_TYPE = 'COLLECT' 
				AND (C.DIM_VALUE = 'TOCALL' OR DATEDIFF(Day ,C.ACTION_DATE,GetDate()) < 0) 
			LEFT OUTER JOIN BRELATIONS_CUSTOMER H 
				ON A.CLIENT = H.CLIENT 
				AND A.LOAN = H.CUSTOMERNO
			WHERE A.CLIENT = @Client 
				AND A.AMOUNT_6 > @inMinBalance
				AND ((@Client NOT IN ('EC') AND A.LOAN_GROUP NOT IN ('DISTFI','DISTCE'))
					  OR (@Client IN ('EC') AND A.LOAN_GROUP IN ('REVADD','CLOSEN')))
				AND B.CUR_AMOUNT > 0
				AND ((A.AMOUNT_2 + A.AMOUNT_3 + A.AMOUNT_4 + A.AMOUNT_5) >= (B.CUR_AMOUNT * 1.5) OR (A.AMOUNT_3 + A.AMOUNT_4 + A.AMOUNT_5) > (A.AMOUNT_2 * .5))
				AND C.LOAN IS NULL 
				AND H.TRANSFERTODFPDATE IS NULL
				AND ((@inRepeatRun = 1 AND dbo.StripTime(C.LAST_UPDATE) <> dbo.StripTime(GetDate()) OR C.LAST_UPDATE IS NULL))
			GROUP BY A.LOAN
		END
	ELSE IF @Client = 'DR'
		BEGIN
			SELECT 
				A.LOAN, 
				'TOCALL' AS [EVENT] 
			FROM HCALOLOAN A 
			INNER JOIN HCALOTERMPLAN B  
				ON B.LOAN = A.LOAN 
				AND B.CLIENT = A.CLIENT 
				AND A.COUNTER BETWEEN B.TERM_FROM AND B.TERM_TO 
			LEFT OUTER JOIN HCALOEVENTS C  
				ON C.LOAN = A.LOAN 
				AND C.CLIENT = A.CLIENT 
				AND C.EVENT_TYPE = 'COLLECT' 
				AND (C.DIM_VALUE = 'TOCALL' OR DATEDIFF(Day ,C.ACTION_DATE,GetDate()) < 0) 
			LEFT OUTER JOIN BRELATIONS_CUSTOMER H 
				ON A.CLIENT = H.CLIENT 
				AND A.LOAN = H.CUSTOMERNO
			WHERE A.CLIENT = @Client 
				AND C.LOAN IS NULL 
				AND A.LOAN_GROUP IN ('REVADD','CLOSEN')
				AND A.AMOUNT_6 > @inMinBalance
				AND B.CUR_AMOUNT > 0
				AND ((A.AMOUNT_2 + A.AMOUNT_3 + A.AMOUNT_4 + A.AMOUNT_5) >= (B.CUR_AMOUNT * 1.5) OR (A.AMOUNT_3 + A.AMOUNT_4 + A.AMOUNT_5) > (A.AMOUNT_2 * .5))	
				AND ((@inRepeatRun = 1 AND dbo.StripTime(C.LAST_UPDATE) <> dbo.StripTime(GetDate()) OR C.LAST_UPDATE IS NULL))
			GROUP BY A.LOAN
		END
	ELSE
		BEGIN 
			SELECT 
				A.LOAN, 
				'TOCALL' AS [EVENT] 
			FROM HCALOLOAN A 
			INNER JOIN HCALOTERMPLAN B  
				ON B.LOAN = A.LOAN 
				AND B.CLIENT = A.CLIENT 
				AND A.COUNTER BETWEEN B.TERM_FROM AND B.TERM_TO 
			LEFT OUTER JOIN HCALOEVENTS C  
				ON C.LOAN = A.LOAN 
				AND C.CLIENT = A.CLIENT 
				AND C.EVENT_TYPE = 'COLLECT' 
				AND (C.DIM_VALUE = 'TOCALL' OR DATEDIFF(Day ,C.ACTION_DATE,GetDate()) < 0) 
			LEFT OUTER JOIN BRELATIONS_CUSTOMER H 
				ON A.CLIENT = H.CLIENT 
				AND A.LOAN = H.CUSTOMERNO
			WHERE A.CLIENT = @Client 
				AND 1 = 0
				AND ((@inRepeatRun = 1 AND dbo.StripTime(C.LAST_UPDATE) <> dbo.StripTime(GetDate()) OR C.LAST_UPDATE IS NULL))
			GROUP BY A.LOAN
		
		END 
END TRY
BEGIN CATCH
	
	SELECT @ErrorNumber =  ERROR_NUMBER(),
		   @ErrorMessage = ERROR_MESSAGE()
		   
	RAISERROR('ERROR: FAILED TO EXECUTE [agresso].[Loan].[proc_GetEventRecords]:%d:%s',16,1,@ErrorNumber, @ErrorMessage)

END CATCH

