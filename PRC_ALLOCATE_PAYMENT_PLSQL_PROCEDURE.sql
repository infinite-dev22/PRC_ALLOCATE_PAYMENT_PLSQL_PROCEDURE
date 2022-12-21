CREATE OR REPLACE PACKAGE BODY PKG_MANAGE_TENANTS_2 IS

	L_SQLCODE  VARCHAR2(2000);
	L_SQLERRM  VARCHAR2(2000);
	O_ERROR_ID NUMBER;

	FUNCTION GET_TENANCY_START_DATE(P_ENTRY_DATE IN DATE) RETURN DATE AS
	
		L_DAYS_TO_NXT_MONTH NUMBER;
		L_DUE_DAYS          NUMBER;
	BEGIN
	
		BEGIN
			SELECT M.DAYS_TO_NEXT_MONTH
				INTO L_DAYS_TO_NXT_MONTH
				FROM GEN_COMPANY_MST M;
		END;
	
		BEGIN
			SELECT EXTRACT(DAY FROM LAST_DAY(P_ENTRY_DATE)) -
						 EXTRACT(DAY FROM P_ENTRY_DATE)
				INTO L_DUE_DAYS
				FROM DUAL;
		
			IF L_DUE_DAYS <= L_DAYS_TO_NXT_MONTH
			THEN
				RETURN ROUND(P_ENTRY_DATE,
										 'MONTH');
			ELSE
				RETURN TRUNC(TO_DATE(P_ENTRY_DATE,
														 'DD-MON-YY'));
			END IF;
		END;
	
	END GET_TENANCY_START_DATE;

	FUNCTION GET_TENANCY_TO_HOUSE_ID(P_CLIENT_ID   IN NUMBER,
																	 P_BUILDING_ID IN NUMBER,
																	 P_HOUSE_ID    IN NUMBER,
																	 P_TENANT_ID   IN NUMBER)
	
	 RETURN NUMBER AS
	
		L_TENANCY_TO_HOUSE_ID NUMBER;
	
	BEGIN
		BEGIN
			SELECT H.TENANT_TO_HOUSE_ID
				INTO L_TENANCY_TO_HOUSE_ID
				FROM PRP_TENANT_TO_HOUSE H
			 WHERE H.CLIENT_ID = P_CLIENT_ID
				 AND H.BUILDING_ID = P_BUILDING_ID
				 AND H.HOUSE_ID = P_HOUSE_ID
				 AND H.TENANT_ID = P_TENANT_ID;
		
		EXCEPTION
			WHEN OTHERS THEN
				L_TENANCY_TO_HOUSE_ID := NULL;
		END;
	
		RETURN L_TENANCY_TO_HOUSE_ID;
	
	END GET_TENANCY_TO_HOUSE_ID;

	FUNCTION GET_HOUSE_COST(P_TENANT_TO_HOUSE_ID IN NUMBER) RETURN NUMBER AS
	
		L_HOUSE_COST NUMBER;
	
	BEGIN
		BEGIN
			SELECT RR.HOUSE_COST
				INTO L_HOUSE_COST
				FROM PRP_TENANT_REGISTRATION RR,
						 PRP_TENANT_TO_HOUSE     HH
			 WHERE RR.TENANT_ID = HH.TENANT_ID
				 AND HH.TENANT_TO_HOUSE_ID = P_TENANT_TO_HOUSE_ID;
		
		EXCEPTION
			WHEN OTHERS THEN
				L_HOUSE_COST := NULL;
			
		END;
		RETURN L_HOUSE_COST;
	END GET_HOUSE_COST;

	PROCEDURE PRC_GENERATE_PERIODS(PI_PRD_ID        IN NUMBER,
																 PI_FRST_DATE     IN DATE,
																 PI_FRST_MTH      IN NUMBER,
																 PI_PERIOD_MST_ID IN NUMBER) AS
		L_DAY           NUMBER;
		L_MTH           NUMBER;
		L_YR            NUMBER;
		L_CHR_DT        VARCHAR2(10);
		L_MTH1          VARCHAR2(3);
		PI_OUT_DATE     DATE;
		PI_PRD_ID1      NUMBER;
		PI_LAST_MTH_DT1 DATE;
		PI_DAYS         NUMBER;
		PI_LAST_DATE    DATE;
		PI_FIRST_DATE   DATE;
		PI_FIN_YR       NUMBER;
		L_COUNT         NUMBER;
	
	BEGIN
		SELECT COUNT(1)
			INTO L_COUNT
			FROM GEN_PERIODS P
		 WHERE P.PERIOD_MST_ID = PI_PERIOD_MST_ID;
	
		IF L_COUNT = 0
		THEN
		
			PI_FIN_YR     := TO_NUMBER(TO_CHAR(PI_FRST_DATE,
																				 'YYYY'));
			L_DAY         := 1;
			PI_PRD_ID1    := PI_PRD_ID;
			PI_FIRST_DATE := PI_FRST_DATE;
			LOOP
				-- for 13th month the first date is the first date of next fin yr
				IF PI_PRD_ID1 = 13
				THEN
					L_MTH := PI_FRST_MTH;
				ELSE
					L_MTH := MOD(PI_PRD_ID1 + PI_FRST_MTH - 1,
											 12);
				END IF;
			
				IF L_MTH = 0
				THEN
					L_MTH := 12;
				END IF;
			
				L_YR := SUBSTR(PI_FIN_YR,
											 1,
											 4);
			
				IF PI_PRD_ID1 = 13
					 OR NOT (L_MTH BETWEEN PI_FRST_MTH AND 12)
				THEN
					L_YR := L_YR + 1;
					/*GENERATE NEXT YEAR*/
				END IF;
				IF L_MTH = 1
				THEN
					L_MTH1 := 'JAN';
				ELSIF L_MTH = 2
				THEN
					L_MTH1 := 'FEB';
				ELSIF L_MTH = 3
				THEN
					L_MTH1 := 'MAR';
				ELSIF L_MTH = 4
				THEN
					L_MTH1 := 'APR';
				ELSIF L_MTH = 5
				THEN
					L_MTH1 := 'MAY';
				ELSIF L_MTH = 6
				THEN
					L_MTH1 := 'JUN';
				ELSIF L_MTH = 7
				THEN
					L_MTH1 := 'JUL';
				ELSIF L_MTH = 8
				THEN
					L_MTH1 := 'AUG';
				ELSIF L_MTH = 9
				THEN
					L_MTH1 := 'SEP';
				ELSIF L_MTH = 10
				THEN
					L_MTH1 := 'OCT';
				ELSIF L_MTH = 11
				THEN
					L_MTH1 := 'NOV';
				ELSE
					L_MTH1 := 'DEC';
				END IF;
			
				L_CHR_DT        := TO_CHAR(L_DAY) || '-' || L_MTH1 || '-' ||
													 TO_CHAR(L_YR);
				PI_OUT_DATE     := TO_DATE(L_CHR_DT,
																	 'DD-MON-YYYY');
				PI_LAST_MTH_DT1 := LAST_DAY(PI_OUT_DATE);
				PI_DAYS         := (TO_NUMBER(SUBSTR(PI_LAST_MTH_DT1,
																						 1,
																						 2))) - 1;
				PI_LAST_DATE    := PI_FIRST_DATE + PI_DAYS;
			
				INSERT INTO GEN_PERIODS
					(PERIOD_NO,
					 START_DATE,
					 END_DATE,
					 PERIOD_MST_ID)
				VALUES
					(PI_PRD_ID1,
					 PI_FIRST_DATE,
					 PI_LAST_DATE,
					 PI_PERIOD_MST_ID);
			
				PI_PRD_ID1    := PI_PRD_ID1 + 1;
				PI_FIRST_DATE := PI_LAST_DATE + 1;
			
				EXIT WHEN PI_PRD_ID1 > 12;
			END LOOP;
		
		END IF;
	EXCEPTION
		WHEN OTHERS THEN
			L_SQLCODE := SQLCODE;
			L_SQLERRM := SQLERRM;
		
			INSERT INTO GEN_ERRORS
				(ERROR_ID,
				 ORA_ERROR_CODE,
				 ORA_ERROR_DESC,
				 CTD_ON,
				 TBL,
				 PROC_DESC,
				 ID)
			VALUES
				(PI_PERIOD_MST_ID,
				 L_SQLCODE,
				 L_SQLERRM,
				 SYSDATE,
				 'PRC_GEN_MTH_PRD',
				 'GENERATING PERIODS',
				 GEN_ERROR_SEQ.NEXTVAL);
		
	END PRC_GENERATE_PERIODS;

	PROCEDURE PRC_GEN_TENANT_PERIODS(P_START_DATE         IN DATE,
																	 P_TENANT_TO_HOUSE_ID IN NUMBER) AS
	
		L_COUNT                  NUMBER;
		L_HOUSE_COST             NUMBER;
		L_TENANT_ID              NUMBER;
		L_REF                    VARCHAR2(30);
		L_SQLCODE                VARCHAR2(2000);
		L_SQLERRM                VARCHAR2(2000);
		L_TENANT_HOUSE_PERIOD_ID NUMBER;
	
	BEGIN
		BEGIN
			BEGIN
			
				-- INSERT VALUES INTO LOCAL VARIABLES.
				SELECT GET_HOUSE_COST(P_TENANT_TO_HOUSE_ID)
					INTO L_HOUSE_COST
					FROM DUAL;
			
				SELECT COUNT(1)
					INTO L_COUNT
					FROM PRP_TENANT_TO_HOUSE P
				 WHERE P.TENANT_TO_HOUSE_ID = P_TENANT_TO_HOUSE_ID;
			
				SELECT TH.TENANT_ID,
							 TH.TENANT_ID || TO_CHAR(SYSDATE,
																			 'DDMMYYHHMISS')
					INTO L_TENANT_ID,
							 L_REF
					FROM PRP_TENANT_TO_HOUSE TH
				 WHERE TH.TENANT_TO_HOUSE_ID = P_TENANT_TO_HOUSE_ID;
			
			EXCEPTION
				WHEN OTHERS THEN
					L_COUNT := 0;
				
			END;
		
			IF L_COUNT = 1
			THEN
				FOR EA IN (SELECT T.PERIOD_MST_ID,
													T.PERIOD_ID,
													T.PERIOD_NO,
													T.START_DATE,
													T.END_DATE,
													PKG_MANAGE_TENANTS_2.GET_TENANCY_START_DATE(P_START_DATE) TENANCY_START_DATE
										 FROM GEN_PERIODS T
										WHERE PKG_MANAGE_TENANTS_2.GET_TENANCY_START_DATE(P_START_DATE) BETWEEN
													T.START_DATE AND T.END_DATE
											AND NOT EXISTS
										(SELECT 1
														 FROM PRP_TENANT_HOUSE_PERIOD D
														WHERE D.PERIOD_ID = T.PERIOD_ID
															AND D.TENANT_TO_HOUSE_ID = P_TENANT_TO_HOUSE_ID))
				
				LOOP
					BEGIN
					
						SAVEPOINT START_TRANS;
						SELECT PRP_TENANT_HOUSE_PERIOD_SEQ.NEXTVAL
							INTO L_TENANT_HOUSE_PERIOD_ID
							FROM DUAL;
						-- INSERT FIRST TENANT HOUSE PERIOD
						INSERT INTO PRP_TENANT_HOUSE_PERIOD
							(TENANT_HOUSE_PERIOD_ID,
							 TENANT_TO_HOUSE_ID,
							 START_DATE,
							 END_DATE,
							 RENT_AMT_EXPECTED,
							 RENT_COLLECTED,
							 BALANCE,
							 PERIOD_ENDED,
							 PERIOD_ID)
						VALUES
							(L_TENANT_HOUSE_PERIOD_ID,
							 P_TENANT_TO_HOUSE_ID,
							 EA.TENANCY_START_DATE,
							 EA.END_DATE,
							 L_HOUSE_COST,
							 0,
							 L_HOUSE_COST,
							 'N',
							 EA.PERIOD_ID);
					
						-- Insert Tenant Transaction
						/*DOES THE BILLING TWICE HERE AND ON LINE 868
            -> COMMENTED THE BELOW LINE
               -> SOLVES DOUBLE BILLING BUH DOESN'T BILL INTO THE NEXT YEAR.*/
						/*BEGIN
              -- Call the procedure
              PRC_TENANT_TRANS_INS(P_TENANT_HOUSE_PERIOD_ID => L_TENANT_HOUSE_PERIOD_ID,
                                   P_TENANT_ID              => L_TENANT_ID,
                                   P_TRANS_DATE             => SYSDATE,
                                   P_REFERENCE              => L_REF,
                                   P_TRANS_TYPE             => 'D',
                                   P_TRANS_AMOUNT           => L_HOUSE_COST,
                                   P_TRANS_SOURCE           => 'RENT_BILL',
                                   P_TRANS_REF_ID           => P_TENANT_TO_HOUSE_ID,
                                   P_TRANS_DESC             => 'Rent Expected for the period:' ||
                                                               EA.TENANCY_START_DATE ||
                                                               ' to ' ||
                                                               EA.END_DATE);
            END;*/
					
						/*PRC_BILL_NEXT_PERIOD(L_TENANT_ID);*/
					
						-- INSERT REMAINING PERIODS
						FOR ES IN (SELECT T.PERIOD_MST_ID,
															T.PERIOD_ID,
															T.PERIOD_NO,
															T.START_DATE,
															T.END_DATE
												 FROM GEN_PERIODS T
												WHERE T.PERIOD_NO > EA.PERIOD_NO
													AND T.PERIOD_MST_ID = EA.PERIOD_MST_ID
												ORDER BY T.PERIOD_NO)
						LOOP
							INSERT INTO PRP_TENANT_HOUSE_PERIOD
								(TENANT_TO_HOUSE_ID,
								 START_DATE,
								 END_DATE,
								 RENT_AMT_EXPECTED,
								 RENT_COLLECTED,
								 BALANCE,
								 PERIOD_ENDED,
								 PERIOD_ID)
							VALUES
								(P_TENANT_TO_HOUSE_ID,
								 ES.START_DATE,
								 ES.END_DATE,
								 L_HOUSE_COST,
								 0,
								 L_HOUSE_COST,
								 'N',
								 ES.PERIOD_ID);
						END LOOP;
					EXCEPTION
						WHEN OTHERS THEN
							ROLLBACK TO START_TRANS;
						
							L_SQLCODE := SQLCODE;
							L_SQLERRM := SQLERRM;
						
							SELECT GEN_ERROR_SEQ.NEXTVAL INTO O_ERROR_ID FROM DUAL;
							PRC_INSERT_ERROR(P_ERROR_ID       => P_TENANT_TO_HOUSE_ID,
															 P_ORA_ERROR_CODE => L_SQLCODE,
															 P_ORA_ERROR_DESC => L_SQLERRM,
															 P_CTD_ON         => SYSDATE,
															 P_TBL            => 'PKG_MANAGE_TENANTS.PRC_GEN_TENANT_PERIODS',
															 P_PROC_DESC      => 'ERROR GENERATING TENANT PERIODS FOR TENANT_TO_HOUSE_ID: ' ||
																									 P_TENANT_TO_HOUSE_ID,
															 P_ID             => O_ERROR_ID);
					END;
				END LOOP;
			
			END IF;
		
		EXCEPTION
			WHEN OTHERS THEN
				ROLLBACK TO START_TRANS;
			
				L_SQLCODE := SQLCODE;
				L_SQLERRM := SQLERRM;
			
				SELECT GEN_ERROR_SEQ.NEXTVAL INTO O_ERROR_ID FROM DUAL;
				PRC_INSERT_ERROR(P_ERROR_ID       => P_TENANT_TO_HOUSE_ID,
												 P_ORA_ERROR_CODE => L_SQLCODE,
												 P_ORA_ERROR_DESC => L_SQLERRM,
												 P_CTD_ON         => SYSDATE,
												 P_TBL            => 'PKG_MANAGE_TENANTS.PRC_GEN_TENANT_PERIODS',
												 P_PROC_DESC      => 'ERROR GENERATING TENANT PERIODS FOR TENANT_TO_HOUSE_ID: ' ||
																						 P_TENANT_TO_HOUSE_ID,
												 P_ID             => O_ERROR_ID);
		END;
	END PRC_GEN_TENANT_PERIODS;

	PROCEDURE PRC_ALLOCATE_PAYMENT(P_TENANT_TO_HOUSE_ID IN NUMBER,
																 P_AMOUNT             IN NUMBER,
																 P_PRN                IN VARCHAR2) AS
		/*
    P_AMOUNT is current amount paid by tenant as of date procedure.*/
		L_AMOUNT_OK            NUMBER; --
		L_BAL                  NUMBER := 0; -- Get what is left after payment is made by a tenant when money paid is more than money billed 
		L_SPENT                NUMBER := 0; -- Amount of money paid on a tenant's house billing(Amount Payed for a billed or unbilled period by tenant)
		L_AMOUNT               NUMBER := 0; -- Mount being billed on tenant and  not yet cleared for a given period(Unpaid Billed Amount On Client)
		L_RENT_BALANCE         NUMBER := 0;
		L_TENANT_ID            NUMBER;
		L_IS_CLEARED           PRP_TENANT_HOUSE_PERIOD.IS_CLEARED%TYPE;
		L_PERIOD_MST_ID        NUMBER;
		L_START_DATE           DATE;
		L_END_DATE             DATE;
		L_START_MONTH          NUMBER;
		L_YR                   NUMBER;
		L_BALANCE              NUMBER;
		L_TENANT_NAME          VARCHAR2(225);
		L_RECENT_TENANT_PAYMNT NUMBER;
	
	BEGIN
		--TO MAKE INITIAL BILLING ON TENANT PAYMENT.
		--FIRST CHECK IF TENANT IS BEING DEMANDED, IF SO... DON'T BILL NEXT MONTH
		/*SELECT TA.BALANCE
     INTO L_BALANCE
     FROM PRP_TENANT_HOUSE_PERIOD TA
    WHERE TA.TENANT_TO_HOUSE_ID = P_TENANT_TO_HOUSE_ID;*/
	
		SELECT TA.BALANCE
			INTO L_BALANCE
			FROM PRP_TENANT_HOUSE_PERIOD TA
		 WHERE TA.IS_CLEARED = 'N';
	
		SELECT NVL(B.AMOUNT,
							 0)
			INTO L_SPENT
			FROM PRP_PAY_ALLOCATION_TEMP B
		 WHERE B.PRN = P_PRN;
	EXCEPTION
		WHEN OTHERS THEN
			L_SPENT := 0;
		
			L_AMOUNT := L_BALANCE;
			L_BAL    := P_AMOUNT - L_SPENT;
		
			SELECT NVL(COUNT(TT.BALANCE),
								 0)
				INTO L_RECENT_TENANT_PAYMNT
				FROM PRP_TENANT_TRANS TT
			 WHERE TT.TRANS_TYPE = 'W'
				 AND TT.TRANS_ID = (SELECT MAX(T.TRANS_ID) FROM PRP_TENANT_TRANS T);
		
			IF L_RECENT_TENANT_PAYMNT = 0
				 OR L_RECENT_TENANT_PAYMNT IS NULL
			THEN
				SELECT TTH.TENANT_ID
					INTO L_TENANT_ID
					FROM PRP_TENANT_TO_HOUSE TTH
				 WHERE TTH.TENANT_TO_HOUSE_ID = P_TENANT_TO_HOUSE_ID;
			
				PKG_MANAGE_TENANTS_2.PRC_BILL_NEXT_PERIOD(P_TENANT_ID => L_TENANT_ID);
			END IF;
		
			<<PROC_LBL>>
			BEGIN
				FOR K IN (SELECT TA.TENANT_HOUSE_PERIOD_ID,
												 TA.TENANT_TO_HOUSE_ID,
												 TA.START_DATE,
												 TA.END_DATE,
												 TA.PERIOD_ID,
												 TA.RENT_AMT_EXPECTED,
												 TA.BALANCE,
												 TA.IS_CLEARED
										FROM PRP_TENANT_HOUSE_PERIOD TA
									 WHERE TA.TENANT_TO_HOUSE_ID = P_TENANT_TO_HOUSE_ID
										 AND TA.IS_CLEARED = 'N'
										 AND NOT EXISTS (SELECT 1
														FROM PRP_PAY_ALLOCATION_TEMP AAM
													 WHERE AAM.TENANT_HOUSE_PERIOD_ID =
																 TA.TENANT_HOUSE_PERIOD_ID
														 AND AAM.PRN = P_PRN)
									 ORDER BY 1)
				LOOP
					BEGIN
						SELECT TTH.TENANT_ID
							INTO L_TENANT_ID
							FROM PRP_TENANT_TO_HOUSE TTH
						 WHERE TTH.TENANT_TO_HOUSE_ID = P_TENANT_TO_HOUSE_ID;
					
						SELECT PTR.TENANT_NAME
							INTO L_TENANT_NAME
							FROM PRP_TENANT_REGISTRATION PTR,
									 PRP_TENANT_TO_HOUSE     PTTH
						 WHERE PTR.TENANT_ID = PTTH.TENANT_ID
							 AND PTTH.TENANT_TO_HOUSE_ID = P_TENANT_TO_HOUSE_ID;
					
						SELECT NVL(SUM(B.AMOUNT),
											 0)
							INTO L_SPENT
							FROM PRP_PAY_ALLOCATION_TEMP B
						 WHERE B.PRN = P_PRN;
					EXCEPTION
						WHEN OTHERS THEN
							L_SPENT := 0;
					END;
				
					L_AMOUNT := K.BALANCE;
					L_BAL    := P_AMOUNT - L_SPENT;
				
					IF L_BAL > 0
					THEN
						BEGIN
							IF L_BAL > K.BALANCE -- GREATER THAN
							THEN
								L_AMOUNT_OK := L_AMOUNT;
							ELSIF L_BAL = K.BALANCE -- EQUAL TO
							THEN
								L_AMOUNT_OK := L_BAL;
							ELSE
								-- LESS THAN
								L_AMOUNT_OK := L_BAL;
							END IF;
						
							BEGIN
								SAVEPOINT START_TRANS;
								INSERT INTO PRP_PAY_ALLOCATION_TEMP AA
									(AA.PRN,
									 AA.TENANT_HOUSE_PERIOD_ID,
									 AA.AMOUNT)
								VALUES
									(P_PRN,
									 K.TENANT_HOUSE_PERIOD_ID,
									 L_AMOUNT_OK);
							
								PKG_PROPERTY_MGT2.PRC_TENANT_TRANS_INS(P_TENANT_ID    => L_TENANT_ID,
																											 P_TRANS_DATE   => SYSDATE,
																											 P_REFERENCE    => P_PRN,
																											 P_TRANS_TYPE   => 'W',
																											 P_TRANS_AMOUNT => L_AMOUNT_OK,
																											 P_TRANS_SOURCE => 'TENANT PAYMENT',
																											 P_TRANS_REF_ID => P_TENANT_TO_HOUSE_ID,
																											 P_TRANS_DESC   => 'Rent Payment for Tenant: ' ||
																																				 L_TENANT_NAME);
							
								--CAN'T BILL HERE COZ NO NEXT YEAR PERIODS ARE GENERATED FOR THE SPECIFIED TENANT.
								/*IF L_BAL > K.BALANCE -- GREATER THAN
                THEN
                  PKG_MANAGE_TENANTS_2.PRC_BILL_NEXT_PERIOD(P_TENANT_ID => L_TENANT_ID);
                END IF;*/
							
								-- UPDATE PERIOD PAYMENT
								FOR D IN (SELECT *
														FROM PRP_TENANT_HOUSE_PERIOD BN
													 WHERE BN.TENANT_HOUSE_PERIOD_ID =
																 K.TENANT_HOUSE_PERIOD_ID
														 FOR UPDATE)
								LOOP
									L_RENT_BALANCE := K.BALANCE - L_AMOUNT_OK;
								
									IF L_RENT_BALANCE = 0
									THEN
										L_IS_CLEARED := 'Y';
									ELSE
										L_IS_CLEARED := 'N';
									END IF;
								
									UPDATE PRP_TENANT_HOUSE_PERIOD NN
										 SET NN.RENT_COLLECTED = NVL(NN.RENT_COLLECTED,
																								 0) + L_AMOUNT_OK,
												 NN.BALANCE        = L_RENT_BALANCE,
												 NN.IS_CLEARED     = L_IS_CLEARED
									 WHERE NN.TENANT_HOUSE_PERIOD_ID =
												 D.TENANT_HOUSE_PERIOD_ID;
								END LOOP;
							
							EXCEPTION
								WHEN OTHERS THEN
									ROLLBACK TO START_TRANS;
								
									L_SQLCODE := SQLCODE;
									L_SQLERRM := SQLERRM;
								
									PRC_INSERT_ERROR(P_ERROR_ID       => K.TENANT_HOUSE_PERIOD_ID,
																	 P_ORA_ERROR_CODE => L_SQLCODE,
																	 P_ORA_ERROR_DESC => L_SQLERRM,
																	 P_CTD_ON         => SYSDATE,
																	 P_TBL            => 'PKG_MANAGE_TENANTS.PRC_ALLOCATE_PAYMENT',
																	 P_PROC_DESC      => 'ERROR UPDATING PERIOD PAYMENT FOR TENANT_HOUSE_PERIOD_ID: ' ||
																											 K.TENANT_HOUSE_PERIOD_ID,
																	 P_ID             => GEN_ERROR_SEQ.NEXTVAL);
							END;
						
							-- STARTS HERE
							--USING THIS GENERATES MANY FUTURE YEARS REGARDLESS
							IF L_BAL > K.BALANCE
								 OR L_BAL = K.BALANCE
								 AND TO_CHAR(K.END_DATE,
																'MON') =
								 TO_CHAR(TO_DATE('1/Dec/1970',
																				'DD/MON/YY'),
																'MON')
							
							THEN
								SELECT GEN_PERIOD_MST_SEQ.NEXTVAL
									INTO L_PERIOD_MST_ID
									FROM DUAL;
							
								SELECT TO_DATE(TO_CHAR(TRUNC(K.START_DATE,
																						 'YEAR'),
																			 'DD/MON') || '/' ||
															 TO_NUMBER(TO_CHAR(TO_DATE(K.START_DATE,
																												 'DD/MON/YY'),
																								 'YYYY') + 1),
															 'DD/MON/YYYY')
									INTO L_START_DATE
									FROM DUAL;
							
								SELECT TO_DATE(TO_CHAR(K.END_DATE,
																			 'DD/MON') || '/' ||
															 TO_CHAR(TO_DATE(K.END_DATE,
																							 'DD/MON/YY') + 1,
																			 'YYYY'),
															 'DD/MON/YYYY')
									INTO L_END_DATE
									FROM DUAL;
							
								SELECT TO_NUMBER(TO_CHAR(TO_DATE(TO_CHAR(TRUNC(SYSDATE,
																															 'YEAR'),
																												 'DD/MON') || '/' ||
																								 TO_CHAR(TO_DATE(SYSDATE,
																																 'DD/MON/YY') + 1,
																												 'YYYY'),
																								 'DD/MON/YYYY'),
																				 'MM'))
									INTO L_START_MONTH
									FROM DUAL;
							
								BEGIN
									-- CHECK IF THE YEAR ALREADY EXISTS ELSE CREATE IT.
									/*SELECT COUNT(GPM.PERIOD_NAME)
                   INTO L_YR
                   FROM GEN_PERIOD_MST GPM
                  WHERE GPM.PERIOD_NAME = TO_CHAR(K.END_DATE,
                                'YYYY') + 1;*/
								
									SELECT COUNT(GPM.PERIOD_NAME)
										INTO L_YR
										FROM GEN_PERIOD_MST GPM
									 WHERE GPM.PERIOD_NAME =
												 (SELECT PM.PERIOD_NAME + 1
														FROM GEN_PERIOD_MST PM
													 WHERE PM.IS_CURRENT = 'Y');
								
									-- CREATE NON EXISTING YEAR.
									IF L_YR = 0
									THEN
										INSERT INTO GEN_PERIOD_MST
											(PERIOD_MST_ID,
											 PERIOD_NAME,
											 IS_CURRENT,
											 START_DATE,
											 END_DATE)
										VALUES
											(L_PERIOD_MST_ID,
											 TO_CHAR(K.END_DATE,
															 'YYYY') + 1,
											 'N',
											 L_START_DATE,
											 L_END_DATE);
										COMMIT;
									
										-- Call the procedure
										PKG_MANAGE_TENANTS_2.PRC_GENERATE_PERIODS(PI_PRD_ID        => 1,
																															PI_FRST_DATE     => L_START_DATE,
																															PI_FRST_MTH      => L_START_MONTH,
																															PI_PERIOD_MST_ID => L_PERIOD_MST_ID);
									
										PKG_MANAGE_TENANTS_2.PRC_GEN_TENANT_PERIODS(L_START_DATE,
																																P_TENANT_TO_HOUSE_ID);
									ELSE
										PKG_MANAGE_TENANTS_2.PRC_GEN_TENANT_PERIODS(L_START_DATE,
																																P_TENANT_TO_HOUSE_ID);
									END IF;
								
									--SEEMS NOT TO WORK AS EXPECTED(BILLING GETS KINDA MESSED UP AND NOT WORKING WELL,
									--DOESN'T BILL BEFORE MAKING PAYMENT) WHEN PLACED AT LINE 547
									IF L_BAL > K.BALANCE
									THEN
										PKG_MANAGE_TENANTS_2.PRC_BILL_NEXT_PERIOD(P_TENANT_ID => L_TENANT_ID);
									END IF;
								
									GOTO PROC_LBL;
								
								END;
							END IF;
							-- ENDS HERE.
						END;
					END IF;
				END LOOP;
			END;
	END PRC_ALLOCATE_PAYMENT;

	PROCEDURE PRC_INS_TENANT_TO_HOUSE(P_TENANT_ID IN NUMBER) IS
	
		L_TENANT_TO_HOUSE_ID NUMBER;
		L_START_DATE         DATE;
		L_HOUSE_COST         NUMBER;
	
	BEGIN
		BEGIN
			FOR M IN (SELECT R.TENANT_ID,
											 R.CLIENT_ID,
											 R.BUILDING_ID,
											 R.HOUSE_ID,
											 R.HOUSE_COST,
											 R.TENANCY_START_DATE
									FROM PRP_TENANT_REGISTRATION R
								 WHERE R.TENANT_ID = P_TENANT_ID
									 AND NOT EXISTS
								 (SELECT 1
													FROM PRP_TENANT_TO_HOUSE TAS
												 WHERE TAS.TENANT_ID = R.TENANT_ID
													 AND TAS.HOUSE_ID = R.HOUSE_ID))
			LOOP
				BEGIN
					SAVEPOINT START_TRANS;
				
					SELECT PRP_TENANT_TO_HOUSE_SEQ.NEXTVAL
						INTO L_TENANT_TO_HOUSE_ID
						FROM DUAL;
				
					INSERT INTO PRP_TENANT_TO_HOUSE
						(TENANT_TO_HOUSE_ID,
						 CLIENT_ID,
						 BUILDING_ID,
						 HOUSE_ID,
						 TENANT_ID,
						 DATE_OF_ENTRY,
						 ACTIVE_STATUS,
						 RENTAL_START_DATE)
					VALUES
						(L_TENANT_TO_HOUSE_ID,
						 M.CLIENT_ID,
						 M.BUILDING_ID,
						 M.HOUSE_ID,
						 P_TENANT_ID,
						 M.TENANCY_START_DATE,
						 'Y',
						 M.TENANCY_START_DATE);
				
				EXCEPTION
					WHEN OTHERS THEN
						ROLLBACK TO START_TRANS;
					
						L_SQLCODE := SQLCODE;
					
						L_SQLERRM := SQLERRM;
					
						SELECT GEN_ERROR_SEQ.NEXTVAL INTO O_ERROR_ID FROM DUAL;
					
						PRC_INSERT_ERROR(P_ERROR_ID       => P_TENANT_ID,
														 P_ORA_ERROR_CODE => L_SQLCODE,
														 P_ORA_ERROR_DESC => L_SQLERRM,
														 P_CTD_ON         => SYSDATE,
														 P_TBL            => 'PKG_MANAGE_TENANTS.PRC_INS_TENANT_TO_HOUSE',
														 P_PROC_DESC      => 'ERROR INSERTING TENANT TO HOUSE: ' ||
																								 M.HOUSE_ID,
														 P_ID             => O_ERROR_ID);
				END;
			END LOOP;
		
			BEGIN
			
				SELECT RR.HOUSE_COST
					INTO L_HOUSE_COST
					FROM PRP_TENANT_REGISTRATION RR
				 WHERE RR.TENANT_ID = P_TENANT_ID;
			
				SELECT RR.TENANCY_START_DATE
					INTO L_START_DATE
					FROM PRP_TENANT_REGISTRATION RR
				 WHERE RR.TENANT_ID = P_TENANT_ID;
			
				PKG_MANAGE_TENANTS_2.PRC_GEN_TENANT_PERIODS(P_START_DATE         => L_START_DATE,
																										P_TENANT_TO_HOUSE_ID => L_TENANT_TO_HOUSE_ID);
			END;
		
		END;
	
	END PRC_INS_TENANT_TO_HOUSE;

	PROCEDURE PRC_TENANT_TRANS_INS(P_TENANT_HOUSE_PERIOD_ID IN NUMBER,
																 P_TENANT_ID              IN NUMBER,
																 P_TRANS_DATE             IN DATE,
																 P_REFERENCE              IN VARCHAR2,
																 P_TRANS_TYPE             IN VARCHAR2,
																 P_TRANS_AMOUNT           IN NUMBER,
																 P_TRANS_SOURCE           IN VARCHAR2,
																 P_TRANS_REF_ID           IN NUMBER,
																 P_TRANS_DESC             IN VARCHAR2) AS
		L_BAL NUMBER;
	BEGIN
		BEGIN
			FOR S IN (SELECT TS.TENANT_ID,
											 TS.TENANT_NAME || ' ' || TS.PHONE_NUMBER TENANT_NAME,
											 NVL(TS.TENANT_BAL,
													 0) BAL
									FROM PRP_TENANT_REGISTRATION TS
								 WHERE TS.TENANT_ID = P_TENANT_ID)
			LOOP
				BEGIN
					IF P_TRANS_TYPE = 'W'
					THEN
						L_BAL := S.BAL - NVL(P_TRANS_AMOUNT,
																 0);
					ELSIF P_TRANS_TYPE = 'D'
					THEN
						L_BAL := S.BAL + NVL(P_TRANS_AMOUNT,
																 0);
					END IF;
				
					INSERT INTO PRP_TENANT_TRANS TT
						(TT.TRANS_DATE,
						 TT.TRANS_REFERENCE,
						 TT.TENANT_ID,
						 TT.TRANS_TYPE,
						 TT.TRANS_AMOUNT,
						 TT.BALANCE,
						 TT.TRANS_SOURCE,
						 TT.TRANS_REF_ID,
						 TT.TRANS_DESC,
						 TT.TENANT_HOUSE_PERIOD_ID)
					VALUES
						(P_TRANS_DATE,
						 P_REFERENCE,
						 P_TENANT_ID,
						 P_TRANS_TYPE,
						 P_TRANS_AMOUNT,
						 L_BAL,
						 P_TRANS_SOURCE,
						 P_TRANS_REF_ID,
						 P_TRANS_DESC,
						 P_TENANT_HOUSE_PERIOD_ID);
				
					BEGIN
						UPDATE PRP_TENANT_REGISTRATION TN
							 SET TN.TENANT_BAL = L_BAL
						 WHERE TN.TENANT_ID = P_TENANT_ID;
					END;
				
				EXCEPTION
					WHEN OTHERS THEN
						L_SQLCODE := SQLCODE;
						L_SQLERRM := SQLERRM;
					
						INSERT INTO GEN_ERRORS E
							(E.ERROR_ID,
							 E.ORA_ERROR_CODE,
							 E.ORA_ERROR_DESC,
							 E.TBL,
							 E.RMK,
							 ID)
						VALUES
							(S.TENANT_ID,
							 L_SQLCODE,
							 L_SQLERRM,
							 'PRC_TENANT_TRANS_INS',
							 'Error inserting Transaction#: ' || ' ' || P_REFERENCE ||
							 'for Tenant: ' || S.TENANT_NAME,
							 GEN_ERROR_SEQ.NEXTVAL);
				END;
			END LOOP;
		END;
	END PRC_TENANT_TRANS_INS;

	PROCEDURE PRC_BILL_NEXT_PERIOD(P_TENANT_ID IN NUMBER) AS
		L_REF PRP_TENANT_TRANS.TRANS_REFERENCE%TYPE;
	BEGIN
		BEGIN
			FOR EA IN (SELECT *
									 FROM (SELECT A.*,
																TH.TENANT_ID
													 FROM PRP_TENANT_HOUSE_PERIOD A,
																PRP_TENANT_TO_HOUSE     TH
													WHERE A.TENANT_TO_HOUSE_ID = TH.TENANT_TO_HOUSE_ID
														AND TH.TENANT_ID = P_TENANT_ID
														AND NOT EXISTS
													(SELECT 1
																	 FROM PRP_TENANT_TRANS TR
																	WHERE TR.TENANT_HOUSE_PERIOD_ID =
																				A.TENANT_HOUSE_PERIOD_ID)
													ORDER BY 1)
									WHERE ROWNUM <= 1)
			LOOP
				BEGIN
					SELECT EA.TENANT_ID || TO_CHAR(SYSDATE,
																				 'DDMMYYHHMISS')
						INTO L_REF
						FROM DUAL;
				
					-- Call the procedure
					PKG_MANAGE_TENANTS_2.PRC_TENANT_TRANS_INS(P_TENANT_HOUSE_PERIOD_ID => EA.TENANT_HOUSE_PERIOD_ID,
																										P_TENANT_ID              => EA.TENANT_ID,
																										P_TRANS_DATE             => SYSDATE,
																										P_REFERENCE              => L_REF,
																										P_TRANS_TYPE             => 'D',
																										P_TRANS_AMOUNT           => EA.RENT_AMT_EXPECTED,
																										P_TRANS_SOURCE           => 'RENT_BILL',
																										P_TRANS_REF_ID           => EA.TENANT_TO_HOUSE_ID,
																										P_TRANS_DESC             => 'Rent Expected for the period:' ||
																																								EA.START_DATE ||
																																								' to ' ||
																																								EA.END_DATE);
				
					UPDATE PRP_TENANT_HOUSE_PERIOD PP
						 SET PP.IS_CLEARED = 'N'
					 WHERE PP.TENANT_HOUSE_PERIOD_ID = EA.TENANT_HOUSE_PERIOD_ID;
				
				END;
			
			END LOOP;
		END;
	END PRC_BILL_NEXT_PERIOD;

BEGIN
	NULL;
END PKG_MANAGE_TENANTS_2;
