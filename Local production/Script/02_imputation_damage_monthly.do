


*******************************************************************
*			Local kcal production and loss
*			Imputation  of values to give monthly overview of calories available
*******************************************************************


	clear all 

	
**# 0. Set-up


	global input      "$root\Input data"
	global output      "$root\Output data"


	** import raw data for conduct the imputation
 
	import excel "$input/raw_kcal_montly_value.xlsx", firstrow clear
 
	* date month year
	gen date=(Month + Year)
	drop if Month=="" 
 
	** rename variables   
	rename aggr_tot_kcal_live_Gaza            aggr_kcal_lvstck_prod
	label var 					              aggr_kcal_lvstck_prod "Aggregate kcal livestock internally produced, Gaza level"
	format  aggr_kcal_lvstck_prod %12.0fc

	rename aggr_tot_kcal_crop_Gaza            aggr_kcal_crop_prod
	label var 							      aggr_kcal_crop_prod  "Aggregate kcal crop internally produced, Gaza level"
	format  aggr_kcal_crop_prod %12.0fc

	rename aggr_croploss_kcal_Gaza            aggr_kcal_crop_loss
	label var 							      aggr_kcal_crop_loss  "Aggregate kcal crop loss, Gaza level"
	format  aggr_kcal_crop_loss %12.0fc

	rename aggr_live_loss_kcal_Gaza           aggr_kcal_lvstck_loss
	label var 							      aggr_kcal_lvstck_loss  "Aggregate kcal livestock loss, Gaza level"
	format  aggr_kcal_lvstck_loss %12.0fc

	rename DemagecroplandfromNLS              damage_crop_land
	label var 							      damage_crop_land "Damage crop land from NSL"
 
 
	gen kcal_left_crop=aggr_kcal_crop_prod-aggr_kcal_crop_loss
	lab var kcal_left_crop "Aggregate kcal availalble crop (post conflict), Gaza level"
	format  kcal_left_crop %12.0fc

	gen kcal_left_livestock=aggr_kcal_lvstck_prod-aggr_kcal_lvstck_loss
	lab var kcal_left_livestock "Aggregate kcal availalble livestock (post conflict), Gaza level"
	format kcal_left_livestock %12.0fc

 
 ** Generate list of months
	gen id=_n 

 ** Generate the n. of days per months
	   
	gen montlhy_days= 31 if inlist((Month), "October", "December", "January", "March", "May", "July", "August")
   replace  montlhy_days= 30 if montlhy_days==.
   replace  montlhy_days= 86 if date=="December2023"
   drop if   date=="September2023"
   replace  montlhy_days= 0 if inlist((date), "September2023", "October2023", "November2023") 
 
   gen cum_monthly_days = sum(montlhy_days)
   
   replace cum_monthly_days=25 if date=="October2023" // if we start form the 7 october included 
   
   replace cum_monthly_days=55 if date=="November2023" & cum_monthly_days==0
   


 ** Impute the damage variable to find the undamage level 
	sort id
	ipolate damage_crop_land id, gen(damage_imp) epolate
	format damage_imp %9.2f
	
	*---------------------------------------------------------------------------*
	* 						       CROP
	*---------------------------------------------------------------------------* 
            
	* create undamage land share: 1-damage share
	gen undamage_crop_land= 1-damage_imp
	format undamage_crop_land %9.2f
	
	gen undamage_ln=ln(undamage_crop_land) 
				
	replace cum_monthly_days=0 if date=="September2023"
	
	* gen kcal left per day 
	gen kcal_left_crop_day=kcal_left_crop/cum_monthly_days
	format  kcal_left_crop_day    %12.0fc

	* compute the elasticity of kcal left to undamaged land 
	gen ln_kcal = ln(kcal_left_crop_day)
    reg ln_kcal undamage_crop_land 
	
 	* gen elasticity based on regression above 
    gen elasticity_crop= 1.46
	
    *gen the delta in undamage land from one month to another
	sort id
    gen delta_undamaged_land= undamage_crop_land- undamage_crop_land[_n-1]
	replace delta_undamaged_land=delta_undamaged_land*100
	format delta_undamaged_land %9.2f
    
	*gen percentage change kcal from crop using elasticity and delta undamaged  
	gen perc_change_kcal_crop=elasticity_crop*delta_undamaged_land
	format perc_change_kcal_crop %9.2f
			
	gen kcal_left_crop_est=kcal_left_crop_day
	

	
       * Forward fill of calories change over time (... -> Nov 2023)	 
	    replace kcal_left_crop_est= 387609768 if date=="September2023"

	    gen change_kcal_crop=.
		    
	    forvalues i = 2/`=_N' {
        
	    quietly replace change_kcal_crop = ///
        kcal_left_crop_est[`i'-1]/100 * perc_change_kcal_crop[`i'] ///
        in `i' if missing(change_kcal_crop[`i']) ///
        & !missing(kcal_left_crop_est[`i'-1]) ///
        & !missing(perc_change_kcal_crop[`i'])
			
		format  change_kcal_crop    %12.0fc
	
        quietly replace kcal_left_crop_est=kcal_left_crop_est[`i'-1]+change_kcal_crop[`i'] in `i' if missing(kcal_left_crop_est[`i']) 
	    format  kcal_left_crop_est    %12.0fc
			}


       * gen calorie per person using population montlhy     
		 gen kcal_left_crop_est_PD=kcal_left_crop_est/pop_monthly 

		 
	*---------------------------------------------------------------------------*
	* 						       LIVESTOCK
	*---------------------------------------------------------------------------* 
     

	* Gen mortality variable as in the main paper  - average of all livestock mortality, without differenciating by typology 
		gen       mortality =.
		replace   mortality = 0.31   if date== "December2023"	
		replace   mortality = 0.73  if date== "September2024"
		replace   mortality = 0  if date== "September2023"
		
		
		* ipolate mortality 
		ipolate mortality id, gen(mortality_imp) epolate


		* replace values over 100 equal to 100
		replace mortality_imp= 1 if id>=19 
		format 	mortality_imp %9.2f

		* rescale mortality variable to be consistent with crop
		gen     undamage_lvst= 1-mortality_imp
		format 	undamage_lvst %9.2f		
		
		* gen kcal left per day 
		gen 	kcal_left_lvst_day=kcal_left_livestock/cum_monthly_days
		format  kcal_left_lvst_day    %12.0fc

		* compute the elasticity of kcal left to undamaged livestock 		
		gen ln_kcal_lvst = ln(kcal_left_lvst_day)
        reg ln_kcal_lvst undamage_lvst 
		
 		* gen elasticity based on regression above 
		gen elasticity_lvst=1.84

		*gen the delta in undamage livestock from one month to another
		sort id
        gen 	delta_undamaged_lvst= undamage_lvst- undamage_lvst[_n-1]
		replace delta_undamaged_lvst=delta_undamaged_lvst*100
		format 	delta_undamaged_lvst %9.2f
        
		
		*gen percentage change kcal from livestock using elasticity and delta undamaged  
		gen 	perc_change_kcal_lvst=elasticity_lvst*delta_undamaged_lvst
		format 	perc_change_kcal_lvst %9.2f
				
		gen kcal_left_lvst_est=.
		
		
		* Forward fill of calories change over time (... -> Nov 2023)	
        sort id 
		replace kcal_left_lvst_est=173359534  if date=="September2023"

	    gen change_kcal_lvst=.
		    
	    forvalues i = 2/`=_N' {
        
	    quietly replace change_kcal_lvst = ///
        kcal_left_lvst_est[`i'-1]/100 * perc_change_kcal_lvst[`i'] ///
        in `i' if missing(change_kcal_lvst[`i']) ///
        & !missing(kcal_left_lvst_est[`i'-1]) ///
        & !missing(perc_change_kcal_lvst[`i'])
			
		format  change_kcal_lvst    %12.0fc
        quietly replace kcal_left_lvst_est=kcal_left_lvst_est[`i'-1]+change_kcal_lvst[`i'] in `i' if missing(kcal_left_lvst_est[`i']) 	  
	   format  kcal_left_lvst_est    %12.0fc

}

	     * replace livestoc kcal left when mortality=1
		 replace kcal_left_lvst_est=0 if undamage_lvst==0
		 
         * gen calorie per person using population montlhy       
		 gen kcal_left_lvst_est_PD=kcal_left_lvst_est/pop_monthly 
		 

		 * gen total kcal left (crop per day per person + livestock per day per person)
		 gen kcal_left_total=kcal_left_crop_est_PD + kcal_left_lvst_est_PD
		  
		 drop if date=="September2023"
		 
		 keep  Month Year kcal_left_crop_est_PD kcal_left_lvst_est_PD kcal_left_total undamage_lvst undamage_crop_land
	
		export excel using "$output/kcal_left_monthly_oct23_sept25.xls", firstrow(variables) replace
		
		exit
			