PROCEDURE PRC_ALLOCATE_PAYMENT(P_TENANT_TO_HOUSE_ID IN NUMBER,
																 P_AMOUNT             IN NUMBER,
																 P_PRN                IN VARCHAR2) AS
		/*
    P_AMOUNT is current amount paid by tenant as of date procedure.*/
		L_AMOUNT_OK     NUMBER; --
		L_BAL           NUMBER := 0; -- Get what is left after payment is made by a tenant when money paid is more than money billed 
		L_SPENT         NUMBER := 0; -- Amount of money paid on a tenant's house billing(Amount Payed for a billed or unbilled period by tenant)
		L_AMOUNT        NUMBER := 0; -- Mount being billed on tenant and  not yet cleared for a given period(Unpaid Billed Amount On Client)
		L_RENT_BALANCE  NUMBER := 0;
		L_TENANT_ID     NUMBER;
		L_IS_CLEARED    PRP_TENANT_HOUSE_PERIOD.IS_CLEARED%TYPE;
		L_PERIOD_MST_ID NUMBER;
		L_START_DATE    DATE;
		L_END_DATE      DATE;
		L_START_MONTH   NUMBER;
		L_YR            NUMBER;
		L_BALANCE       NUMBER;
	
	BEGIN
		--TO MAKE INITIAL BILLING ON TENANT PAYMENT.
		--FIRST CHECK IF TENANT IS BEING DEMANDED, IF SO... DON'T BILL NEXT MONTH
		SELECT TA.BALANCE
			INTO L_BALANCE
			FROM PRP_TENANT_HOUSE_PERIOD TA
		 WHERE TA.TENANT_TO_HOUSE_ID = P_TENANT_TO_HOUSE_ID;
	
		SELECT NVL(SUM(B.AMOUNT),
							 0)
			INTO L_SPENT
			FROM PRP_PAY_ALLOCATION_TEMP B
		 WHERE B.PRN = P_PRN;
	EXCEPTION
		WHEN OTHERS THEN
			L_SPENT := 0;
		
			L_AMOUNT := L_BALANCE;
			L_BAL    := P_AMOUNT - L_SPENT;
		
			L_RENT_BALANCE := L_BALANCE - L_AMOUNT_OK;
			IF L_RENT_BALANCE = 0
				 OR L_BALANCE <> 0
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
																																				 L_TENANT_ID);
							
								IF L_BAL > K.BALANCE -- GREATER THAN
								THEN
									PKG_MANAGE_TENANTS_2.PRC_BILL_NEXT_PERIOD(P_TENANT_ID => L_TENANT_ID);
								END IF;
							
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
									SELECT COUNT(GPM.PERIOD_NAME)
										INTO L_YR
										FROM GEN_PERIOD_MST GPM
									 WHERE GPM.PERIOD_NAME =
												 TO_CHAR(K.END_DATE,
																 'YYYY') + 1;
								
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
									GOTO PROC_LBL;
								
								END;
							END IF;
							-- ENDS HERE.
						END;
					END IF;
				END LOOP;
			END;
	END PRC_ALLOCATE_PAYMENT;
